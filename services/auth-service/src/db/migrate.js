const pool = require('./index');

async function migrate() {
  // Connect gets one connection from the pool
  const client = await pool.connect();
  try {
    console.log('Running auth service migrations...');

    await client.query(`
      -- Create the users table
      -- IF NOT EXISTS means this is safe to run multiple times
      CREATE TABLE IF NOT EXISTS users (
        id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
        username   VARCHAR(50)  UNIQUE NOT NULL,
        email      VARCHAR(255) UNIQUE NOT NULL,
        password   VARCHAR(255) NOT NULL,
        created_at TIMESTAMPTZ  DEFAULT NOW(),
        updated_at TIMESTAMPTZ  DEFAULT NOW()
      );

      -- Indexes make lookups by email and username fast
      CREATE INDEX IF NOT EXISTS idx_users_email    ON users(email);
      CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
    `);

    console.log('Auth service migrations complete ✓');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    // Always release the connection back to the pool
    client.release();
    await pool.end();
  }
}

migrate();