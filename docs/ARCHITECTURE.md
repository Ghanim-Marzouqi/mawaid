# Architecture Document: Mawa'id (مواعيد)

## 1. Executive Summary

**Mawa'id** is a specialized appointment management system designed for a high-level environment (e.g., a Director's office). The application streamlines the coordination between a **Coordinator** and a **Manager**, focusing on three specific appointment types with varying levels of priority and authority.

The Coordinator (منى) creates and manages appointments. The Manager (حاتم) reviews, approves, rejects, or suggests alternatives. Both users can access the app from **desktop or mobile** — the UI is fully responsive. Ministry meetings are auto-confirmed and cannot be overlapped. The system is Arabic-only (RTL), uses the Gregorian calendar, and runs on a self-hosted Supabase backend.

The Flutter app targets **web** (not native mobile) and is designed as an installable PWA, allowing it to be added to a mobile device's home screen. Both the app and the Supabase backend are self-hosted via Docker.

---

## 2. Technical Stack

| Layer              | Technology                                          |
| :----------------- | :-------------------------------------------------- |
| **Framework**      | Flutter 3.41+ (Dart 3.11+) — **Web target** (PWA)  |
| **Routing**        | GoRouter ^17.1.0 (declarative, path-based)          |
| **Styling**        | Flutter Material Design 3 + custom theme            |
| **Icons**          | Lucide Icons (`lucide_icons_flutter` ^3.1.9)        |
| **State**          | Riverpod v3 (`flutter_riverpod` ^3.2.1)             |
| **Backend**        | Supabase self-hosted (Docker)                       |
| **Database**       | PostgreSQL 17 (via Supabase)                        |
| **Auth**           | Supabase Auth (email + password)                    |
| **Real-time**      | Supabase Realtime (WebSocket channels)              |
| **Push**           | Web Push Notifications (via Supabase Edge Functions) |
| **Language**       | Arabic only (RTL) — `flutter_localizations` + hardcoded strings |
| **Calendar**       | Gregorian (Arabic locale `ar`, date formatting via `ar_OM`) |
| **Timezone**       | `Asia/Muscat` (GMT+4) — enforced at all layers      |
| **Font**           | Readex Pro (via `pubspec.yaml` assets / Google Fonts) |
| **Hosting**        | Docker (Nginx serving Flutter web build + Supabase)  |

---

## 3. System Architecture & Roles

### A. User Roles

| Role            | Primary Interface | Permissions                                                        |
| :-------------- | :---------------- | :----------------------------------------------------------------- |
| **Coordinator** (منى) | Desktop & Mobile  | Create, Edit, Delete, View Calendar, Track Approval Status         |
| **Manager** (حاتم)    | Desktop & Mobile  | View Pending, Approve, Reject, Suggest Alternative Time            |

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

### 4.8 Dart Model Classes

These models map directly to the database tables. Each model has a `fromJson()` factory for Supabase responses and a `toJson()` method for inserts/updates.

#### Enums

```dart
// lib/models/enums.dart
enum UserRole { coordinator, manager }

enum AppointmentType { ministry, patient, external_ }

enum AppointmentStatus { pending, confirmed, rejected, suggested, cancelled }

enum NotificationType {
  newAppointment,
  appointmentConfirmed,
  appointmentRejected,
  alternativeSuggested,
  suggestionAccepted,
  suggestionRejected,
  appointmentCancelled,
  ministryAutoConfirmed,
}

// Helpers to convert between Dart enums and database string values
extension AppointmentTypeX on AppointmentType {
  String toDb() => switch (this) {
    AppointmentType.ministry => 'ministry',
    AppointmentType.patient => 'patient',
    AppointmentType.external_ => 'external',
  };
  static AppointmentType fromDb(String v) => switch (v) {
    'ministry' => AppointmentType.ministry,
    'patient' => AppointmentType.patient,
    'external' => AppointmentType.external_,
    _ => throw ArgumentError('Unknown AppointmentType: $v'),
  };
}

extension AppointmentStatusX on AppointmentStatus {
  String toDb() => name; // enum names match DB values
  static AppointmentStatus fromDb(String v) =>
      AppointmentStatus.values.firstWhere((e) => e.name == v);
}
```

#### Profile

```dart
// lib/models/profile.dart
class Profile {
  final String id;
  final String role; // 'coordinator' or 'manager'
  final String fullName;
  final String? pushToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.pushToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'],
    role: json['role'],
    fullName: json['full_name'],
    pushToken: json['push_token'],
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
```

#### Appointment

```dart
// lib/models/appointment.dart
class Appointment {
  final String id;
  final String title;
  final AppointmentType type;
  final AppointmentStatus status;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? notes;
  final String createdBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({ /* all fields required/optional as above */ });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'],
    title: json['title'],
    type: AppointmentTypeX.fromDb(json['type']),
    status: AppointmentStatusX.fromDb(json['status']),
    startTime: DateTime.parse(json['start_time']),
    endTime: DateTime.parse(json['end_time']),
    location: json['location'],
    notes: json['notes'],
    createdBy: json['created_by'],
    reviewedBy: json['reviewed_by'],
    reviewedAt: json['reviewed_at'] != null
        ? DateTime.parse(json['reviewed_at'])
        : null,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );

  Map<String, dynamic> toJsonForInsert() => {
    'title': title,
    'type': type.toDb(),
    'start_time': startTime.toUtc().toIso8601String(),
    'end_time': endTime.toUtc().toIso8601String(),
    'location': location,
    'notes': notes,
    // created_by is set automatically via RLS (auth.uid())
  };
}
```

#### AppointmentSuggestion

```dart
// lib/models/appointment_suggestion.dart
class AppointmentSuggestion {
  final String id;
  final String appointmentId;
  final String suggestedBy;
  final DateTime suggestedStart;
  final DateTime suggestedEnd;
  final String? message;
  final bool isActive;
  final DateTime createdAt;

  const AppointmentSuggestion({ /* all fields */ });

  factory AppointmentSuggestion.fromJson(Map<String, dynamic> json) =>
      AppointmentSuggestion(
        id: json['id'],
        appointmentId: json['appointment_id'],
        suggestedBy: json['suggested_by'],
        suggestedStart: DateTime.parse(json['suggested_start']),
        suggestedEnd: DateTime.parse(json['suggested_end']),
        message: json['message'],
        isActive: json['is_active'],
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJsonForInsert() => {
    'appointment_id': appointmentId,
    'suggested_start': suggestedStart.toUtc().toIso8601String(),
    'suggested_end': suggestedEnd.toUtc().toIso8601String(),
    'message': message,
  };
}
```

#### AppNotification

```dart
// lib/models/notification.dart
class AppNotification {
  final String id;
  final String recipientId;
  final String type;
  final String title;
  final String body;
  final String? appointmentId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({ /* all fields */ });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        recipientId: json['recipient_id'],
        type: json['type'],
        title: json['title'],
        body: json['body'],
        appointmentId: json['appointment_id'],
        isRead: json['is_read'],
        createdAt: DateTime.parse(json['created_at']),
      );
}
```

### 4.9 Supabase Client Query Examples

These are the key Supabase queries used throughout the app. All queries go through RLS — the authenticated user's role determines what they can read/write.

```dart
// ─── Fetch all appointments (both roles) ───
final appointments = await supabase
    .from('appointments')
    .select()
    .order('start_time');

// ─── Fetch appointments for a specific date range ───
final dayAppointments = await supabase
    .from('appointments')
    .select()
    .gte('start_time', dayStart.toUtc().toIso8601String())
    .lt('start_time', dayEnd.toUtc().toIso8601String())
    .order('start_time');

// ─── Fetch pending appointments (Manager queue) ───
final pending = await supabase
    .from('appointments')
    .select()
    .eq('status', 'pending')
    .order('start_time');

// ─── Create appointment (Coordinator) ───
final newAppointment = await supabase
    .from('appointments')
    .insert({
      'title': title,
      'type': type.toDb(),
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'location': location,
      'notes': notes,
      'created_by': supabase.auth.currentUser!.id,
    })
    .select()
    .single();

// ─── Approve appointment (Manager) ───
await supabase
    .from('appointments')
    .update({
      'status': 'confirmed',
      'reviewed_by': supabase.auth.currentUser!.id,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    })
    .eq('id', appointmentId);

// ─── Reject appointment (Manager) ───
await supabase
    .from('appointments')
    .update({
      'status': 'rejected',
      'reviewed_by': supabase.auth.currentUser!.id,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    })
    .eq('id', appointmentId);

// ─── Suggest alternative (Manager) ───
// Step 1: Insert suggestion
await supabase.from('appointment_suggestions').insert({
  'appointment_id': appointmentId,
  'suggested_by': supabase.auth.currentUser!.id,
  'suggested_start': newStart.toUtc().toIso8601String(),
  'suggested_end': newEnd.toUtc().toIso8601String(),
  'message': message,
});
// Step 2: Update appointment status
await supabase
    .from('appointments')
    .update({'status': 'suggested'})
    .eq('id', appointmentId);

// ─── Accept suggestion (Coordinator) ───
// Step 1: Update appointment with suggested times + confirm
await supabase
    .from('appointments')
    .update({
      'start_time': suggestion.suggestedStart.toUtc().toIso8601String(),
      'end_time': suggestion.suggestedEnd.toUtc().toIso8601String(),
      'status': 'confirmed',
    })
    .eq('id', appointmentId);
// Step 2: Deactivate the suggestion
await supabase
    .from('appointment_suggestions')
    .update({'is_active': false})
    .eq('id', suggestion.id);

// ─── Reject suggestion (Coordinator) ───
await supabase
    .from('appointments')
    .update({'status': 'pending'})
    .eq('id', appointmentId);
await supabase
    .from('appointment_suggestions')
    .update({'is_active': false})
    .eq('id', suggestion.id);

// ─── Cancel appointment (Coordinator) ───
await supabase
    .from('appointments')
    .update({'status': 'cancelled'})
    .eq('id', appointmentId);

// ─── Delete pending appointment (Coordinator) ───
await supabase
    .from('appointments')
    .delete()
    .eq('id', appointmentId);

// ─── Fetch active suggestion for an appointment ───
final suggestion = await supabase
    .from('appointment_suggestions')
    .select()
    .eq('appointment_id', appointmentId)
    .eq('is_active', true)
    .maybeSingle();

// ─── Fetch notifications (current user, via RLS) ───
final notifications = await supabase
    .from('notifications')
    .select()
    .order('created_at', ascending: false);

// ─── Mark notification as read ───
await supabase
    .from('notifications')
    .update({'is_read': true})
    .eq('id', notificationId);

// ─── Get unread notification count ───
final count = await supabase
    .from('notifications')
    .select()
    .eq('is_read', false)
    .count(CountOption.exact);

// ─── Conflict check RPC ───
final conflicts = await supabase.rpc('check_appointment_overlap', params: {
  'p_start_time': startTime.toUtc().toIso8601String(),
  'p_end_time': endTime.toUtc().toIso8601String(),
  'p_exclude_id': existingAppointmentId,
});
```

### 4.10 Form Validation Rules

| Field          | Screen(s)                | Required | Constraints                                      |
| :------------- | :----------------------- | :------- | :----------------------------------------------- |
| `title`        | Create, Edit             | Yes      | Non-empty, max 200 characters                    |
| `type`         | Create                   | Yes      | Must be one of: `ministry`, `patient`, `external` |
| `start_time`   | Create, Edit, Suggest    | Yes      | Must be in the future. Must be before `end_time`  |
| `end_time`     | Create, Edit, Suggest    | Yes      | Must be after `start_time`. Minimum duration: 15 minutes |
| `location`     | Create, Edit             | No       | Free text, max 500 characters. Shown for `external` type |
| `notes`        | Create, Edit             | No       | Free text, max 1000 characters                   |
| `message`      | Suggest                  | No       | Free text, max 500 characters (Manager's note)   |
| `email`        | Login                    | Yes      | Non-empty, valid email format                    |
| `password`     | Login                    | Yes      | Non-empty, minimum 6 characters                  |

For appointment creation/editing, after field validation passes, always run the conflict check RPC (Section 9.2) before submitting.

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

### 6.1 GoRouter Route Structure

```
lib/
├── router/
│   └── app_router.dart          ← GoRouter configuration with auth redirect
├── screens/
│   ├── login_screen.dart        ← Login screen
│   ├── coordinator/
│   │   ├── dashboard_screen.dart      ← Dashboard (today's appointments, pending count)
│   │   ├── calendar_screen.dart       ← Full calendar view (month/week/day)
│   │   ├── create_appointment_screen.dart ← Create new appointment form
│   │   ├── appointment_detail_screen.dart ← Appointment detail (view, edit, accept/reject suggestion)
│   │   ├── notifications_screen.dart  ← Notification list
│   │   └── settings_screen.dart       ← Settings (account info, push token)
│   ├── manager/
│   │   ├── pending_queue_screen.dart  ← Pending queue (appointments awaiting action)
│   │   ├── calendar_screen.dart       ← Full calendar view (read-only overview)
│   │   ├── appointment_detail_screen.dart ← Appointment detail (approve, reject, suggest)
│   │   ├── suggest_screen.dart        ← Suggest alternative time form
│   │   ├── notifications_screen.dart  ← Notification list
│   │   └── settings_screen.dart       ← Settings (account info, push token)
│   └── not_found_screen.dart    ← 404 fallback
```

### 6.2 Screen Descriptions

#### Auth

| Screen   | Route          | Description                                   |
| :------- | :------------- | :-------------------------------------------- |
| Login    | `/login`       | Email + password form. Redirects by role on success. |

#### Coordinator Screens

| Screen              | Route                          | Description                                                        |
| :------------------ | :----------------------------- | :----------------------------------------------------------------- |
| Dashboard           | `/coordinator`                 | Today's agenda, count of pending/confirmed appointments.           |
| Calendar            | `/coordinator/calendar`        | Month/week/day view of all appointments, color-coded by type.      |
| Create Appointment  | `/coordinator/create`          | Form: title, type, date/time range, location/notes. Runs conflict check before submit. |
| Appointment Detail  | `/coordinator/appointment/:id` | Full details. Shows suggestion if `status = 'suggested'`. Accept/reject suggestion buttons. Edit/cancel for non-ministry. |
| Notifications       | `/coordinator/notifications`   | List of notifications with read/unread state.                      |
| Settings            | `/coordinator/settings`        | Display name, role, sign out button.                               |

#### Manager Screens

| Screen              | Route                          | Description                                                        |
| :------------------ | :----------------------------- | :----------------------------------------------------------------- |
| Pending Queue       | `/manager`                     | List of `pending` appointments sorted by `start_time`.             |
| Calendar            | `/manager/calendar`            | Month/week/day view of all appointments (read-only overview).      |
| Appointment Detail  | `/manager/appointment/:id`     | Full details. Approve/reject/suggest buttons for `pending`. View-only for other statuses. |
| Suggest Alternative | `/manager/suggest/:id`         | Date/time picker + optional message. Conflict check before submit. |
| Notifications       | `/manager/notifications`       | List of notifications with read/unread state.                      |
| Settings            | `/manager/settings`            | Display name, role, sign out button.                               |

### 6.3 Navigation Flow

```
App Launch
  │
  ▼
MaterialApp.router (GoRouter)
  │
  ├── No session? ──► /login
  │
  └── Has session?
        │
        ├── Fetch profile → role = 'coordinator'
        │     └──► Redirect to /coordinator
        │
        └── Fetch profile → role = 'manager'
              └──► Redirect to /manager
```

---

## 7. Real-time Strategy

### 7.1 Channels

| Channel                         | Table                    | Filter                          | Purpose                              |
| :------------------------------ | :----------------------- | :------------------------------ | :----------------------------------- |
| `realtime:appointments`         | `appointments`           | None (all rows)                 | Calendar stays in sync across both roles |
| `realtime:notifications:{uid}`  | `notifications`          | `recipient_id=eq.{uid}`         | Per-user notification delivery       |
| `realtime:suggestions`          | `appointment_suggestions`| None                            | Coordinator sees new suggestions live |

### 7.2 Subscription Pattern

```dart
// lib/services/realtime_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;

  RealtimeService(this._supabase);

  void subscribe(String userId) {
    _channel = _supabase
        .channel('app-realtime')
        // Appointments: all changes
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          callback: (payload) {
            // Update appointment state via Riverpod
          },
        )
        // Notifications: filtered to current user
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            // Update notification state via Riverpod
          },
        )
        // Suggestions: all changes
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointment_suggestions',
          callback: (payload) {
            // Update suggestion state via Riverpod
          },
        )
        .subscribe();
  }

  void dispose() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
  }
}
```

### 7.3 Optimistic Updates

- When the Coordinator creates an appointment, the state adds it to the local list immediately with a temporary ID.
- On server confirmation (via Realtime event), replace the temporary entry with the server's canonical row.
- If the insert fails, remove the temporary entry and show an error snackbar.

### 7.4 Reconnection

- Use Flutter's `AppLifecycleListener`. When the app moves from `paused`/`inactive` to `resumed`, re-fetch the latest appointments and notifications to catch any missed Realtime events.
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
- **Snackbar/Overlay**: When a Realtime `INSERT` on `notifications` is received while the app is in the foreground, show a snackbar or overlay notification.
- **Notification list screen**: Sorted by `created_at DESC`. Tapping a notification marks it as read and navigates to the related appointment detail.

### 8.3 Push Notifications

Push notifications are delivered via the **Web Push API** (using VAPID keys). A Supabase Edge Function sends the push to the browser's push endpoint.

```
supabase/functions/send-push/index.ts
```

**Flow:**

1. On login, the Flutter web app requests notification permission via the browser's `Notification.requestPermission()` API, then subscribes to push via the service worker and stores the push subscription endpoint in `profiles.push_token`.
2. The `trg_notify_appointment` trigger inserts a row into `notifications`.
3. A separate database trigger (or webhook) on `notifications` INSERT calls the `send-push` Edge Function.
4. The Edge Function reads the recipient's `push_token` (Web Push subscription JSON) from `profiles`.
5. If the token exists, it sends a Web Push notification using VAPID authentication.

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

  // push_token stores the Web Push subscription JSON
  // { endpoint, keys: { p256dh, auth } }
  const subscription = JSON.parse(profile.push_token);

  // Send Web Push notification using VAPID
  // Implementation uses web-push library or manual VAPID signing
  const pushResponse = await sendWebPush(subscription, {
    title: record.title,
    body: record.body,
    data: { appointmentId: record.appointment_id },
  });

  return new Response(JSON.stringify({ success: pushResponse.ok }), { status: 200 });
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

```dart
final conflicts = await supabase
    .rpc('check_appointment_overlap', params: {
      'p_start_time': startTime.toIso8601String(),
      'p_end_time': endTime.toIso8601String(),
      'p_exclude_id': existingAppointmentId, // null for new appointments
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

In the `MaterialApp` configuration:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MawaidApp extends StatelessWidget {
  const MawaidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      // Force RTL directionality for Arabic
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      theme: appTheme,
    );
  }
}
```

> **Note:** Use `Locale('ar')` not `Locale('ar', 'OM')`. Flutter's `MaterialLocalizations` supports `ar` but not the `ar_OM` sub-locale. Without the localization delegates, Material widgets (TextFormField, ElevatedButton, etc.) will fail to render on web. The `intl` package still uses `ar_OM` for date/number formatting via `initializeDateFormatting('ar_OM', null)`.

### 10.2 Flutter Directional Widgets

Use directional-aware properties instead of hardcoded left/right:

| Physical (avoid)            | Directional (use)                | Meaning in RTL    |
| :-------------------------- | :------------------------------- | :----------------- |
| `EdgeInsets.only(left: 16)` | `EdgeInsetsDirectional.only(start: 16)` | padding-right |
| `EdgeInsets.only(right: 16)`| `EdgeInsetsDirectional.only(end: 16)`   | padding-left  |
| `Alignment.centerLeft`      | `AlignmentDirectional.centerStart`      | center-right  |
| `Alignment.centerRight`     | `AlignmentDirectional.centerEnd`        | center-left   |
| `CrossAxisAlignment.start`  | *(already directional-aware)*           | right-aligned |

### 10.3 Font

Use **Readex Pro** loaded via `pubspec.yaml`:

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: ReadexPro
      fonts:
        - asset: assets/fonts/ReadexPro-Regular.ttf
          weight: 400
        - asset: assets/fonts/ReadexPro-Medium.ttf
          weight: 500
        - asset: assets/fonts/ReadexPro-Bold.ttf
          weight: 700
```

Set as default in the app theme:

```dart
// lib/theme/app_theme.dart
final appTheme = ThemeData(
  fontFamily: 'ReadexPro',
  // ... other theme configuration
);
```

### 10.4 Date & Number Formatting

Use the `intl` package with **Omani Arabic locale** and **Gregorian calendar** (not Hijri):

```dart
// lib/utils/format_date.dart
import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  return DateFormat('EEEE، d MMMM yyyy', 'ar_OM').format(date);
}

String formatTime(DateTime date) {
  return DateFormat('hh:mm a', 'ar_OM').format(date);
}
```

All dates throughout the app use the Gregorian calendar. No Hijri conversion is needed.

### 10.5 Timezone: `Asia/Muscat` (GMT+4)

The app is used in Oman, but the server/VPS may be in a different timezone. To avoid any timezone mismatch, `Asia/Muscat` is enforced at **every layer**:

#### Database Level

Set the database timezone in the Supabase PostgreSQL config so that `now()`, `CURRENT_TIMESTAMP`, and any implicit conversions use Muscat time:

```sql
-- Apply in a migration or via supabase/config.toml
ALTER DATABASE postgres SET timezone TO 'Asia/Muscat';
```

All `TIMESTAMPTZ` columns already store UTC internally, but this ensures that any SQL using `now()` or casting to `timestamp` (without tz) behaves correctly.

#### Edge Functions Level

Set the timezone environment variable for the Deno runtime:

```env
# supabase/functions/.env.local
TZ=Asia/Muscat
```

#### Docker Level

Set the timezone on all containers in `docker-compose.yml`:

```yaml
services:
  mawaid-web:
    environment:
      - TZ=Asia/Muscat
  # Apply to all Supabase containers as well
```

#### Flutter App Level

Use the `timezone` package to ensure all client-side date operations use `Asia/Muscat`, regardless of the user's device/browser timezone:

```dart
// lib/utils/format_date.dart
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

final _muscat = tz.getLocation('Asia/Muscat');

void initTimezone() {
  tz_data.initializeTimeZones();
}

/// Convert a UTC DateTime to Muscat local time
tz.TZDateTime toMuscat(DateTime utc) {
  return tz.TZDateTime.from(utc.toUtc(), _muscat);
}

String formatDate(DateTime date) {
  final local = toMuscat(date);
  return DateFormat('EEEE، d MMMM yyyy', 'ar_OM').format(local);
}

String formatTime(DateTime date) {
  final local = toMuscat(date);
  return DateFormat('hh:mm a', 'ar_OM').format(local);
}
```

Call `initTimezone()` in `main.dart` before `runApp()`.

**Key rule**: Never rely on the device/browser's local timezone. Always convert to `Asia/Muscat` explicitly before displaying or comparing dates.

### 10.6 Arabic Strings

No i18n library. All Arabic strings live in a single file:

```
lib/constants/strings.dart
```

```dart
class Strings {
  Strings._();

  // Auth
  static const login = 'تسجيل الدخول';
  static const email = 'البريد الإلكتروني';
  static const password = 'كلمة المرور';
  static const loginButton = 'دخول';
  static const loginError = 'البريد أو كلمة المرور غير صحيحة';

  // Appointment types
  static const ministry = 'إجتماع وزارة';
  static const patient = 'موعد مريض';
  static const external_ = 'موعد خارجي';

  // Statuses
  static const pending = 'بانتظار الموافقة';
  static const confirmed = 'مؤكد';
  static const rejected = 'مرفوض';
  static const suggested = 'مقترح وقت بديل';
  static const cancelled = 'ملغي';

  // Actions
  static const approve = 'موافقة';
  static const reject = 'رفض';
  static const suggestAlternative = 'اقتراح وقت بديل';
  static const acceptSuggestion = 'قبول الاقتراح';
  static const rejectSuggestion = 'رفض الاقتراح';
  static const cancel = 'إلغاء';
  static const save = 'حفظ';
  static const create = 'إنشاء';
  static const delete = 'حذف';
  static const signOut = 'تسجيل الخروج';

  // Notifications
  static const notifications = 'الإشعارات';
  static const noNotifications = 'لا توجد إشعارات';

  // Calendar
  static const calendar = 'التقويم';
  static const today = 'اليوم';
  static const noAppointments = 'لا توجد مواعيد';

  // Dashboard
  static const dashboard = 'الرئيسية';
  static const pendingCount = 'بانتظار الموافقة';
  static const confirmedCount = 'مؤكدة';
  static const todaySchedule = 'جدول اليوم';

  // Errors
  static const conflictMinistry = 'يوجد تعارض مع إجتماع وزارة — لا يمكن الحجز في هذا الوقت';
  static const conflictWarning = 'يوجد تعارض مع مواعيد أخرى';
  static const conflictProceed = 'متابعة رغم التعارض';
  static const networkError = 'خطأ في الاتصال';
  static const genericError = 'حدث خطأ، حاول مرة أخرى';

  // Settings
  static const settings = 'الإعدادات';
}
```

---

## 11. Design System & Icons

### 11.1 Design Philosophy

The app follows a **modern, clean design** built on Material Design 3 (Material You) principles:

- **Clean layouts** with generous whitespace and clear visual hierarchy.
- **Soft color palette** with distinct accent colors per appointment type (ministry, patient, external).
- **Rounded corners** on cards, buttons, and input fields.
- **Subtle shadows and elevation** for depth without visual clutter.
- **Smooth transitions** and micro-animations for state changes (approvals, rejections, suggestions).
- **Fully responsive layout** — every screen works on both desktop and mobile viewports for all users.

### 11.2 Icons

Use **Lucide Icons** (`lucide_icons_flutter` package) throughout the app for a consistent, modern icon style. This package includes RTL support via `.dir()` and variable stroke thickness:

```yaml
# pubspec.yaml (relevant dependencies)
dependencies:
  flutter_localizations:
    sdk: flutter
  lucide_icons_flutter: ^3.1.9
  timezone: ^0.10.1
  intl: ^0.20.2
  supabase_flutter: ^2.10.2
  flutter_riverpod: ^3.2.1
  go_router: ^17.1.0
  table_calendar: ^3.2.0
```

> **Important:** `flutter_localizations` is required for Material widgets to render correctly on web. Without it, `TextFormField`, `ElevatedButton`, and other Material widgets will fail silently in release builds.

| Usage                  | Icon                        |
| :--------------------- | :-------------------------- |
| Dashboard / Home       | `LucideIcons.layoutDashboard` |
| Calendar               | `LucideIcons.calendar`      |
| Create appointment     | `LucideIcons.plus`          |
| Notifications          | `LucideIcons.bell`          |
| Settings               | `LucideIcons.settings`      |
| Approve                | `LucideIcons.check`         |
| Reject                 | `LucideIcons.x`             |
| Suggest alternative    | `LucideIcons.clockArrowUp`  |
| Ministry meeting       | `LucideIcons.landmark`      |
| Patient appointment    | `LucideIcons.userRound`     |
| External meeting       | `LucideIcons.mapPin`        |
| Sign out               | `LucideIcons.logOut`        |
| Back / navigation      | `LucideIcons.arrowRight.dir()` (auto-flips for RTL) |
| Edit                   | `LucideIcons.pencil`        |
| Delete / Cancel        | `LucideIcons.trash2`        |
| Conflict warning       | `LucideIcons.triangleAlert`  |

### 11.3 Color Scheme

| Element                    | Hex         | Color purpose                              |
| :------------------------- | :---------- | :----------------------------------------- |
| **Primary**                | `#1B5E7B`   | Deep teal — brand color for primary actions, navigation, and app bars |
| **Primary variant**        | `#0D3B4F`   | Darker teal — pressed states, active nav items |
| **Ministry meeting**       | `#8B1A2B`   | Deep maroon — signals critical priority    |
| **Patient appointment**    | `#1A7F6D`   | Teal/green — calm, medium priority         |
| **External meeting**       | `#C27A1A`   | Warm amber — neutral, medium priority      |
| **Confirmed status**       | `#2E7D32`   | Green — approved/confirmed                 |
| **Rejected status**        | `#C62828`   | Red — rejected/error                       |
| **Pending status**         | `#F57F17`   | Amber — awaiting action                    |
| **Suggested status**       | `#5C6BC0`   | Indigo/purple — alternative proposed       |
| **Cancelled status**       | `#757575`   | Grey — inactive/cancelled                  |
| **Background**             | `#F5F5F0`   | Warm off-white — main background           |
| **Surface / Cards**        | `#FFFFFF`   | White — card surfaces with `elevation: 1`  |
| **On Surface (text)**      | `#1C1B1F`   | Near-black — primary text color            |
| **On Surface variant**     | `#49454F`   | Dark grey — secondary/subtitle text        |
| **Error**                  | `#B3261E`   | Material error red — form validation, hard blocks |

These values should be defined in `lib/theme/colors.dart` and referenced via the `ThemeData.colorScheme` in `app_theme.dart`.

### 11.4 Navigation Tabs

Both roles share the same responsive shell pattern but with different tab items:

**Coordinator tabs:**

| Tab       | Label      | Icon                            | Route                    |
| :-------- | :--------- | :------------------------------ | :----------------------- |
| Dashboard | الرئيسية   | `LucideIcons.layoutDashboard`   | `/coordinator`           |
| Calendar  | التقويم    | `LucideIcons.calendar`          | `/coordinator/calendar`  |
| Create    | إنشاء      | `LucideIcons.plus`              | `/coordinator/create`    |
| Notifications | الإشعارات | `LucideIcons.bell`           | `/coordinator/notifications` |
| Settings  | الإعدادات  | `LucideIcons.settings`          | `/coordinator/settings`  |

**Manager tabs:**

| Tab       | Label      | Icon                            | Route                    |
| :-------- | :--------- | :------------------------------ | :----------------------- |
| Pending   | بانتظار    | `LucideIcons.clock`             | `/manager`               |
| Calendar  | التقويم    | `LucideIcons.calendar`          | `/manager/calendar`      |
| Notifications | الإشعارات | `LucideIcons.bell`           | `/manager/notifications` |
| Settings  | الإعدادات  | `LucideIcons.settings`          | `/manager/settings`      |

On **desktop** (`≥1024px`): Tabs render as a right-side `NavigationRail` (since the app is RTL, the rail appears on the right edge). On **mobile** (`<768px`): Tabs render as a `NavigationBar` (bottom bar). On **tablet** (`768px–1023px`): Use `NavigationRail` in compact mode (icons only, no labels).

### 11.5 Responsive Layout Pattern

Use `LayoutBuilder` or `MediaQuery` to switch layouts based on viewport width:

```dart
// lib/widgets/ui/responsive_scaffold.dart
import 'package:flutter/material.dart';

class ResponsiveScaffold extends StatelessWidget {
  final List<NavigationItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;

  const ResponsiveScaffold({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1024) {
      // Desktop: NavigationRail + expanded content
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onTabSelected,
              labelType: NavigationRailLabelType.all,
              destinations: tabs.map((t) => NavigationRailDestination(
                icon: Icon(t.icon),
                label: Text(t.label),
              )).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    if (width >= 768) {
      // Tablet: compact NavigationRail (icons only)
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onTabSelected,
              labelType: NavigationRailLabelType.none,
              destinations: tabs.map((t) => NavigationRailDestination(
                icon: Icon(t.icon),
                label: Text(t.label),
              )).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Mobile: BottomNavigationBar
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTabSelected,
        destinations: tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  const NavigationItem({required this.icon, required this.label});
}
```

### 11.6 Empty & Loading States

Every list screen must handle three states:

| State     | Behavior                                                       |
| :-------- | :------------------------------------------------------------- |
| **Loading** | Show `CircularProgressIndicator` centered on screen.          |
| **Empty**   | Show an icon + Arabic message centered. E.g., `LucideIcons.calendarOff` + "لا توجد مواعيد". |
| **Error**   | Show `LucideIcons.wifiOff` + "خطأ في الاتصال" + retry button ("إعادة المحاولة"). |

For action feedback:
- **Success**: Show a green `SnackBar` with the action result (e.g., "تم تأكيد الموعد").
- **Error**: Show a red `SnackBar` with "حدث خطأ، حاول مرة أخرى".

### 11.7 Calendar Widget

Use the `table_calendar` package (`^3.2.0`). The calendar is wrapped in a custom `CalendarView` widget (`lib/widgets/calendar_view.dart`) used by both roles.

**Configuration:**

```dart
TableCalendar(
  locale: 'ar_OM',
  firstDay: DateTime.utc(2024, 1, 1),
  lastDay: DateTime.utc(2030, 12, 31),
  focusedDay: focusedDay,
  startingDayOfWeek: StartingDayOfWeek.saturday, // Omani week starts Saturday
  calendarFormat: calendarFormat, // month / twoWeeks / week
  availableCalendarFormats: const {
    CalendarFormat.month: 'شهر',
    CalendarFormat.twoWeeks: 'أسبوعين',
    CalendarFormat.week: 'أسبوع',
  },
  eventLoader: (day) => appointmentsForDay(day),
  // ... callbacks and styling
)
```

**Appointment indicators on the calendar:**

- Each day cell shows colored dots below the date number, one per appointment on that day.
- Dot color matches the appointment type color (maroon for ministry, teal for patient, amber for external).
- Tapping a day shows the day's appointments in a list below the calendar.
- Tapping an appointment in the list navigates to its detail screen.

**Calendar formats:**

- **Month view** (default): Full month grid. Good for desktop.
- **Week view**: Single week row. Useful on mobile.
- The user can toggle between formats via a button.

### 11.8 Web & PWA Considerations

Since the app runs as a **Flutter web** application:

- **PWA manifest** (`web/manifest.json`) is configured with app name, icons, theme color, and `"display": "standalone"` for installable experience.
- **Service worker** for offline caching of static assets.
- **Responsive breakpoints**: All screens adapt to the current viewport. Desktop layout (`≥1024px`) uses wider content areas, side navigation, and multi-column layouts where appropriate. Mobile layout (`<768px`) switches to bottom navigation, stacked single-column layouts, and full-width cards. Tablet (`768px–1023px`) uses an intermediate layout.
- **Touch-friendly targets**: Minimum 48px tap targets on all viewports to support both mouse and touch input.
- **No native-only APIs**: All features work within the browser (no camera, no filesystem, no native push — uses Web Push API instead).

---

## 12. Project Structure

```
mawaid/
├── lib/
│   ├── main.dart
│   ├── router/
│   │   └── app_router.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── colors.dart
│   ├── models/
│   │   ├── enums.dart                 ← UserRole, AppointmentType, AppointmentStatus, etc.
│   │   ├── profile.dart
│   │   ├── appointment.dart
│   │   ├── appointment_suggestion.dart
│   │   └── notification.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── appointment_provider.dart
│   │   └── notification_provider.dart
│   ├── services/
│   │   ├── supabase_service.dart
│   │   └── realtime_service.dart
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── not_found_screen.dart
│   │   ├── coordinator/
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── calendar_screen.dart
│   │   │   ├── create_appointment_screen.dart
│   │   │   ├── appointment_detail_screen.dart
│   │   │   ├── notifications_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── manager/
│   │       ├── pending_queue_screen.dart
│   │       ├── calendar_screen.dart
│   │       ├── appointment_detail_screen.dart
│   │       ├── suggest_screen.dart
│   │       ├── notifications_screen.dart
│   │       └── settings_screen.dart
│   ├── widgets/
│   │   ├── appointment_card.dart
│   │   ├── appointment_form.dart
│   │   ├── calendar_view.dart       ← Wraps table_calendar with app-specific config
│   │   ├── conflict_dialog.dart
│   │   ├── notification_item.dart
│   │   ├── suggestion_card.dart
│   │   ├── status_badge.dart
│   │   └── ui/
│   │       ├── responsive_scaffold.dart ← Desktop/tablet/mobile shell switcher
│   │       ├── app_button.dart
│   │       ├── app_input.dart
│   │       ├── app_date_time_picker.dart
│   │       └── app_card.dart
│   ├── constants/
│   │   └── strings.dart
│   └── utils/
│       ├── format_date.dart         ← Date/time formatting + Asia/Muscat TZ
│       └── push_token.dart          ← Web Push subscription helper
├── web/
│   ├── index.html              ← Flutter web entrypoint
│   ├── manifest.json           ← PWA manifest (name, icons, display: standalone)
│   ├── favicon.png
│   └── icons/                  ← PWA icons (192x192, 512x512)
├── assets/
│   └── fonts/
│       ├── ReadexPro-Regular.ttf
│       ├── ReadexPro-Medium.ttf
│       └── ReadexPro-Bold.ttf
├── docker/
│   ├── Dockerfile              ← Multi-stage: flutter build web → Nginx
│   └── nginx.conf              ← Nginx config serving Flutter web build
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
├── docker-compose.yml          ← Orchestrates Supabase + Flutter web (Nginx)
├── pubspec.yaml
├── analysis_options.yaml
└── docs/
    └── ARCHITECTURE.md
```

---

## 13. Auth Flow

### 13.1 Account Creation

This is an internal office application — there is no self-registration. User accounts are created in one of two ways:

1. **Supabase Studio**: Admin navigates to `localhost:54323` → Authentication → Create User. User metadata must include `role` and `full_name`:
   ```json
   { "role": "coordinator", "full_name": "منى" }
   ```
   ```json
   { "role": "manager", "full_name": "حاتم" }
   ```
2. **Seed script**: The `supabase/seed.sql` file is run automatically by `supabase start` after migrations. It inserts directly into `auth.users` (this works in self-hosted Supabase where the seed runs with superuser privileges):

```sql
-- supabase/seed.sql
-- Seed users for local development.
-- The handle_new_user() trigger auto-creates profiles from user_metadata.

INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'muna@mawaid.local',
  crypt('mawaid123', gen_salt('bf')),
  now(),
  '{"role": "coordinator", "full_name": "منى"}'::jsonb,
  now(),
  now(),
  '',
  ''
), (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'hatem@mawaid.local',
  crypt('mawaid123', gen_salt('bf')),
  now(),
  '{"role": "manager", "full_name": "حاتم"}'::jsonb,
  now(),
  now(),
  '',
  ''
);

-- Also insert into auth.identities (required for sign-in to work)
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT
  id,
  id,
  json_build_object('sub', id::text, 'email', email)::jsonb,
  'email',
  id::text,
  now(),
  now(),
  now()
FROM auth.users
WHERE email IN ('muna@mawaid.local', 'hatem@mawaid.local');
```

| User       | Email              | Password    | Role        |
| :--------- | :----------------- | :---------- | :---------- |
| منى        | muna@mawaid.local  | mawaid123   | coordinator |
| حاتم       | hatem@mawaid.local | mawaid123   | manager     |

The `handle_new_user()` trigger (Section 4.7) automatically creates the `profiles` row from the user metadata.

### 13.2 Login Flow

```
User enters email + password
  │
  ▼
supabase.auth.signInWithPassword(email: email, password: password)
  │
  ├── Error? → Show Arabic error message
  │
  └── Success → session stored automatically
        │
        ▼
  Fetch profile: supabase.from('profiles').select().eq('id', user.id).single()
        │
        ▼
  Store profile in auth provider (Riverpod)
        │
        ▼
  Request Web Push notification permission (if supported)
        │
        ▼
  GoRouter redirect based on role:
    coordinator → /coordinator
    manager     → /manager
```

### 13.3 Session Persistence

```dart
// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
```

### 13.4 Auth Provider (Riverpod v3)

```dart
// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

class AuthState {
  final Session? session;
  final Profile? profile;
  final bool isLoading;

  const AuthState({this.session, this.profile, this.isLoading = true});

  AuthState copyWith({Session? session, Profile? profile, bool? isLoading}) {
    return AuthState(
      session: session ?? this.session,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> initialize() async {
    final session = supabase.auth.currentSession;
    state = state.copyWith(session: session);
    if (session != null) {
      await fetchProfile();
    }
    state = state.copyWith(isLoading: false);

    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      if (!ref.mounted) return;
      state = state.copyWith(session: data.session);
      if (data.session == null) {
        state = state.copyWith(profile: null);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
    await fetchProfile();
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = const AuthState(isLoading: false);
  }

  Future<void> fetchProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    state = state.copyWith(profile: Profile.fromJson(data));
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
```

### 13.5 Protected Routes (GoRouter with Redirect)

```dart
// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggedIn = authState.session != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';

      if (isLoggedIn && authState.profile != null) {
        final role = authState.profile!.role;
        final targetPrefix = '/$role';

        if (isOnLogin) return targetPrefix;

        // Prevent cross-role access
        if (!state.matchedLocation.startsWith(targetPrefix)) {
          return targetPrefix;
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      // Coordinator routes
      ShellRoute(
        builder: (_, __, child) => CoordinatorShell(child: child),
        routes: [
          GoRoute(path: '/coordinator', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/coordinator/calendar', builder: (_, __) => const CalendarScreen()),
          GoRoute(path: '/coordinator/create', builder: (_, __) => const CreateAppointmentScreen()),
          GoRoute(path: '/coordinator/appointment/:id', builder: (_, state) =>
            AppointmentDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/coordinator/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/coordinator/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      // Manager routes
      ShellRoute(
        builder: (_, __, child) => ManagerShell(child: child),
        routes: [
          GoRoute(path: '/manager', builder: (_, __) => const PendingQueueScreen()),
          GoRoute(path: '/manager/calendar', builder: (_, __) => const CalendarScreen()),
          GoRoute(path: '/manager/appointment/:id', builder: (_, state) =>
            AppointmentDetailScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/manager/suggest/:id', builder: (_, state) =>
            SuggestScreen(id: state.pathParameters['id']!)),
          GoRoute(path: '/manager/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/manager/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
    errorBuilder: (_, __) => const NotFoundScreen(),
  );
});
```

---

## 14. Docker / Self-Hosted Setup

### 14.1 Overview

Both the **Flutter web app** and **Supabase backend** are self-hosted via Docker Compose. The Flutter app is built to static files and served by Nginx.

| Service          | Container              | Port  | Purpose                        |
| :--------------- | :--------------------- | :---- | :----------------------------- |
| **Mawaid Web**   | `mawaid-web`           | 80/443| Flutter web app (Nginx)        |
| PostgreSQL       | `supabase-db`          | 54322 | Primary database               |
| Auth (GoTrue)    | `supabase-auth`        | 9999  | Email/password authentication  |
| Realtime         | `supabase-realtime`    | 4000  | WebSocket subscriptions        |
| PostgREST        | `supabase-rest`        | 3000  | Auto-generated REST API        |
| Storage          | `supabase-storage`     | 5000  | File storage (not used yet)    |
| Edge Functions   | `supabase-edge-functions`| 54321| Deno-based serverless functions|
| Studio           | `supabase-studio`      | 54323 | Admin dashboard (web UI)       |
| Kong             | `supabase-kong`        | 8000  | API gateway                    |

### 14.2 Flutter Web Docker Build

```dockerfile
# docker/Dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web \
  --release \
  --dart-define=SUPABASE_URL=${SUPABASE_URL} \
  --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}

FROM nginx:alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
```

### 14.3 Nginx Configuration

```nginx
# docker/nginx.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression for Flutter web assets
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript application/wasm;
    gzip_min_length 1000;

    # Cache static assets (fonts, images, JS)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA fallback: all routes serve index.html (GoRouter handles client-side routing)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 14.4 Docker Compose

```yaml
# docker-compose.yml
# This file adds the mawaid-web service alongside the Supabase stack.
# For the full Supabase docker-compose, see:
# https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml
# Merge or extend the Supabase compose file with this service.

services:
  mawaid-web:
    build:
      context: .
      dockerfile: docker/Dockerfile
      args:
        SUPABASE_URL: ${SUPABASE_URL}
        SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
    ports:
      - "80:80"
    environment:
      - TZ=Asia/Muscat
    restart: unless-stopped
    depends_on:
      - supabase-kong  # Wait for API gateway to be ready
```

### 14.5 Setup Steps

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

### 14.6 Environment Variables

For local development, pass Supabase credentials via Dart defines:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://localhost:54321 \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key-from-supabase-start-output>
```

For the Edge Functions (`.env.local` in `supabase/functions/`):

```env
SUPABASE_URL=http://localhost:54321
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
```

### 14.7 Production Deployment

For production on a VPS/server:

1. Clone the [supabase/supabase](https://github.com/supabase/supabase) Docker directory.
2. Configure `.env` with production secrets (JWT secret, database password, API keys).
3. Run `docker compose up -d` — this starts both Supabase and the Mawaid web container.
4. The Flutter web build is handled inside the Docker build step (see Section 14.2). Pass `SUPABASE_URL` and `SUPABASE_ANON_KEY` as build args.
5. Apply migrations: `supabase db push --db-url postgres://postgres:<password>@<host>:54322/postgres`.
6. Deploy Edge Functions: `supabase functions deploy send-push --project-ref <ref>`.
7. Configure DNS to point the domain to the server. Nginx serves the Flutter web app and proxies API requests to Supabase Kong.

### 14.8 Supabase Studio Admin Tasks

Access Studio at `http://localhost:54323` (or the server URL in production) to:

- **Create user accounts**: Authentication → Users → Create User (include `role` and `full_name` in metadata).
- **Inspect data**: Table Editor → browse `appointments`, `profiles`, `notifications`, `appointment_suggestions`.
- **Run SQL**: SQL Editor → execute ad-hoc queries for debugging.
- **View logs**: Logs Explorer → monitor Edge Function invocations and auth events.

---

## 15. Verification & Testing

### 15.1 Manual Testing Checklist

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
- [ ] Dates display in Gregorian calendar with Arabic numerals and Arabic month names
- [ ] All times display in Asia/Muscat (GMT+4) regardless of browser/device timezone
- [ ] All UI text is in Arabic
- [ ] Readex Pro font renders correctly

#### Calendar
- [ ] Month view shows appointments as colored dots/indicators
- [ ] Day view shows appointment blocks
- [ ] Appointments color-coded by type
- [ ] Tapping appointment → navigates to detail

#### Web / PWA
- [ ] App loads correctly in Chrome, Safari, Firefox
- [ ] PWA install prompt appears (or "Add to Home Screen" works)
- [ ] Installed PWA opens in standalone mode (no browser chrome)
- [ ] Coordinator screens work on both desktop and mobile viewports
- [ ] Manager screens work on both desktop and mobile viewports
- [ ] Desktop layout uses side navigation / wider content areas
- [ ] Mobile layout switches to bottom navigation / stacked layout
- [ ] Lucide icons render correctly at all sizes

### 15.2 Key End-to-End Flows

1. **Ministry meeting creation**: Coordinator creates → auto-confirmed → appears on Manager's calendar → Manager receives notification → Manager cannot modify.

2. **Standard approval**: Coordinator creates patient appointment → Manager sees in pending queue → Manager approves → Coordinator notified → both calendars updated.

3. **Rejection**: Coordinator creates → Manager rejects → Coordinator notified → appointment shows as rejected.

4. **Suggest alternative (full cycle)**: Coordinator creates → Manager suggests alternative → Coordinator notified → Coordinator accepts → appointment time updated → both calendars updated.

5. **Suggestion rejection cycle**: Coordinator creates → Manager suggests → Coordinator rejects suggestion → appointment back to pending → Manager suggests again → Coordinator accepts.

6. **Conflict detection**: Coordinator creates ministry meeting 9:00–10:00 → Coordinator tries to create patient appointment 9:30–10:30 → warning shown (non-ministry overlap allowed) → Coordinator tries to create another ministry meeting 9:00–10:00 → hard block.

### 15.3 Database Verification Queries

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
  '2026-03-01 09:00:00+04',
  '2026-03-01 10:00:00+04'
);

-- Verify ministry auto-confirm trigger
INSERT INTO appointments (title, type, start_time, end_time, created_by)
VALUES ('Test Ministry', 'ministry', '2026-04-01 09:00:00+04', '2026-04-01 10:00:00+04', '<coordinator-uuid>');
-- Check: status should be 'confirmed'
SELECT status FROM appointments WHERE title = 'Test Ministry';

-- Verify notification was auto-created
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;
```

---

## 16. Project Timeline (Phases)

Each phase builds on the previous one. A phase is complete when all its deliverables exist and its acceptance criteria pass. Do not start a phase until the previous phase's acceptance criteria are met.

---

### Phase 1: Project Setup & Configuration

**Goal**: A running Flutter web app skeleton with theming, fonts, routing shell, and a local Supabase instance with an empty database.

**Tasks**:

1. Initialize Flutter project (`flutter create --platforms web mawaid`).
2. Add all dependencies to `pubspec.yaml` (see Section 11.2 for full list):
   - `flutter_riverpod`, `go_router`, `supabase_flutter`, `lucide_icons_flutter`, `timezone`, `intl`, `table_calendar`.
3. Set up `web/` directory:
   - Configure `web/index.html` with Arabic lang/dir attributes (`<html lang="ar" dir="rtl">`).
   - Create `web/manifest.json` with PWA metadata (`display: standalone`, app name, theme color, icons).
4. Add Readex Pro font files to `assets/fonts/` and register in `pubspec.yaml`.
5. Create `lib/theme/app_theme.dart` — Material Design 3 theme with Readex Pro, color scheme for appointment types/statuses (Section 11.3).
6. Create `lib/theme/colors.dart` — centralized color constants.
7. Create `lib/constants/strings.dart` — all Arabic strings (Section 10.6).
8. Create `lib/utils/format_date.dart` — date/time formatting with `Asia/Muscat` timezone enforcement (Section 10.5).
9. Create `lib/services/supabase_service.dart` — Supabase initialization (Section 13.3).
10. Create `lib/main.dart` — entry point with `initTimezone()`, `initSupabase()`, RTL `Directionality` wrapper, Riverpod `ProviderScope` (Section 10.1).
11. Create `lib/router/app_router.dart` — GoRouter skeleton with `/login` route and placeholder coordinator/manager shell routes.
12. Create `lib/widgets/ui/responsive_scaffold.dart` — the responsive shell that switches between `NavigationRail` (desktop/tablet) and `NavigationBar` (mobile) based on viewport width (Section 11.5).
13. Create `CoordinatorShell` and `ManagerShell` using `ResponsiveScaffold` with the tab items defined in Section 11.4.
14. Initialize Supabase locally: `supabase init` and `supabase start`.

**Deliverables**:
- `pubspec.yaml` with all dependencies
- `web/index.html`, `web/manifest.json`
- `lib/main.dart`, `lib/router/app_router.dart`
- `lib/theme/`, `lib/constants/`, `lib/utils/format_date.dart`
- `lib/services/supabase_service.dart`
- Responsive shell widgets
- Local Supabase running

**Acceptance Criteria**:
- [ ] `flutter run -d chrome` launches the app with RTL layout, Readex Pro font, and correct theme
- [ ] GoRouter navigates to placeholder screens
- [ ] Shell switches between side nav (desktop) and bottom nav (mobile) on resize
- [ ] `supabase status` shows all services running
- [ ] Date formatting outputs Gregorian dates in Arabic with Muscat timezone

---

### Phase 2: Database & Backend

**Goal**: Complete PostgreSQL schema with all tables, enums, RLS policies, triggers, functions, and seed data. The `send-push` Edge Function is deployed locally.

**Tasks**:

1. Create SQL migration files in `supabase/migrations/`:
   - `00001_create_enums.sql` — all enum types (Section 4.1)
   - `00002_create_profiles.sql` — profiles table + index (Section 4.2)
   - `00003_create_appointments.sql` — appointments table + indexes + btree_gist + exclusion constraint (Section 4.3)
   - `00004_create_suggestions.sql` — appointment_suggestions table + indexes (Section 4.4)
   - `00005_create_notifications.sql` — notifications table + indexes (Section 4.5)
   - `00006_create_rls_policies.sql` — all RLS policies (Section 4.6)
   - `00007_create_functions_triggers.sql` — `handle_new_user()`, `handle_ministry_meeting()`, `set_updated_at()`, `check_appointment_overlap()`, `notify_on_appointment_change()` + all triggers (Section 4.7)
   - `00008_seed_data.sql` — seed two users: منى (coordinator, muna@mawaid.local) and حاتم (manager, hatem@mawaid.local). See Section 13.1 for exact seed commands.
2. Set database timezone: `ALTER DATABASE postgres SET timezone TO 'Asia/Muscat'` (include in first migration, see Section 10.5).
3. Apply all migrations: `supabase db push`.
4. Create seed users via Supabase Studio or Admin API (see Section 13.1 for exact curl commands).
5. Create `supabase/functions/send-push/index.ts` — Web Push Edge Function (Section 8.3).
6. Create Dart model classes in `lib/models/` — follow the exact definitions in Section 4.8:
   - `enums.dart` — `UserRole`, `AppointmentType`, `AppointmentStatus`, `NotificationType` with `toDb()`/`fromDb()` helpers.
   - `profile.dart`, `appointment.dart`, `appointment_suggestion.dart`, `notification.dart`
   - Each with `fromJson()` factory and `toJson()` method matching the database schema.

**Deliverables**:
- All 8 migration files in `supabase/migrations/`
- `supabase/functions/send-push/index.ts`
- `lib/models/` with all model classes and enums

**Acceptance Criteria**:
- [ ] `supabase db push` succeeds with no errors
- [ ] Run verification queries from Section 15.3 — all pass (RLS enabled, triggers exist, exclusion constraint exists)
- [ ] Insert a ministry appointment via SQL → auto-confirmed, notification created
- [ ] `check_appointment_overlap()` returns correct conflicts
- [ ] Two seed users exist in `auth.users` and `profiles`
- [ ] `supabase functions serve send-push` starts without errors

---

### Phase 3: Auth & Core Navigation

**Goal**: Working login screen, session persistence, role-based routing, and protected route guards. Both users can sign in and are redirected to their respective (still placeholder) screens.

**Tasks**:

1. Create `lib/providers/auth_provider.dart` — `AuthNotifier` with `initialize()`, `signIn()`, `signOut()`, `fetchProfile()` (Section 13.4).
2. Complete `lib/router/app_router.dart` — full GoRouter config with `redirect` logic for auth guards and cross-role prevention (Section 13.5).
3. Create `lib/screens/login_screen.dart`:
   - Email + password form with Arabic labels.
   - Error handling with Arabic error messages.
   - Responsive: centered card on desktop, full-width on mobile.
4. Create `lib/screens/not_found_screen.dart` — 404 fallback.
5. Wire up auth state listener to GoRouter for reactive redirects.
6. Ensure session persistence across page reloads (Supabase handles this via browser storage on web).

**Deliverables**:
- `lib/providers/auth_provider.dart`
- `lib/router/app_router.dart` (complete)
- `lib/screens/login_screen.dart`
- `lib/screens/not_found_screen.dart`

**Acceptance Criteria**:
- [ ] Login with منى's credentials (muna@mawaid.local / mawaid123) → redirected to `/coordinator`
- [ ] Login with حاتم's credentials (hatem@mawaid.local / mawaid123) → redirected to `/manager`
- [ ] Wrong password → Arabic error message displayed
- [ ] Page refresh → session persists, auto-redirects to correct route
- [ ] Sign out → redirected to `/login`
- [ ] Manually navigate to `/manager` as coordinator → redirected to `/coordinator`
- [ ] Manually navigate to `/coordinator` as manager → redirected to `/manager`
- [ ] Login screen is responsive (desktop and mobile)

---

### Phase 4: Core Screens & CRUD

**Goal**: All coordinator and manager screens are implemented with full appointment CRUD, approval workflow, suggestion flow, and conflict detection. Calendar view shows all appointments.

**Tasks**:

1. Create `lib/providers/appointment_provider.dart` — Riverpod notifier for appointments CRUD. Use the exact Supabase queries from Section 4.9 for all operations (fetch, create, update, delete, approve, reject, suggest, accept/reject suggestion).
2. Create `lib/widgets/` shared components:
   - `appointment_card.dart` — card displaying appointment summary, color-coded by type (use hex values from Section 11.3), status badge.
   - `appointment_form.dart` — reusable form for create/edit (title, type, date/time pickers, location, notes). Apply validation rules from Section 4.10.
   - `calendar_view.dart` — wraps `TableCalendar` with app-specific configuration (see Section 11.7 for exact config).
   - `conflict_dialog.dart` — warning/hard-block dialog for overlaps.
   - `suggestion_card.dart` — displays suggested alternative time with accept/reject actions.
   - `status_badge.dart` — colored badge for appointment status (use hex values from Section 11.3).
   - `ui/app_button.dart`, `ui/app_input.dart`, `ui/app_date_time_picker.dart`, `ui/app_card.dart` — base UI components.
3. Create coordinator screens (`lib/screens/coordinator/`):
   - `dashboard_screen.dart` — today's agenda, pending/confirmed counts (Section 6.2).
   - `calendar_screen.dart` — full calendar view, color-coded by type, tap to navigate to detail.
   - `create_appointment_screen.dart` — appointment form with conflict check via `check_appointment_overlap()` RPC before submit (Section 9.2).
   - `appointment_detail_screen.dart` — full details, edit/cancel for non-ministry, accept/reject suggestion when status is `suggested`.
   - `notifications_screen.dart` — placeholder (completed in Phase 5).
   - `settings_screen.dart` — display name, role, sign out button.
4. Create manager screens (`lib/screens/manager/`):
   - `pending_queue_screen.dart` — list of `pending` appointments sorted by `start_time`.
   - `calendar_screen.dart` — read-only calendar overview.
   - `appointment_detail_screen.dart` — full details, approve/reject/suggest buttons for `pending`, view-only for other statuses.
   - `suggest_screen.dart` — date/time picker + optional message, conflict check before submit (Section 5.5).
   - `notifications_screen.dart` — placeholder (completed in Phase 5).
   - `settings_screen.dart` — display name, role, sign out button.
5. Implement conflict detection client-side (Section 9.2):
   - Call `check_appointment_overlap()` RPC before creating appointments, suggesting alternatives, and accepting suggestions.
   - Hard-block for ministry conflicts, warning dialog for others.
6. Ensure all screens are responsive:
   - Forms: single-column on mobile, optionally two-column on desktop.
   - Lists/queues: full-width cards on mobile, constrained-width with whitespace on desktop.
   - Calendar: adapts grid density to viewport.

**Deliverables**:
- `lib/providers/appointment_provider.dart`
- All `lib/widgets/` components
- All `lib/screens/coordinator/` screens
- All `lib/screens/manager/` screens

**Acceptance Criteria**:
- [ ] Coordinator can create all three appointment types
- [ ] Ministry meeting auto-confirms on creation
- [ ] Coordinator can edit/delete pending non-ministry appointments
- [ ] Coordinator cannot edit/delete ministry meetings (UI prevents it)
- [ ] Manager sees pending queue with only `pending` appointments
- [ ] Manager can approve → status becomes `confirmed`
- [ ] Manager can reject → status becomes `rejected`
- [ ] Manager can suggest alternative time → status becomes `suggested`, suggestion row created
- [ ] Coordinator can accept suggestion → time updated, status `confirmed`
- [ ] Coordinator can reject suggestion → status back to `pending`
- [ ] Conflict detection: ministry overlap → hard block; other overlap → warning with proceed option
- [ ] Calendar shows appointments color-coded by type
- [ ] All screens render correctly on both desktop and mobile viewports
- [ ] All text is Arabic, RTL layout correct throughout

---

### Phase 5: Real-time & Notifications

**Goal**: Real-time updates across both roles via Supabase Realtime. Full notification system with in-app notifications, badge counts, and Web Push.

**Tasks**:

1. Create `lib/services/realtime_service.dart` — subscribe to `appointments`, `notifications`, `appointment_suggestions` channels (Section 7.2).
2. Wire realtime events into Riverpod providers:
   - Appointment changes update the appointment provider state automatically.
   - New notifications update the notification provider state.
   - New suggestions trigger UI updates on the coordinator's appointment detail.
3. Implement optimistic updates (Section 7.3):
   - Add temporary entry on create, replace on server confirmation, rollback on failure.
4. Implement app lifecycle reconnection (Section 7.4):
   - On `visibilitychange` (web equivalent of app resume), re-fetch latest data to catch missed events.
5. Create `lib/providers/notification_provider.dart` — fetch notifications, mark as read, unread count.
6. Complete `notifications_screen.dart` for both roles:
   - List sorted by `created_at DESC`.
   - Read/unread visual distinction.
   - Tap notification → mark as read + navigate to appointment detail.
7. Add notification badge count to the notifications tab icon in both shell widgets.
8. Show snackbar/overlay when a new notification arrives while the app is in the foreground.
9. Implement Web Push registration:
   - Request `Notification.requestPermission()` on login.
   - Subscribe via service worker, store push subscription JSON in `profiles.push_token`.
10. Create `lib/utils/push_token.dart` — helper to register/update push subscription.

**Deliverables**:
- `lib/services/realtime_service.dart`
- `lib/providers/notification_provider.dart`
- `lib/utils/push_token.dart`
- Completed `notifications_screen.dart` for both roles
- Updated shell widgets with badge counts
- Service worker for Web Push

**Acceptance Criteria**:
- [ ] Coordinator creates appointment → appears on Manager's screen without refresh
- [ ] Manager approves → Coordinator's calendar updates without refresh
- [ ] New notification appears in recipient's notification tab in real-time
- [ ] Snackbar shown for foreground notifications
- [ ] Badge count on notifications tab reflects unread count
- [ ] Tapping notification marks it as read and navigates to appointment detail
- [ ] Badge count decreases after marking as read
- [ ] Tab/browser hidden and restored → data refreshed
- [ ] Web Push permission requested on login
- [ ] Push subscription stored in `profiles.push_token`

---

### Phase 6: Polish, PWA & Deployment

**Goal**: Production-ready app with PWA installability, Docker deployment config, final responsive polish, and all manual testing checklist items passing.

**Tasks**:

1. PWA finalization:
   - Verify `web/manifest.json` is complete (name, short_name, icons 192x192 + 512x512, theme_color, background_color, `display: standalone`).
   - Add service worker for offline caching of static assets.
   - Test PWA install on Chrome (desktop) and Safari/Chrome (mobile).
2. Docker setup:
   - Create `docker/Dockerfile` — multi-stage build: Flutter web → Nginx (Section 14.2 has exact Dockerfile).
   - Create `docker/nginx.conf` — serve Flutter web build, handle SPA fallback routing (Section 14.3 has exact config).
   - Create/update `docker-compose.yml` with `mawaid-web` service (Section 14.4 has exact config).
   - Set `TZ=Asia/Muscat` on all containers (Section 10.5).
3. Responsive polish:
   - Review every screen at `320px`, `768px`, `1024px`, and `1440px` widths.
   - Verify side nav ↔ bottom nav transition is smooth.
   - Ensure all dialogs, forms, and modals are usable on mobile.
   - Verify touch targets ≥ 48px on all interactive elements.
4. Visual polish:
   - Verify Lucide icons render at all sizes.
   - Verify appointment type colors are distinct and accessible.
   - Verify status badge colors match the color scheme (Section 11.3).
   - Smooth transitions/animations on status changes.
5. Edge cases (see Section 11.6 for patterns):
   - Empty states: no appointments, no notifications, no pending items — show Arabic empty state messages with icons.
   - Network error handling: show Arabic error snackbar on failed requests.
   - Loading states: show skeleton/spinner while data loads.
6. Run the full manual testing checklist (Section 15.1).
7. Run the key end-to-end flows (Section 15.2).
8. Run the database verification queries (Section 15.3).

**Deliverables**:
- `docker/Dockerfile`, `docker/nginx.conf`
- `docker-compose.yml` (updated with `mawaid-web` service)
- PWA-ready `web/` directory with service worker and icons
- All screens polished and responsive

**Acceptance Criteria**:
- [ ] `docker compose up` builds and serves the app successfully
- [ ] App accessible at configured host/port
- [ ] PWA installable on desktop Chrome and mobile browsers
- [ ] Installed PWA opens in standalone mode (no browser chrome)
- [ ] All items in Section 15.1 manual testing checklist pass
- [ ] All 6 end-to-end flows in Section 15.2 pass
- [ ] All database verification queries in Section 15.3 pass
- [ ] No console errors in browser DevTools during normal usage

---

### Phase Dependency Summary

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
Setup       Database     Auth         Screens      Realtime     Polish
& Config    & Backend    & Routing    & CRUD       & Notifs     & Deploy
```

Each phase **must** pass all its acceptance criteria before proceeding to the next. If a criterion fails, fix it within the current phase before moving on.
