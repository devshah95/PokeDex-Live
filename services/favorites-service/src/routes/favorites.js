const express     = require('express');
const pool        = require('../db');
const { publish } = require('../kafka/producer');
const verifyToken = require('../middleware/auth');
const router      = express.Router();

// ── GET /favorites — get current user's favorites ────────────────────────────
// verifyToken is middleware — it runs first, then the route handler
router.get('/', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM favorites WHERE user_id = $1 ORDER BY created_at DESC',
      [req.user.userId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('GET /favorites error:', err.message);
    res.status(500).json({ error: 'Failed to fetch favorites' });
  }
});

// ── POST /favorites — add a Pokémon to favorites ─────────────────────────────
router.post('/', verifyToken, async (req, res) => {
  const { pokedexId } = req.body;

  if (!pokedexId || typeof pokedexId !== 'number') {
    return res.status(400).json({ error: 'pokedexId (number) is required' });
  }

  try {
    // Insert the favorite
    const result = await pool.query(
      `INSERT INTO favorites (user_id, pokedex_id)
       VALUES ($1, $2)
       RETURNING *`,
      [req.user.userId, pokedexId]
    );

    // Publish the Kafka event — async, non-blocking
    // The user gets their response immediately. Pokemon Service handles it in background.
    await publish('pokemon.favorited', {
      pokedexId,
      userId:    req.user.userId,
      username:  req.user.username,
      timestamp: new Date().toISOString(),
    });

    res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Already in favorites' });
    }
    console.error('POST /favorites error:', err.message);
    res.status(500).json({ error: 'Failed to add favorite' });
  }
});

// ── DELETE /favorites/:pokedexId — remove from favorites ─────────────────────
router.delete('/:pokedexId', verifyToken, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM favorites WHERE user_id = $1 AND pokedex_id = $2 RETURNING *',
      [req.user.userId, parseInt(req.params.pokedexId)]
    );
    if (!result.rows[0]) {
      return res.status(404).json({ error: 'Favorite not found' });
    }
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: 'Failed to remove favorite' });
  }
});

module.exports = router;