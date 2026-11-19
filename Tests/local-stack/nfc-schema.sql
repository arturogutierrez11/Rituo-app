-- Empty local fixture tables, not a production migration.
CREATE TABLE nfc_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tag_hash text UNIQUE, status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
);
CREATE TABLE nfc_tag_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tag_id uuid REFERENCES nfc_tags(id),
  user_id uuid REFERENCES users(id), label text, status text DEFAULT 'active',
  claimed_at timestamptz DEFAULT now(), last_seen_at timestamptz,
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(), UNIQUE(tag_id,user_id)
);
