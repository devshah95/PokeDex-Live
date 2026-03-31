const express = require('express');
const pool    = require('../db');
const cache   = require('../cache/redis');
const router  = express.Router();

// ── GET /pokemon — paginated list with optional type filter ──────────────────
router.get('/', async (req, res) => {
  const page  = Math.max(1, parseInt(req.query.page  || '1'));
  const limit = Math.min(50, parseInt(req.query.limit || '20'));
  const type  = req.query.type || null;
  const offset = (page - 1) * limit;

  // Cache key includes all query params so different filters get different cache entries
  const cacheKey = `pokemon:list:${page}:${limit}:${type || 'all'}`;
  const cached   = await cache.get(cacheKey);
  if (cached) return res.json(cached);

  try {
    // Build query dynamically based on whether a type filter was provided
    let dataQuery  = 'SELECT * FROM pokemon';
    let countQuery = 'SELECT COUNT(*) FROM pokemon';
    let params     = [];

    if (type) {
      const typeFilter = ' WHERE primary_type = $1 OR secondary_type = $1';
      dataQuery  += typeFilter;
      countQuery += typeFilter;
      params.push(type);
    }

    dataQuery += ` ORDER BY pokedex_id LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const [dataResult, countResult] = await Promise.all([
      pool.query(dataQuery, params),
      pool.query(countQuery, type ? [type] : []),
    ]);

    const total = parseInt(countResult.rows[0].count);
    const payload = {
      data:       dataResult.rows,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };

    // Cache the list for 5 minutes — shorter than individual Pokémon (1 hour)
    // because the list changes if favorite_count updates
    await cache.set(cacheKey, payload, 300);
    res.json(payload);
  } catch (err) {
    console.error('GET /pokemon error:', err.message);
    res.status(500).json({ error: 'Failed to fetch pokemon' });
  }
});

// ── GET /pokemon/random ──────────────────────────────────────────────────────
router.get('/random', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM pokemon ORDER BY RANDOM() LIMIT 1'
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'No pokemon found' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch random pokemon' });
  }
});

// ── GET /pokemon/:id — by pokedex number or name ─────────────────────────────
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  const cacheKey = `pokemon:${id}`;

  // Check Redis first
  const cached = await cache.get(cacheKey);
  if (cached) return res.json(cached);

  try {
    // Support lookup by either number (25) or name (pikachu)
    const isNumber = /^\d+$/.test(id);
    const query    = isNumber
      ? 'SELECT * FROM pokemon WHERE pokedex_id = $1'
      : 'SELECT * FROM pokemon WHERE LOWER(name) = LOWER($1)';

    const result = await pool.query(query, [id]);
    if (!result.rows[0]) return res.status(404).json({ error: 'Pokemon not found' });

    // Cache for 1 hour — individual Pokémon data rarely changes
    await cache.set(cacheKey, result.rows[0], 3600);
    res.json(result.rows[0]);
  } catch (err) {
    console.error(`GET /pokemon/${id} error:`, err.message);
    res.status(500).json({ error: 'Failed to fetch pokemon' });
  }
});

module.exports = router;