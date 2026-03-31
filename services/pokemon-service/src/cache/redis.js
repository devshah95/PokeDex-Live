// This module wraps Redis operations and tracks cache hits/misses for Prometheus.
const { createClient } = require('redis');
const { Counter } = require('prom-client');

// These counters are automatically exposed on the /metrics endpoint.
// Grafana uses them to show the cache hit ratio dashboard panel.
const cacheHits = new Counter({
  name: 'pokemon_cache_hits_total',
  help: 'Number of Redis cache hits for pokemon data',
});

const cacheMisses = new Counter({
  name: 'pokemon_cache_misses_total',
  help: 'Number of Redis cache misses for pokemon data',
});

let client = null;

async function getClient() {
  if (client && client.isReady) return client;

  client = createClient({
    socket: {
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379'),
      // In production, ElastiCache requires TLS
      tls: process.env.NODE_ENV === 'production',
    }
  });

  client.on('error', (err) => console.error('Redis error:', err.message));
  client.on('ready', () => console.log('Redis connected ✓'));

  await client.connect();
  return client;
}

// Try to get a value from cache.
// Returns the parsed value if found (cache hit), or null (cache miss).
async function get(key) {
  try {
    const redis = await getClient();
    const value = await redis.get(key);
    if (value) {
      cacheHits.inc();
      return JSON.parse(value);
    }
    cacheMisses.inc();
    return null;
  } catch (err) {
    // If Redis is unavailable, log the error and return null.
    // The service degrades gracefully — it still works, just slower.
    console.error('Redis get error:', err.message);
    return null;
  }
}

// Store a value in cache with an expiry time (TTL = time to live, in seconds).
async function set(key, value, ttlSeconds = 3600) {
  try {
    const redis = await getClient();
    await redis.setEx(key, ttlSeconds, JSON.stringify(value));
  } catch (err) {
    console.error('Redis set error:', err.message);
    // Silently fail — caching is an optimization, not a requirement
  }
}

async function del(key) {
  try {
    const redis = await getClient();
    await redis.del(key);
  } catch (err) {
    console.error('Redis del error:', err.message);
  }
}

module.exports = { get, set, del };