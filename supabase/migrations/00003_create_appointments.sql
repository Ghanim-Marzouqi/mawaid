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
