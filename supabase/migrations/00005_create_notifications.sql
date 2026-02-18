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
