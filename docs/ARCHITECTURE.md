# Architecture Document: Mawa'id (مواعيد)

## 1. Executive Summary

**Mawa'id** is a specialized appointment management system designed for a high-level environment (e.g., a Director's office). The application streamlines the coordination between a **Coordinator** and a **Manager**, focusing on three specific appointment types with varying levels of priority and authority.

The Coordinator creates and manages appointments from a desktop/laptop. The Manager reviews, approves, rejects, or suggests alternatives from a mobile device. Ministry meetings are auto-confirmed and cannot be overlapped. The system is Arabic-only (RTL) and runs on a self-hosted Supabase backend.

---

## 2. Technical Stack

| Layer              | Technology                                          |
| :----------------- | :-------------------------------------------------- |
| **Framework**      | Expo SDK 54 (React Native 0.81)                     |
| **Routing**        | Expo Router v6 (file-based)                         |
| **Styling**        | NativeWind v4.2 (Tailwind CSS)                      |
| **State**          | Zustand v5                                          |
| **Backend**        | Supabase self-hosted (Docker)                       |
| **Database**       | PostgreSQL 17 (via Supabase)                        |
| **Auth**           | Supabase Auth (email + password)                    |
| **Real-time**      | Supabase Realtime (WebSocket channels)              |
| **Push**           | Expo Push Notifications + Supabase Edge Functions   |
| **Language**       | Arabic only (RTL) — no i18n library                 |
| **Font**           | IBM Plex Arabic (via `expo-font`)                   |

---

## 3. System Architecture & Roles

### A. User Roles

| Role            | Primary Interface | Permissions                                                        |
| :-------------- | :---------------- | :----------------------------------------------------------------- |
| **Coordinator** | Laptop / Desktop  | Create, Edit, Delete, View Calendar, Track Approval Status         |
| **Manager**     | Mobile (Handheld) | View Pending, Approve, Reject, Suggest Alternative Time            |

Both roles are stored in the `profiles` table. There is no self-registration — accounts are pre-seeded by an admin via Supabase Studio or a seed script.

### B. Appointment Types

| Type                            | Arabic              | Priority | Behavior                                                                  |
| :------------------------------ | :------------------- | :------- | :------------------------------------------------------------------------ |
| **Ministry Meeting**            | إجتماع وزارة        | Critical | Auto-confirmed on creation. Locked — cannot be edited, rejected, or overlapped. |
| **Patient Appointment**         | موعد مريض            | Medium   | Requires Manager approval. Can be suggested an alternative time.          |
| **External Meeting**            | موعد خارجي           | Medium   | Requires Manager approval. Stores a text address or external link (no Google Maps). |

---

## 4. Complete Data Model (Supabase PostgreSQL Schema)

### 4.1 Enum Types

```sql
CREATE TYPE user_role AS ENUM ('coordinator', 'manager');

CREATE TYPE appointment_type AS ENUM ('ministry', 'patient', 'external');

CREATE TYPE appointment_status AS ENUM (
  'pending',
  'confirmed',
  'rejected',
  'suggested',
  'cancelled'
);

CREATE TYPE notification_type AS ENUM (
  'new_appointment',
  'appointment_confirmed',
  'appointment_rejected',
  'alternative_suggested',
  'suggestion_accepted',
  'suggestion_rejected',
  'appointment_cancelled',
  'ministry_auto_confirmed'
);
```

### 4.2 `profiles` Table

Linked to `auth.users` via a trigger that fires on new user sign-up.

```sql
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role        user_role     NOT NULL,
  full_name   TEXT          NOT NULL,
  push_token  TEXT,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Index for role-based queries
CREATE INDEX idx_profiles_role ON profiles(role);
```

### 4.3 `appointments` Table

```sql
CREATE TABLE appointments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT               NOT NULL,
  type          appointment_type   NOT NULL,
  status        appointment_status NOT NULL DEFAULT 'pending',
  start_time    TIMESTAMPTZ        NOT NULL,
  end_time      TIMESTAMPTZ        NOT NULL,
  location      TEXT,
  notes         TEXT,
  created_by    UUID               NOT NULL REFERENCES profiles(id),
  reviewed_by   UUID               REFERENCES profiles(id),
  reviewed_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ        NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ        NOT NULL DEFAULT now(),

  CONSTRAINT chk_time_range CHECK (end_time > start_time),
  CONSTRAINT chk_reviewed_fields CHECK (
    (reviewed_by IS NULL AND reviewed_at IS NULL) OR
    (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
  )
);

-- Standard indexes
CREATE INDEX idx_appointments_status     ON appointments(status);
CREATE INDEX idx_appointments_type       ON appointments(type);
CREATE INDEX idx_appointments_created_by ON appointments(created_by);
CREATE INDEX idx_appointments_start_time ON appointments(start_time);

-- GiST index for time-range overlap queries
-- Requires the btree_gist extension
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE INDEX idx_appointments_time_range
  ON appointments USING GIST (tstzrange(start_time, end_time));

-- EXCLUSION constraint: no two confirmed ministry meetings can overlap
ALTER TABLE appointments
  ADD CONSTRAINT excl_ministry_overlap
  EXCLUDE USING GIST (
    tstzrange(start_time, end_time) WITH &&
  )
  WHERE (type = 'ministry' AND status = 'confirmed');
```

### 4.4 `appointment_suggestions` Table

Stores the Manager's suggested alternative time for an appointment.

```sql
CREATE TABLE appointment_suggestions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id    UUID           NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  suggested_by      UUID           NOT NULL REFERENCES profiles(id),
  suggested_start   TIMESTAMPTZ    NOT NULL,
  suggested_end     TIMESTAMPTZ    NOT NULL,
  message           TEXT,
  is_active         BOOLEAN        NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT chk_suggestion_time_range CHECK (suggested_end > suggested_start)
);

CREATE INDEX idx_suggestions_appointment ON appointment_suggestions(appointment_id);
CREATE INDEX idx_suggestions_active      ON appointment_suggestions(appointment_id) WHERE is_active = true;
```

### 4.5 `notifications` Table

```sql
CREATE TABLE notifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id  UUID              NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type          notification_type NOT NULL,
  title         TEXT              NOT NULL,
  body          TEXT              NOT NULL,
  appointment_id UUID             REFERENCES appointments(id) ON DELETE SET NULL,
  is_read       BOOLEAN           NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ       NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_recipient  ON notifications(recipient_id);
CREATE INDEX idx_notifications_unread     ON notifications(recipient_id) WHERE is_read = false;
```

### 4.6 Row Level Security (RLS) Policies

```sql
-- Enable RLS on all tables
ALTER TABLE profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications         ENABLE ROW LEVEL SECURITY;

-- ─── profiles ───
-- All authenticated users can read all profiles (needed for name lookups)
CREATE POLICY "profiles_select"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

-- Users can update only their own profile (e.g., push token)
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ─── appointments ───
-- Both roles can read all appointments (needed for calendar view)
CREATE POLICY "appointments_select"
  ON appointments FOR SELECT
  TO authenticated
  USING (true);

-- Only coordinators can insert appointments
CREATE POLICY "appointments_insert_coordinator"
  ON appointments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'coordinator'
    )
  );

-- Coordinators can update their own non-ministry appointments
-- Managers can update any appointment (for approval/rejection)
CREATE POLICY "appointments_update"
  ON appointments FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'manager'
    )
    OR (
      created_by = auth.uid() AND type != 'ministry'
    )
  );

-- Coordinators can delete their own non-ministry pending appointments
CREATE POLICY "appointments_delete_coordinator"
  ON appointments FOR DELETE
  TO authenticated
  USING (
    created_by = auth.uid()
    AND type != 'ministry'
    AND status = 'pending'
  );

-- ─── appointment_suggestions ───
-- Both roles can view suggestions
CREATE POLICY "suggestions_select"
  ON appointment_suggestions FOR SELECT
  TO authenticated
  USING (true);

-- Only managers can insert suggestions
CREATE POLICY "suggestions_insert_manager"
  ON appointment_suggestions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'manager'
    )
  );

-- ─── notifications ───
-- Users can only read their own notifications
CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  TO authenticated
  USING (recipient_id = auth.uid());

-- Users can update (mark as read) their own notifications
CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE
  TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());
```

### 4.7 Database Functions & Triggers

#### `handle_new_user()` — Auto-create profile on sign-up

```sql
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
```

#### `handle_ministry_meeting()` — Auto-confirm ministry meetings

```sql
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
```

#### `set_updated_at()` — Auto-update `updated_at` timestamp

```sql
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
```

#### `check_appointment_overlap()` — RPC for conflict detection

```sql
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
```

#### `notify_on_appointment_change()` — Auto-create notifications

```sql
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
      FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
        INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
        VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
      END LOOP;
    ELSE
      v_notif_type := 'new_appointment';
      v_title := 'موعد جديد بانتظار الموافقة';
      v_body := 'موعد جديد: ' || NEW.title;
      -- Notify all managers
      FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
        INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
        VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
      END LOOP;
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
            FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
              INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
              VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
            END LOOP;
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
            FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
              INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
              VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
            END LOOP;
          END IF;

        WHEN 'cancelled' THEN
          v_notif_type := 'appointment_cancelled';
          v_title := 'تم إلغاء الموعد';
          v_body := 'تم إلغاء: ' || NEW.title;
          -- Coordinator cancelled — notify managers
          FOREACH v_recipient_id IN ARRAY v_manager_ids LOOP
            INSERT INTO notifications (recipient_id, type, title, body, appointment_id)
            VALUES (v_recipient_id, v_notif_type, v_title, v_body, NEW.id);
          END LOOP;

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
```

---

## 5. Appointment Workflow & State Machine

### 5.1 Statuses

| Status        | Arabic            | Description                                      |
| :------------ | :---------------- | :----------------------------------------------- |
| `pending`     | بانتظار الموافقة  | Created by Coordinator, awaiting Manager review   |
| `confirmed`   | مؤكد              | Approved by Manager (or auto-confirmed for ministry) |
| `rejected`    | مرفوض             | Rejected by Manager                              |
| `suggested`   | مقترح وقت بديل    | Manager suggested an alternative time             |
| `cancelled`   | ملغي              | Cancelled by Coordinator                         |

### 5.2 State Transition Diagram

```
                    ┌──────────────────────────────────┐
                    │       MINISTRY MEETING            │
                    │  (auto-confirmed on creation)     │
                    │         ┌───────────┐             │
                    │  ──────►│ confirmed │ (final)     │
                    │         └───────────┘             │
                    └──────────────────────────────────┘

                    ┌──────────────────────────────────────────┐
                    │   PATIENT / EXTERNAL APPOINTMENT          │
                    │                                          │
                    │         ┌─────────┐                      │
                    │  ──────►│ pending │──┬──► confirmed      │
                    │         └─────────┘  │                   │
                    │              │        ├──► rejected       │
                    │              │        │                   │
                    │              │        └──► suggested ─┐   │
                    │              │                        │   │
                    │              ▼                        │   │
                    │         cancelled                     │   │
                    │                                      │   │
                    │     ┌────────────────────────────────┘   │
                    │     │  Coordinator accepts suggestion:   │
                    │     │    ──► confirmed                   │
                    │     │  Coordinator rejects suggestion:   │
                    │     │    ──► pending (new cycle)         │
                    │     └────────────────────────────────────│
                    └──────────────────────────────────────────┘
```

### 5.3 Transition Table

| From        | To          | Triggered By  | Conditions                              | Side Effects                            |
| :---------- | :---------- | :------------ | :-------------------------------------- | :-------------------------------------- |
| *(new)*     | `confirmed` | System        | `type = 'ministry'`                     | Auto-set by `trg_ministry_auto_confirm` trigger. Notify managers. |
| *(new)*     | `pending`   | Coordinator   | `type != 'ministry'`                    | Notify managers of new appointment.     |
| `pending`   | `confirmed` | Manager       | —                                       | Set `reviewed_by`, `reviewed_at`. Notify coordinator. |
| `pending`   | `rejected`  | Manager       | —                                       | Set `reviewed_by`, `reviewed_at`. Notify coordinator. |
| `pending`   | `suggested` | Manager       | Must create row in `appointment_suggestions` | Notify coordinator of alternative.      |
| `pending`   | `cancelled` | Coordinator   | `created_by = auth.uid()`               | Notify managers.                        |
| `suggested` | `confirmed` | Coordinator   | Accepts suggestion → updates `start_time`/`end_time` | Deactivate suggestion. Notify managers. |
| `suggested` | `pending`   | Coordinator   | Rejects suggestion                      | Deactivate suggestion. Notify managers. |
| `confirmed` | `cancelled` | Coordinator   | `type != 'ministry'`                    | Notify managers.                        |

**Terminal states**: `rejected` and `cancelled` are final — no transitions out. A rejected appointment cannot be re-submitted; the Coordinator creates a new one instead. Ministry `confirmed` is also final (immutable).

### 5.4 Ministry Meeting Special Rules

1. **Auto-confirmed**: The `trg_ministry_auto_confirm` trigger sets `status = 'confirmed'` before insert.
2. **Immutable**: Cannot be edited, rejected, suggested, or cancelled after creation. Enforced via RLS policy (coordinator update policy excludes `type = 'ministry'`).
3. **Overlap blocking**: The `excl_ministry_overlap` exclusion constraint prevents any two confirmed ministry meetings from overlapping. The `check_appointment_overlap()` RPC also flags ministry conflicts as hard blocks in the UI.

### 5.5 "Suggest Alternative Time" Flow

1. Manager views a `pending` appointment and taps "اقتراح وقت بديل" (Suggest Alternative).
2. Manager selects a new `start_time` and `end_time`, optionally adds a message.
3. Client calls `check_appointment_overlap()` RPC for the suggested time to verify no ministry conflicts.
4. Client inserts a row into `appointment_suggestions` and updates the appointment `status` to `suggested`.
5. Coordinator receives a notification: "اقتراح وقت بديل".
6. Coordinator views the suggestion on the appointment detail screen.
7. **If Coordinator accepts**: appointment `start_time`/`end_time` are updated to the suggested times, `status` → `confirmed`, suggestion `is_active` → `false`.
8. **If Coordinator rejects**: `status` → `pending` (back to review queue), suggestion `is_active` → `false`.
9. The cycle can repeat — Manager can suggest again from `pending`.

---

## 6. Screen Inventory & Navigation

### 6.1 Expo Router File Structure

```
app/
├── _layout.tsx              ← Root layout: auth gate, RTL setup, font loading
├── login.tsx                ← Login screen
├── (coordinator)/
│   ├── _layout.tsx          ← Tab navigator for coordinator
│   ├── index.tsx            ← Dashboard (today's appointments, pending count)
│   ├── calendar.tsx         ← Full calendar view (month/week/day)
│   ├── create.tsx           ← Create new appointment form
│   ├── [id].tsx             ← Appointment detail (view, edit, accept/reject suggestion)
│   ├── notifications.tsx    ← Notification list
│   └── settings.tsx         ← Settings (account info, push token)
├── (manager)/
│   ├── _layout.tsx          ← Tab navigator for manager
│   ├── index.tsx            ← Pending queue (appointments awaiting action)
│   ├── calendar.tsx         ← Full calendar view (read-only overview)
│   ├── [id].tsx             ← Appointment detail (approve, reject, suggest)
│   ├── suggest/[id].tsx     ← Suggest alternative time form
│   ├── notifications.tsx    ← Notification list
│   └── settings.tsx         ← Settings (account info, push token)
└── +not-found.tsx           ← 404 fallback
```

### 6.2 Screen Descriptions

#### Auth

| Screen   | Route          | Description                                   |
| :------- | :------------- | :-------------------------------------------- |
| Login    | `/login`       | Email + password form. Redirects by role on success. |

#### Coordinator Screens

| Screen              | Route                     | Description                                                        |
| :------------------ | :------------------------ | :----------------------------------------------------------------- |
| Dashboard           | `/(coordinator)/`         | Today's agenda, count of pending/confirmed appointments.           |
| Calendar            | `/(coordinator)/calendar` | Month/week/day view of all appointments, color-coded by type.      |
| Create Appointment  | `/(coordinator)/create`   | Form: title, type, date/time range, location/notes. Runs conflict check before submit. |
| Appointment Detail  | `/(coordinator)/[id]`     | Full details. Shows suggestion if `status = 'suggested'`. Accept/reject suggestion buttons. Edit/cancel for non-ministry. |
| Notifications       | `/(coordinator)/notifications` | List of notifications with read/unread state.                 |
| Settings            | `/(coordinator)/settings` | Display name, role, sign out button.                               |

#### Manager Screens

| Screen              | Route                     | Description                                                        |
| :------------------ | :------------------------ | :----------------------------------------------------------------- |
| Pending Queue       | `/(manager)/`             | List of `pending` appointments sorted by `start_time`.             |
| Calendar            | `/(manager)/calendar`     | Month/week/day view of all appointments (read-only overview).      |
| Appointment Detail  | `/(manager)/[id]`         | Full details. Approve/reject/suggest buttons for `pending`. View-only for other statuses. |
| Suggest Alternative | `/(manager)/suggest/[id]` | Date/time picker + optional message. Conflict check before submit. |
| Notifications       | `/(manager)/notifications`| List of notifications with read/unread state.                      |
| Settings            | `/(manager)/settings`     | Display name, role, sign out button.                               |

### 6.3 Navigation Flow

```
App Launch
  │
  ▼
Root _layout.tsx
  │
  ├── No session? ──► /login
  │
  └── Has session?
        │
        ├── Fetch profile → role = 'coordinator'
        │     └──► Redirect to /(coordinator)/
        │
        └── Fetch profile → role = 'manager'
              └──► Redirect to /(manager)/
```

---

## 7. Real-time Strategy

### 7.1 Channels

| Channel                         | Table                    | Filter                          | Purpose                              |
| :------------------------------ | :----------------------- | :------------------------------ | :----------------------------------- |
| `realtime:appointments`         | `appointments`           | None (all rows)                 | Calendar stays in sync across both roles |
| `realtime:notifications:{uid}`  | `notifications`          | `recipient_id=eq.{uid}`         | Per-user notification delivery       |
| `realtime:suggestions`          | `appointment_suggestions`| None                            | Coordinator sees new suggestions live |

### 7.2 Hook Pattern

```typescript
// hooks/useRealtimeSubscriptions.ts
import { useEffect } from 'react';
import { supabase } from '@/services/supabase';
import { useAuthStore } from '@/stores/authStore';
import { useAppointmentStore } from '@/stores/appointmentStore';
import { useNotificationStore } from '@/stores/notificationStore';

export function useRealtimeSubscriptions() {
  const userId = useAuthStore((s) => s.profile?.id);

  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel('app-realtime')
      // Appointments: all changes
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'appointments' },
        (payload) => {
          useAppointmentStore.getState().handleRealtimeEvent(payload);
        }
      )
      // Notifications: filtered to current user
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `recipient_id=eq.${userId}`,
        },
        (payload) => {
          useNotificationStore.getState().handleNewNotification(payload.new);
        }
      )
      // Suggestions: all changes
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'appointment_suggestions' },
        (payload) => {
          useAppointmentStore.getState().handleSuggestionEvent(payload);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId]);
}
```

### 7.3 Optimistic Updates

- When the Coordinator creates an appointment, the store adds it to the local list immediately with a temporary ID.
- On server confirmation (via Realtime event), replace the temporary entry with the server's canonical row.
- If the insert fails, remove the temporary entry and show an error toast.

### 7.4 Reconnection

- Use Expo's `AppState` listener. When the app moves from `background` to `active`, re-fetch the latest appointments and notifications to catch any missed Realtime events.
- Supabase Realtime client auto-reconnects on WebSocket disconnect.

---

## 8. Notification Design

### 8.1 Notification Event Types

| Event                     | Recipient    | Arabic Title             | Arabic Body Template                           |
| :------------------------ | :----------- | :----------------------- | :--------------------------------------------- |
| `new_appointment`         | Manager(s)   | موعد جديد بانتظار الموافقة | موعد جديد: {title}                             |
| `appointment_confirmed`   | Coordinator  | تم تأكيد الموعد           | تم تأكيد: {title}                              |
| `appointment_rejected`    | Coordinator  | تم رفض الموعد             | تم رفض: {title}                                |
| `alternative_suggested`   | Coordinator  | اقتراح وقت بديل          | تم اقتراح وقت بديل لـ: {title}                 |
| `suggestion_accepted`     | Manager(s)   | تم قبول الاقتراح          | تم قبول الوقت البديل لـ: {title}                |
| `suggestion_rejected`     | Manager(s)   | تم رفض الاقتراح           | تم رفض الوقت البديل لـ: {title}                 |
| `appointment_cancelled`   | Other party  | تم إلغاء الموعد           | تم إلغاء: {title}                              |
| `ministry_auto_confirmed` | Manager(s)   | إجتماع وزارة جديد        | تم تأكيد إجتماع وزارة: {title}                 |

### 8.2 In-App Notifications

- **Badge count**: Shown on the notifications tab icon. Count of `is_read = false` notifications.
- **Toast**: When a Realtime `INSERT` on `notifications` is received while the app is in the foreground, show a toast (e.g., using `react-native-toast-message`).
- **Notification list screen**: Sorted by `created_at DESC`. Tapping a notification marks it as read and navigates to the related appointment detail.

### 8.3 Push Notifications

Push notifications are delivered via a Supabase Edge Function that calls the Expo Push API.

```
supabase/functions/send-push/index.ts
```

**Flow:**

1. The `trg_notify_appointment` trigger inserts a row into `notifications`.
2. A separate database trigger (or webhook) on `notifications` INSERT calls the `send-push` Edge Function.
3. The Edge Function reads the recipient's `push_token` from `profiles`.
4. If the token exists, it sends a push via `https://exp.host/--/api/v2/push/send`.

**Edge Function sketch:**

```typescript
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  const { record } = await req.json(); // notification row from webhook

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data: profile } = await supabase
    .from('profiles')
    .select('push_token')
    .eq('id', record.recipient_id)
    .single();

  if (!profile?.push_token) {
    return new Response(JSON.stringify({ skipped: true }), { status: 200 });
  }

  const pushResponse = await fetch('https://exp.host/--/api/v2/push/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      to: profile.push_token,
      title: record.title,
      body: record.body,
      data: { appointmentId: record.appointment_id },
    }),
  });

  const result = await pushResponse.json();
  return new Response(JSON.stringify(result), { status: 200 });
});
```

---

## 9. Conflict Detection

### 9.1 Rules

| Conflict Type                    | Severity    | Behavior                                                 |
| :------------------------------- | :---------- | :------------------------------------------------------- |
| Overlaps with a **confirmed ministry** meeting | **Hard block** | Insert/update is rejected. UI shows error.         |
| Overlaps with any other `pending`/`confirmed` appointment | **Warning** | UI shows warning with list of conflicts. User can proceed. |
| No overlaps                      | None        | Insert proceeds normally.                                |

### 9.2 Client-Side Flow

1. Before submitting a new appointment (or accepting a suggestion), the client calls the `check_appointment_overlap()` RPC:

```typescript
const { data: conflicts } = await supabase
  .rpc('check_appointment_overlap', {
    p_start_time: startTime,
    p_end_time: endTime,
    p_exclude_id: existingAppointmentId ?? null, // exclude self on edit
  });
```

2. If any conflict has `type = 'ministry'` and `status = 'confirmed'`, display a hard-block error — the form cannot be submitted.
3. If conflicts exist but none are ministry, show a warning dialog listing the conflicting appointments. The user can choose to proceed or adjust the time.

### 9.3 Database-Level Safety Net

The `excl_ministry_overlap` exclusion constraint (Section 4.3) ensures that even if the client-side check is bypassed, the database will reject an overlapping confirmed ministry meeting at the SQL level.

### 9.4 Suggestion Conflict Check

When a Manager suggests an alternative time, the same `check_appointment_overlap()` RPC is called for the suggested time range. Ministry hard blocks apply. When a Coordinator accepts a suggestion, the conflict check runs again (the conflict landscape may have changed since the suggestion was created).

---

## 10. Arabic RTL Strategy

### 10.1 Force RTL at App Level

In the root layout (`app/_layout.tsx`):

```typescript
import { I18nManager } from 'react-native';

// Force RTL before any rendering
if (!I18nManager.isRTL) {
  I18nManager.forceRTL(true);
  I18nManager.allowRTL(true);
  // On native, a reload is required after forcing RTL.
  // Expo handles this via the expo-updates or a manual restart on first launch.
}
```

Also set in `app.json`:

```json
{
  "expo": {
    "extra": {
      "supportsRTL": true,
      "forcesRTL": true
    }
  }
}
```

### 10.2 NativeWind Logical Properties

Use logical (start/end) properties instead of left/right:

| Physical (avoid) | Logical (use)   | Meaning in RTL |
| :---------------- | :-------------- | :------------- |
| `pl-4`           | `ps-4`           | padding-right  |
| `pr-4`           | `pe-4`           | padding-left   |
| `ml-4`           | `ms-4`           | margin-right   |
| `mr-4`           | `me-4`           | margin-left    |
| `text-left`      | `text-start`     | text-right     |
| `text-right`     | `text-end`       | text-left      |

### 10.3 Font

Use **IBM Plex Arabic** loaded via `expo-font`:

```typescript
import { useFonts } from 'expo-font';

const [fontsLoaded] = useFonts({
  'IBMPlexArabic-Regular': require('@/assets/fonts/IBMPlexSansArabic-Regular.ttf'),
  'IBMPlexArabic-Medium': require('@/assets/fonts/IBMPlexSansArabic-Medium.ttf'),
  'IBMPlexArabic-Bold': require('@/assets/fonts/IBMPlexSansArabic-Bold.ttf'),
});
```

Set as default in `tailwind.config.js`:

```javascript
module.exports = {
  theme: {
    fontFamily: {
      sans: ['IBMPlexArabic-Regular'],
      medium: ['IBMPlexArabic-Medium'],
      bold: ['IBMPlexArabic-Bold'],
    },
  },
};
```

### 10.4 Date & Number Formatting

Use `Intl.DateTimeFormat` with Arabic-Saudi locale and Arabic-Indic numerals:

```typescript
// utils/formatDate.ts
export function formatDate(date: Date): string {
  return new Intl.DateTimeFormat('ar-SA-u-nu-arab', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(date);
}

export function formatTime(date: Date): string {
  return new Intl.DateTimeFormat('ar-SA-u-nu-arab', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  }).format(date);
}
```

### 10.5 Arabic Strings

No i18n library. All Arabic strings live in a single file:

```
constants/strings.ts
```

```typescript
export const STRINGS = {
  // Auth
  login: 'تسجيل الدخول',
  email: 'البريد الإلكتروني',
  password: 'كلمة المرور',
  loginButton: 'دخول',
  loginError: 'البريد أو كلمة المرور غير صحيحة',

  // Appointment types
  ministry: 'إجتماع وزارة',
  patient: 'موعد مريض',
  external: 'موعد خارجي',

  // Statuses
  pending: 'بانتظار الموافقة',
  confirmed: 'مؤكد',
  rejected: 'مرفوض',
  suggested: 'مقترح وقت بديل',
  cancelled: 'ملغي',

  // Actions
  approve: 'موافقة',
  reject: 'رفض',
  suggestAlternative: 'اقتراح وقت بديل',
  acceptSuggestion: 'قبول الاقتراح',
  rejectSuggestion: 'رفض الاقتراح',
  cancel: 'إلغاء',
  save: 'حفظ',
  create: 'إنشاء',
  delete: 'حذف',
  signOut: 'تسجيل الخروج',

  // Notifications
  notifications: 'الإشعارات',
  noNotifications: 'لا توجد إشعارات',

  // Calendar
  calendar: 'التقويم',
  today: 'اليوم',
  noAppointments: 'لا توجد مواعيد',

  // Dashboard
  dashboard: 'الرئيسية',
  pendingCount: 'بانتظار الموافقة',
  confirmedCount: 'مؤكدة',
  todaySchedule: 'جدول اليوم',

  // Errors
  conflictMinistry: 'يوجد تعارض مع إجتماع وزارة — لا يمكن الحجز في هذا الوقت',
  conflictWarning: 'يوجد تعارض مع مواعيد أخرى',
  conflictProceed: 'متابعة رغم التعارض',
  networkError: 'خطأ في الاتصال',
  genericError: 'حدث خطأ، حاول مرة أخرى',

  // Settings
  settings: 'الإعدادات',
} as const;
```

---

## 11. Project Structure

```
mawaid/
├── app/
│   ├── _layout.tsx
│   ├── login.tsx
│   ├── +not-found.tsx
│   ├── (coordinator)/
│   │   ├── _layout.tsx
│   │   ├── index.tsx
│   │   ├── calendar.tsx
│   │   ├── create.tsx
│   │   ├── [id].tsx
│   │   ├── notifications.tsx
│   │   └── settings.tsx
│   └── (manager)/
│       ├── _layout.tsx
│       ├── index.tsx
│       ├── calendar.tsx
│       ├── [id].tsx
│       ├── suggest/[id].tsx
│       ├── notifications.tsx
│       └── settings.tsx
├── components/
│   ├── AppointmentCard.tsx
│   ├── AppointmentForm.tsx
│   ├── CalendarView.tsx
│   ├── ConflictDialog.tsx
│   ├── NotificationItem.tsx
│   ├── SuggestionCard.tsx
│   ├── StatusBadge.tsx
│   ├── Toast.tsx
│   └── ui/
│       ├── Button.tsx
│       ├── Input.tsx
│       ├── DateTimePicker.tsx
│       └── Card.tsx
├── stores/
│   ├── authStore.ts
│   ├── appointmentStore.ts
│   └── notificationStore.ts
├── services/
│   └── supabase.ts
├── hooks/
│   ├── useRealtimeSubscriptions.ts
│   └── useConflictCheck.ts
├── constants/
│   ├── strings.ts
│   └── colors.ts
├── types/
│   └── database.ts
├── utils/
│   ├── formatDate.ts
│   └── pushToken.ts
├── assets/
│   └── fonts/
│       ├── IBMPlexSansArabic-Regular.ttf
│       ├── IBMPlexSansArabic-Medium.ttf
│       └── IBMPlexSansArabic-Bold.ttf
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   │   ├── 00001_create_enums.sql
│   │   ├── 00002_create_profiles.sql
│   │   ├── 00003_create_appointments.sql
│   │   ├── 00004_create_suggestions.sql
│   │   ├── 00005_create_notifications.sql
│   │   ├── 00006_create_rls_policies.sql
│   │   ├── 00007_create_functions_triggers.sql
│   │   └── 00008_seed_data.sql
│   └── functions/
│       └── send-push/
│           └── index.ts
├── app.json
├── tailwind.config.js
├── tsconfig.json
├── package.json
└── docs/
    └── ARCHITECTURE.md
```

---

## 12. Auth Flow

### 12.1 Account Creation

This is an internal office application — there is no self-registration. User accounts are created in one of two ways:

1. **Supabase Studio**: Admin navigates to `localhost:54323` → Authentication → Create User. User metadata must include `role` and `full_name`:
   ```json
   { "role": "coordinator", "full_name": "أحمد المنسق" }
   ```
2. **Seed script**: The `00008_seed_data.sql` migration (or a separate script) creates users via the Supabase Admin API.

The `handle_new_user()` trigger (Section 4.7) automatically creates the `profiles` row from the user metadata.

### 12.2 Login Flow

```
User enters email + password
  │
  ▼
supabase.auth.signInWithPassword({ email, password })
  │
  ├── Error? → Show Arabic error message
  │
  └── Success → session stored automatically
        │
        ▼
  Fetch profile: supabase.from('profiles').select('*').eq('id', user.id).single()
        │
        ▼
  Store profile in authStore
        │
        ▼
  Register push token (if on native)
        │
        ▼
  Router redirect based on role:
    coordinator → /(coordinator)/
    manager     → /(manager)/
```

### 12.3 Session Persistence

```typescript
// services/supabase.ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
```

### 12.4 Auth Store (Zustand)

```typescript
// stores/authStore.ts
import { create } from 'zustand';
import { supabase } from '@/services/supabase';
import type { Profile } from '@/types/database';

interface AuthState {
  session: Session | null;
  profile: Profile | null;
  isLoading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  fetchProfile: () => Promise<void>;
  initialize: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  session: null,
  profile: null,
  isLoading: true,

  initialize: async () => {
    const { data: { session } } = await supabase.auth.getSession();
    set({ session });
    if (session) {
      await get().fetchProfile();
    }
    set({ isLoading: false });

    // Listen for auth state changes
    supabase.auth.onAuthStateChange((_event, session) => {
      set({ session });
      if (!session) set({ profile: null });
    });
  },

  signIn: async (email, password) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    await get().fetchProfile();
  },

  signOut: async () => {
    await supabase.auth.signOut();
    set({ session: null, profile: null });
  },

  fetchProfile: async () => {
    const userId = (await supabase.auth.getUser()).data.user?.id;
    if (!userId) return;
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();
    set({ profile: data });
  },
}));
```

### 12.5 Protected Routes (Root Layout)

```typescript
// app/_layout.tsx (simplified)
import { useEffect } from 'react';
import { useRouter, useSegments, Slot } from 'expo-router';
import { useAuthStore } from '@/stores/authStore';

export default function RootLayout() {
  const router = useRouter();
  const segments = useSegments();
  const { session, profile, isLoading, initialize } = useAuthStore();

  useEffect(() => {
    initialize();
  }, []);

  useEffect(() => {
    if (isLoading) return;

    const inAuthGroup = segments[0] === 'login';

    if (!session && !inAuthGroup) {
      router.replace('/login');
    } else if (session && profile) {
      const targetGroup = `(${profile.role})`;
      if (segments[0] !== targetGroup) {
        router.replace(`/${targetGroup}/`);
      }
    }
  }, [session, profile, isLoading, segments]);

  if (isLoading) return null; // or a splash screen

  return <Slot />;
}
```

---

## 13. Docker / Self-Hosted Supabase Setup

### 13.1 Overview

Supabase is run self-hosted via Docker Compose. This provides the full Supabase stack locally or on a server:

| Service          | Container              | Port  | Purpose                        |
| :--------------- | :--------------------- | :---- | :----------------------------- |
| PostgreSQL       | `supabase-db`          | 54322 | Primary database               |
| Auth (GoTrue)    | `supabase-auth`        | 9999  | Email/password authentication  |
| Realtime         | `supabase-realtime`    | 4000  | WebSocket subscriptions        |
| PostgREST        | `supabase-rest`        | 3000  | Auto-generated REST API        |
| Storage          | `supabase-storage`     | 5000  | File storage (not used yet)    |
| Edge Functions   | `supabase-edge-functions`| 54321| Deno-based serverless functions|
| Studio           | `supabase-studio`      | 54323 | Admin dashboard (web UI)       |
| Kong             | `supabase-kong`        | 8000  | API gateway                    |

### 13.2 Setup Steps

```bash
# 1. Install the Supabase CLI
npm install -g supabase

# 2. Initialize the project (if not already done)
supabase init

# 3. Start all services locally
supabase start

# 4. Apply migrations
supabase db push

# 5. Serve Edge Functions locally
supabase functions serve send-push --env-file .env.local

# 6. Open Studio for admin tasks
# Navigate to http://localhost:54323
```

### 13.3 Environment Variables

Create `.env.local` for development:

```env
EXPO_PUBLIC_SUPABASE_URL=http://localhost:54321
EXPO_PUBLIC_SUPABASE_ANON_KEY=<your-anon-key-from-supabase-start-output>
```

For the Edge Functions (`.env.local` in `supabase/functions/`):

```env
SUPABASE_URL=http://localhost:54321
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
```

### 13.4 Production Deployment

For production on a VPS/server:

1. Clone the [supabase/supabase](https://github.com/supabase/supabase) Docker directory.
2. Configure `.env` with production secrets (JWT secret, database password, API keys).
3. Run `docker compose up -d`.
4. Point `EXPO_PUBLIC_SUPABASE_URL` to the server's public address.
5. Apply migrations: `supabase db push --db-url postgres://postgres:<password>@<host>:54322/postgres`.
6. Deploy Edge Functions: `supabase functions deploy send-push --project-ref <ref>`.

### 13.5 Supabase Studio Admin Tasks

Access Studio at `http://localhost:54323` (or the server URL in production) to:

- **Create user accounts**: Authentication → Users → Create User (include `role` and `full_name` in metadata).
- **Inspect data**: Table Editor → browse `appointments`, `profiles`, `notifications`, `appointment_suggestions`.
- **Run SQL**: SQL Editor → execute ad-hoc queries for debugging.
- **View logs**: Logs Explorer → monitor Edge Function invocations and auth events.

---

## 14. Verification & Testing

### 14.1 Manual Testing Checklist

#### Auth
- [ ] Login with valid coordinator credentials → redirects to coordinator dashboard
- [ ] Login with valid manager credentials → redirects to manager pending queue
- [ ] Login with wrong password → shows Arabic error
- [ ] Login with non-existent email → shows Arabic error
- [ ] App restart → session persists, auto-redirects to correct screen
- [ ] Sign out → redirects to login, session cleared
- [ ] Access coordinator route as manager → redirected to manager route
- [ ] Access manager route as coordinator → redirected to coordinator route

#### Appointment CRUD (Coordinator)
- [ ] Create ministry meeting → status auto-set to `confirmed`
- [ ] Create patient appointment → status is `pending`
- [ ] Create external meeting → status is `pending`, location field accepts text
- [ ] Edit a pending patient appointment → changes saved
- [ ] Cannot edit a ministry meeting → UI prevents it
- [ ] Delete a pending patient appointment → removed from list
- [ ] Cannot delete a confirmed appointment → UI prevents it

#### Approval Workflow (Manager)
- [ ] Pending queue shows only `pending` appointments
- [ ] Approve appointment → status changes to `confirmed`
- [ ] Reject appointment → status changes to `rejected`
- [ ] Suggest alternative → status changes to `suggested`, suggestion row created
- [ ] Cannot modify a ministry meeting → no action buttons shown

#### Suggestion Flow
- [ ] Manager suggests alternative time → Coordinator notified
- [ ] Coordinator views suggestion details on appointment detail screen
- [ ] Coordinator accepts suggestion → appointment time updated, status → `confirmed`
- [ ] Coordinator rejects suggestion → status → `pending`, back in Manager queue
- [ ] Manager can suggest again after rejection → new cycle

#### Real-time
- [ ] Coordinator creates appointment → appears on Manager's pending queue without refresh
- [ ] Manager approves → Coordinator's calendar updates without refresh
- [ ] Notification appears on recipient's notification tab in real-time
- [ ] App backgrounded and foregrounded → data refreshed

#### Notifications
- [ ] New appointment → managers receive notification
- [ ] Appointment confirmed → coordinator receives notification
- [ ] Appointment rejected → coordinator receives notification
- [ ] Alternative suggested → coordinator receives notification
- [ ] Tapping notification → navigates to appointment detail
- [ ] Unread badge count updates correctly
- [ ] Mark notification as read → badge count decreases

#### Conflict Detection
- [ ] Create appointment overlapping confirmed ministry → hard block error shown
- [ ] Create appointment overlapping pending patient → warning shown, can proceed
- [ ] Suggest time overlapping confirmed ministry → hard block error
- [ ] Accept suggestion that now conflicts with ministry (created after suggestion) → error

#### RTL & Arabic
- [ ] App layout is right-to-left
- [ ] Text alignment is correct (right-aligned)
- [ ] Dates display in Arabic numerals and Arabic month names
- [ ] All UI text is in Arabic
- [ ] IBM Plex Arabic font renders correctly

#### Calendar
- [ ] Month view shows appointments as colored dots/indicators
- [ ] Day view shows appointment blocks
- [ ] Appointments color-coded by type
- [ ] Tapping appointment → navigates to detail

### 14.2 Key End-to-End Flows

1. **Ministry meeting creation**: Coordinator creates → auto-confirmed → appears on Manager's calendar → Manager receives notification → Manager cannot modify.

2. **Standard approval**: Coordinator creates patient appointment → Manager sees in pending queue → Manager approves → Coordinator notified → both calendars updated.

3. **Rejection**: Coordinator creates → Manager rejects → Coordinator notified → appointment shows as rejected.

4. **Suggest alternative (full cycle)**: Coordinator creates → Manager suggests alternative → Coordinator notified → Coordinator accepts → appointment time updated → both calendars updated.

5. **Suggestion rejection cycle**: Coordinator creates → Manager suggests → Coordinator rejects suggestion → appointment back to pending → Manager suggests again → Coordinator accepts.

6. **Conflict detection**: Coordinator creates ministry meeting 9:00–10:00 → Coordinator tries to create patient appointment 9:30–10:30 → warning shown (non-ministry overlap allowed) → Coordinator tries to create another ministry meeting 9:00–10:00 → hard block.

### 14.3 Database Verification Queries

```sql
-- Verify RLS is enabled on all tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'appointments', 'appointment_suggestions', 'notifications');

-- Verify triggers exist
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public';

-- Verify exclusion constraint exists
SELECT conname, contype
FROM pg_constraint
WHERE conname = 'excl_ministry_overlap';

-- Test overlap detection
SELECT * FROM check_appointment_overlap(
  '2026-03-01 09:00:00+03',
  '2026-03-01 10:00:00+03'
);

-- Verify ministry auto-confirm trigger
INSERT INTO appointments (title, type, start_time, end_time, created_by)
VALUES ('Test Ministry', 'ministry', '2026-04-01 09:00:00+03', '2026-04-01 10:00:00+03', '<coordinator-uuid>');
-- Check: status should be 'confirmed'
SELECT status FROM appointments WHERE title = 'Test Ministry';

-- Verify notification was auto-created
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;
```
