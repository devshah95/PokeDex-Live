// dotenv must be required first — it loads .env before anything else reads process.env
require('dotenv').config();

const express = require('express');
const morgan  = require('morgan');
const cors    = require('cors');
const { collectDefaultMetrics, register } = require('prom-client');

// collectDefaultMetrics automatically tracks: CPU usage, memory, event loop lag, etc.
// prefix namespaces the metrics so you know they came from the auth service
collectDefaultMetrics({ prefix: 'auth_service_' });

const app  = express();
const PORT = process.env.PORT || 3001;

// ── Middleware ────────────────────────────────────────────────────────────────
// Middleware runs on every request before your routes handle it

app.use(cors());                  // Allow cross-origin requests from the frontend
app.use(express.json());          // Parse JSON request bodies
app.use(morgan('combined'));       // Log every request: method, path, status, time

// ── Health Check ─────────────────────────────────────────────────────────────
// Kubernetes liveness and readiness probes call this endpoint.
// If it returns 200, Kubernetes knows the pod is healthy.
// If it returns an error or times out, Kubernetes restarts the pod.
app.get('/health', (req, res) => {
  res.json({
    status:    'healthy',
    service:   'auth-service',
    env:       process.env.NODE_ENV,
    timestamp: new Date().toISOString()
  });
});

// ── Metrics ───────────────────────────────────────────────────────────────────
// Prometheus scrapes this endpoint every 15 seconds.
// It returns metrics in a text format Prometheus understands.
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/auth', require('./routes/auth'));

// ── 404 Handler ───────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found` });
});

// ── Start Server ──────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Auth service running on port ${PORT} [${process.env.NODE_ENV}]`);
});

// Export for testing — supertest needs the app object, not a running server
module.exports = app;