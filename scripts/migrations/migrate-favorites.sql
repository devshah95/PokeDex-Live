CREATE TABLE IF NOT EXISTS favorites (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID    NOT NULL,
  pokedex_id  INTEGER NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, pokedex_id)
);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id    ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_pokedex_id ON favorites(pokedex_id);
