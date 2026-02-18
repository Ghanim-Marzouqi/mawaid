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
