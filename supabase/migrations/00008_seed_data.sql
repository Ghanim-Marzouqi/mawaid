-- Seed test users for local development.
-- The handle_new_user() trigger auto-creates profiles from user_metadata.

-- Coordinator account (منى)
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
  email_change,
  email_change_token_new,
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
  '',
  '',
  ''
);

-- Manager account (حاتم)
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
  email_change,
  email_change_token_new,
  recovery_token
) VALUES (
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
  '',
  '',
  ''
);

-- Insert identity records (required for Supabase Auth sign-in to work)
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
