const pool = require('./index');

async function migrate() {
  const client = await pool.connect();
  try {
    console.log('Running pokemon service migrations...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS pokemon (
        id              SERIAL      PRIMARY KEY,
        pokedex_id      INTEGER     UNIQUE NOT NULL,
        name            VARCHAR(100) NOT NULL,
        primary_type    VARCHAR(50)  NOT NULL,
        secondary_type  VARCHAR(50),
        hp              INTEGER     NOT NULL,
        attack          INTEGER     NOT NULL,
        defense         INTEGER     NOT NULL,
        speed           INTEGER     NOT NULL,
        special_attack  INTEGER     NOT NULL,
        special_defense INTEGER     NOT NULL,
        height          INTEGER,
        weight          INTEGER,
        base_experience INTEGER,
        sprite_url      TEXT,
        favorite_count  INTEGER     DEFAULT 0,
        created_at      TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_pokemon_pokedex_id   ON pokemon(pokedex_id);
      CREATE INDEX IF NOT EXISTS idx_pokemon_name         ON pokemon(name);
      CREATE INDEX IF NOT EXISTS idx_pokemon_primary_type ON pokemon(primary_type);
    `);
    console.log('Pokemon service migrations complete ✓');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();