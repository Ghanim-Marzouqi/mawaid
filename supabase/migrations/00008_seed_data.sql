-- Seed test users via supabase_auth_admin role
-- These users will have their profiles auto-created by the handle_new_user() trigger

-- Coordinator account
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
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'authenticated',
  'authenticated',
  'coordinator@mawaid.local',
  crypt('coordinator123', gen_salt('bf')),
  now(),
  '{"role": "coordinator", "full_name": "أحمد المنسق"}'::jsonb,
  now(),
  now(),
  '',
  '',
  '',
  ''
);

-- Manager account
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
  'b2c3d4e5-f6a7-8901-bcde-f12345678901',
  'authenticated',
  'authenticated',
  'manager@mawaid.local',
  crypt('manager123', gen_salt('bf')),
  now(),
  '{"role": "manager", "full_name": "محمد المدير"}'::jsonb,
  now(),
  now(),
  '',
  '',
  '',
  ''
);

-- Insert identity records for the users (required for Supabase Auth to work)
INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  'coordinator@mawaid.local',
  '{"sub": "a1b2c3d4-e5f6-7890-abcd-ef1234567890", "email": "coordinator@mawaid.local"}'::jsonb,
  'email',
  now(),
  now(),
  now()
);

INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  'b2c3d4e5-f6a7-8901-bcde-f12345678901',
  'b2c3d4e5-f6a7-8901-bcde-f12345678901',
  'manager@mawaid.local',
  '{"sub": "b2c3d4e5-f6a7-8901-bcde-f12345678901", "email": "manager@mawaid.local"}'::jsonb,
  'email',
  now(),
  now(),
  now()
);
