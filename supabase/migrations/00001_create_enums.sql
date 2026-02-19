-- Set timezone for the database
ALTER DATABASE postgres SET timezone TO 'Asia/Muscat';

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
