-- handle_new_user() — Auto-create profile on sign-up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (id, role, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'role', 'coordinator')::user_role,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- handle_ministry_meeting() — Auto-confirm ministry meetings
CREATE OR REPLACE FUNCTION handle_ministry_meeting()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.type = 'ministry' THEN
    NEW.status := 'confirmed';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ministry_auto_confirm
  BEFORE INSERT ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION handle_ministry_meeting();

-- set_updated_at() — Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointments_updated_at
  BEFORE UPDATE ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- check_appointment_overlap() — RPC for conflict detection
CREATE OR REPLACE FUNCTION check_appointment_overlap(
  p_start_time  TIMESTAMPTZ,
  p_end_time    TIMESTAMPTZ,
  p_exclude_id  UUID DEFAULT NULL
)
RETURNS TABLE (
  id         UUID,
  title      TEXT,
  type       appointment_type,
  status     appointment_status,
  start_time TIMESTAMPTZ,
  end_time   TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id, a.title, a.type, a.status, a.start_time, a.end_time
  FROM appointments a
  WHERE a.status IN ('pending', 'confirmed')
    AND tstzrange(a.start_time, a.end_time) && tstzrange(p_start_time, p_end_time)
    AND (p_exclude_id IS NULL OR a.id != p_exclude_id);
END;
$$;

-- notify_on_appointment_change() — Auto-create notifications
CREATE OR REPLACE FUNCTION notify_on_appointment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
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
    IF NEW.type = 'ministry' THEN
      v_notif_type := 'ministry_auto_confirmed';
      v_title := 'إجتماع وزارة جديد';
      v_body := 'تم تأكيد إجتماع وزارة: ' || NEW.title;
      -- Notify all managers
      IF v_manager_ids IS NOT NULL THEN
        FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
          INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
          VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
        END LOOP;
      END IF;
    ELSE
      v_notif_type := 'new_appointment';
      v_title := 'موعد جديد بانتظار الموافقة';
      v_body := 'موعد جديد: ' || NEW.title;
      -- Notify all managers
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
            -- Coordinator accepted a suggestion — notify managers
            v_notif_type := 'suggestion_accepted';
            v_title := 'تم قبول الاقتراح';
            v_body := 'تم قبول الوقت البديل لـ: ' || NEW.title;
            IF v_manager_ids IS NOT NULL THEN
              FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
                INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
                VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
              END LOOP;
            END IF;
          ELSE
            -- Manager approved — notify coordinator
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
            -- Coordinator rejected a suggestion — notify managers
            v_notif_type := 'suggestion_rejected';
            v_title := 'تم رفض الاقتراح';
            v_body := 'تم رفض الوقت البديل لـ: ' || NEW.title;
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
          -- Coordinator cancelled — notify managers
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
