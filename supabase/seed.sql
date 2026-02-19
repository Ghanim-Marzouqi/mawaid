-- Seed users for local development.
-- Note: If running after migrations, users may already exist from 00008_seed_data.sql.
-- This file is idempotent — it skips if users already exist.

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
)
SELECT
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  v.email,
  crypt('mawaid123', gen_salt('bf')),
  now(),
  v.meta::jsonb,
  now(),
  now(),
  '',
  ''
FROM (VALUES
  ('muna@mawaid.local', '{"role": "coordinator", "full_name": "منى"}'),
  ('hatem@mawaid.local', '{"role": "manager", "full_name": "حاتم"}')
) AS v(email, meta)
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE auth.users.email = v.email
);

-- Insert identity records for any users that don't have them yet
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
  u.id,
  u.id,
  json_build_object('sub', u.id::text, 'email', u.email)::jsonb,
  'email',
  u.id::text,
  now(),
  now(),
  now()
FROM auth.users u
WHERE u.email IN ('muna@mawaid.local', 'hatem@mawaid.local')
  AND NOT EXISTS (
    SELECT 1 FROM auth.identities i WHERE i.user_id = u.id
  );
