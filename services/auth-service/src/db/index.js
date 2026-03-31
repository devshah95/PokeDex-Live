// This file creates and exports a "connection pool".
// A pool is a set of pre-opened database connections that your code reuses.
// Without pooling, every request would open and close a connection — very slow.

const { Pool } = require('pg');

// The Pool reads connection details from environment variables.
// Locally, these come from your .env file.
// In Kubernetes, they come from a Secret injected by the CI/CD pipeline.
const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  // In production (Kubernetes), the RDS instance uses SSL.
  // Locally with Docker, SSL is disabled.
  ssl: process.env.NODE_ENV === 'production'
    ? { rejectUnauthorized: false }
    : false,
  max: 10,                // Maximum connections in the pool
  idleTimeoutMillis: 30000, // Close idle connections after 30 seconds
});

// Log any unexpected database errors to the console
pool.on('error', (err) => {
  console.error('Unexpected database error:', err.message);
});

module.exports = pool;