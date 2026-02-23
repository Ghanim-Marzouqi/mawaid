-- ============================================================
-- Migration 00010: Dynamic appointment types, drafts, approval toggle
-- ============================================================

-- 1a. Create appointment_types table
CREATE TABLE appointment_types (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  color_index INT  NOT NULL DEFAULT 0,
  created_by  UUID NOT NULL REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE appointment_types ENABLE ROW LEVEL SECURITY;

CREATE POLICY "appointment_types_select"
  ON appointment_types FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "appointment_types_insert_coordinator"
  ON appointment_types FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'coordinator'
    )
  );

CREATE POLICY "appointment_types_update_coordinator"
  ON appointment_types FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "appointment_types_delete_coordinator"
  ON appointment_types FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- 1b. Migrate appointments.type column
ALTER TABLE appointments ADD COLUMN type_id UUID REFERENCES appointment_types(id);
CREATE INDEX idx_appointments_type_id ON appointments(type_id);

-- Drop old type column and index
DROP INDEX IF EXISTS idx_appointments_type;
ALTER TABLE appointments DROP COLUMN type;

-- Drop the old appointment_type enum
DROP TYPE IF EXISTS appointment_type;

-- 1c. Add requires_approval column
ALTER TABLE appointments ADD COLUMN requires_approval BOOLEAN NOT NULL DEFAULT true;

-- 1d. Add draft status & make times nullable
ALTER TYPE appointment_status ADD VALUE 'draft';

-- Make start_time and end_time nullable
ALTER TABLE appointments ALTER COLUMN start_time DROP NOT NULL;
ALTER TABLE appointments ALTER COLUMN end_time DROP NOT NULL;

-- Update chk_time_range constraint to allow both-null (draft) or both-set
ALTER TABLE appointments DROP CONSTRAINT chk_time_range;
ALTER TABLE appointments ADD CONSTRAINT chk_time_range CHECK (
  (start_time IS NULL AND end_time IS NULL) OR
  (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)
);

-- 1e. Drop ministry-specific constraints & triggers
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS excl_ministry_overlap;
DROP TRIGGER IF EXISTS trg_ministry_auto_confirm ON appointments;
DROP FUNCTION IF EXISTS handle_ministry_meeting();

-- New auto-confirm trigger: if requires_approval = false AND start_time IS NOT NULL
CREATE OR REPLACE FUNCTION handle_auto_confirm()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.requires_approval = false AND NEW.start_time IS NOT NULL THEN
    NEW.status := 'confirmed';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_confirm
  BEFORE INSERT ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION handle_auto_confirm();

-- 1f. Update RLS policies (unrestricted edit/delete)
DROP POLICY IF EXISTS "appointments_update" ON appointments;
DROP POLICY IF EXISTS "appointments_delete_coordinator" ON appointments;

CREATE POLICY "appointments_update"
  ON appointments FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'manager'
    )
    OR created_by = auth.uid()
  );

CREATE POLICY "appointments_delete_coordinator"
  ON appointments FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- 1g. Update check_appointment_overlap RPC
CREATE OR REPLACE FUNCTION check_appointment_overlap(
  p_start_time  TIMESTAMPTZ,
  p_end_time    TIMESTAMPTZ,
  p_exclude_id  UUID DEFAULT NULL
)
RETURNS TABLE (
  id         UUID,
  title      TEXT,
  type_id    UUID,
  status     appointment_status,
  start_time TIMESTAMPTZ,
  end_time   TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id, a.title, a.type_id, a.status, a.start_time, a.end_time
  FROM appointments a
  WHERE a.status IN ('pending', 'confirmed')
    AND a.start_time IS NOT NULL
    AND tstzrange(a.start_time, a.end_time) && tstzrange(p_start_time, p_end_time)
    AND (p_exclude_id IS NULL OR a.id != p_exclude_id);
END;
$$;

-- 1h. Update notification trigger
DROP TRIGGER IF EXISTS trg_notify_appointment ON appointments;

CREATE OR REPLACE FUNCTION notify_on_appointment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coordinator_id UUID;
  v_manager_ids    UUID[];
  v_notif_type     notification_type;
  v_title          TEXT;
  v_body           TEXT;
  v_recipient_id   UUID;
BEGIN
  -- Gather role IDs
  SELECT ARRAY_AGG(id) INTO v_manager_ids
  FROM profiles WHERE role = 'manager';

  IF TG_OP = 'INSERT' THEN
    -- Draft appointments: no notification on insert
    IF NEW.status = 'draft' THEN
      RETURN NEW;
    END IF;

    IF NEW.requires_approval = false AND NEW.start_time IS NOT NULL THEN
      -- Auto-confirmed: notify managers
      v_notif_type := 'ministry_auto_confirmed';
      v_title := 'موعد جديد مؤكد';
      v_body := 'تم تأكيد: ' || NEW.title;
      IF v_manager_ids IS NOT NULL THEN
        FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
          INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
          VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
        END LOOP;
      END IF;
    ELSE
      -- Requires approval: notify managers of new pending appointment
      v_notif_type := 'new_appointment';
      v_title := 'موعد جديد بانتظار الموافقة';
      v_body := 'موعد جديد: ' || NEW.title;
      IF v_manager_ids IS NOT NULL THEN
        FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
          INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
          VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
        END LOOP;
      END IF;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    v_coordinator_id := NEW.created_by;

    IF OLD.status IS DISTINCT FROM NEW.status THEN
      CASE NEW.status
        WHEN 'confirmed' THEN
          IF OLD.status = 'suggested' THEN
            v_notif_type := 'suggestion_accepted';
            v_title := 'تم قبول الاقتراح';
            v_body := 'تم قبول الوقت البديل لـ: ' || NEW.title;
            IF v_manager_ids IS NOT NULL THEN
              FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
                INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
                VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
              END LOOP;
            END IF;
          ELSIF OLD.status = 'draft' THEN
            -- Draft → confirmed (auto-confirmed draft): notify managers
            v_notif_type := 'ministry_auto_confirmed';
            v_title := 'موعد جديد مؤكد';
            v_body := 'تم تأكيد: ' || NEW.title;
            IF v_manager_ids IS NOT NULL THEN
              FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
                INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
                VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
              END LOOP;
            END IF;
          ELSE
            v_notif_type := 'appointment_confirmed';
            v_title := 'تم تأكيد الموعد';
            v_body := 'تم تأكيد: ' || NEW.title;
            INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
            VALUES (v_coordinator_id, v_notif_type, v_title, v_body, NEW.id);
          END IF;

        WHEN 'rejected' THEN
          v_notif_type := 'appointment_rejected';
          v_title := 'تم رفض الموعد';
          v_body := 'تم رفض: ' || NEW.title;
          INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
          VALUES (v_coordinator_id, v_notif_type, v_title, v_body, NEW.id);

        WHEN 'suggested' THEN
          v_notif_type := 'alternative_suggested';
          v_title := 'اقتراح وقت بديل';
          v_body := 'تم اقتراح وقت بديل لـ: ' || NEW.title;
          INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
          VALUES (v_coordinator_id, v_notif_type, v_title, v_body, NEW.id);

        WHEN 'pending' THEN
          IF OLD.status = 'suggested' THEN
            v_notif_type := 'suggestion_rejected';
            v_title := 'تم رفض الاقتراح';
            v_body := 'تم رفض الوقت البديل لـ: ' || NEW.title;
            IF v_manager_ids IS NOT NULL THEN
              FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
                INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
                VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
              END LOOP;
            END IF;
          ELSIF OLD.status = 'draft' THEN
            -- Draft → pending: notify managers of new appointment needing approval
            v_notif_type := 'new_appointment';
            v_title := 'موعد جديد بانتظار الموافقة';
            v_body := 'موعد جديد: ' || NEW.title;
            IF v_manager_ids IS NOT NULL THEN
              FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
                INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
                VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
              END LOOP;
            END IF;
          END IF;

        WHEN 'cancelled' THEN
          v_notif_type := 'appointment_cancelled';
          v_title := 'تم إلغاء الموعد';
          v_body := 'تم إلغاء: ' || NEW.title;
          IF v_manager_ids IS NOT NULL THEN
            FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
              INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
              VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
            END LOOP;
          END IF;

        ELSE
          NULL;
      END CASE;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_appointment
  AFTER INSERT OR UPDATE ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_appointment_change();
