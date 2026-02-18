-- Fix 12 Supabase advisor issues (security + performance)

-- ═══════════════════════════════════════════════════════════
-- PERFORMANCE: Add missing indexes on foreign key columns
-- ═══════════════════════════════════════════════════════════

CREATE INDEX idx_suggestions_suggested_by ON appointment_suggestions(suggested_by);
CREATE INDEX idx_appointments_reviewed_by ON appointments(reviewed_by);
CREATE INDEX idx_notifications_appointment ON notifications(appointment_id);

-- ═══════════════════════════════════════════════════════════
-- SECURITY: Set search_path on SECURITY DEFINER function
-- ═══════════════════════════════════════════════════════════

ALTER FUNCTION notify_on_appointment_change() SET search_path = public;

-- ═══════════════════════════════════════════════════════════
-- SECURITY: Revoke anon access from all public tables
-- Only authenticated users should access these tables.
-- ═══════════════════════════════════════════════════════════

REVOKE ALL ON profiles FROM anon;
REVOKE ALL ON appointments FROM anon;
REVOKE ALL ON appointment_suggestions FROM anon;
REVOKE ALL ON notifications FROM anon;

-- ═══════════════════════════════════════════════════════════
-- SECURITY: Revoke anon EXECUTE on custom functions
-- Trigger functions don't need direct execute grants.
-- check_appointment_overlap is called via RPC by authenticated users only.
-- ═══════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION handle_new_user() FROM anon, public;
REVOKE EXECUTE ON FUNCTION handle_ministry_meeting() FROM anon, public;
REVOKE EXECUTE ON FUNCTION set_updated_at() FROM anon, public;
REVOKE EXECUTE ON FUNCTION check_appointment_overlap(TIMESTAMPTZ, TIMESTAMPTZ, UUID) FROM anon, public;
REVOKE EXECUTE ON FUNCTION notify_on_appointment_change() FROM anon, public;

-- Grant execute on check_appointment_overlap to authenticated only (needed for RPC)
GRANT EXECUTE ON FUNCTION check_appointment_overlap(TIMESTAMPTZ, TIMESTAMPTZ, UUID) TO authenticated;
