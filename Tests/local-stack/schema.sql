-- Fictional, minimal fixture for break configuration tests. NOT a production migration.
CREATE TABLE users (id uuid PRIMARY KEY, email text, display_name text,
  status text DEFAULT 'active', created_at timestamptz DEFAULT now());
INSERT INTO users VALUES ('00000000-0000-4000-8000-000000000001',
  'local-test@example.invalid', 'Prueba local', 'active', now());
CREATE TABLE refresh_sessions (id uuid PRIMARY KEY, user_id uuid REFERENCES users(id),
  revoked_at timestamptz, expires_at timestamptz);
INSERT INTO refresh_sessions VALUES ('00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000001', NULL, now() + interval '1 day');
CREATE TABLE rituals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id),
  title text, description text, icon text, duration_minutes integer,
  weekdays integer[], start_time text, end_time text,
  app_count integer DEFAULT 0, category_count integer DEFAULT 0, domain_count integer DEFAULT 0,
  selection_digest text, is_protected boolean DEFAULT false, nfc_unlock_enabled boolean DEFAULT false,
  password_hash text, status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
);
CREATE TABLE modes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id),
  template_key text, title text, icon text,
  app_count integer DEFAULT 0, category_count integer DEFAULT 0, domain_count integer DEFAULT 0,
  selection_digest text, is_protected boolean DEFAULT false, nfc_unlock_enabled boolean DEFAULT false,
  password_hash text, status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(), UNIQUE(user_id, template_key)
);
CREATE TABLE ritual_blocked_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ritual_id uuid REFERENCES rituals(id) ON DELETE CASCADE,
  platform text, type text, identifier text, display_name text, application_identifier text,
  bundle_identifier text, created_at timestamptz DEFAULT now()
);
CREATE TABLE mode_blocked_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), mode_id uuid REFERENCES modes(id) ON DELETE CASCADE,
  platform text, type text, identifier text, display_name text, application_identifier text,
  bundle_identifier text, created_at timestamptz DEFAULT now()
);
CREATE TABLE idempotency_operations (
  user_id uuid REFERENCES users(id), idempotency_key text, operation text, request_hash text,
  resource_type text, resource_id uuid, expires_at timestamptz,
  PRIMARY KEY(user_id, idempotency_key)
);
CREATE TABLE mode_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id),
  mode_id uuid REFERENCES modes(id) ON DELETE CASCADE,
  started_at timestamptz DEFAULT now(), ended_at timestamptz, status text,
  start_source text, end_source text, duration_seconds integer,
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
);
CREATE TABLE ritual_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id),
  ritual_id uuid REFERENCES rituals(id) ON DELETE CASCADE,
  started_at timestamptz DEFAULT now(), planned_end_at timestamptz, ended_at timestamptz, status text,
  start_source text, end_source text, duration_seconds integer,
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
);
