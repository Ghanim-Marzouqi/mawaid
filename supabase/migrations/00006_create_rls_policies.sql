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
