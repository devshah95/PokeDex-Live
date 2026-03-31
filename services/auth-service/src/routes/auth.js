const express  = require('express');
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const pool     = require('../db');

const router = express.Router();

// ── POST /auth/register ──────────────────────────────────────────────────────
// Validates input, hashes password, inserts user, returns JWT
router.post(
  '/register',
  // These are validation rules — express-validator checks them before your handler runs
  [
    body('username')
      .isLength({ min: 3, max: 50 })
      .trim()
      .withMessage('Username must be 3-50 characters'),
    body('email')
      .isEmail()
      .normalizeEmail()
      .withMessage('Must be a valid email'),
    body('password')
      .isLength({ min: 6 })
      .withMessage('Password must be at least 6 characters'),
  ],
  async (req, res) => {
    // Check if validation failed
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { username, email, password } = req.body;

    try {
      // bcrypt.hash(password, 12) hashes the password with 12 salt rounds.
      // Higher rounds = more secure but slower. 12 is the industry standard.
      const hashedPassword = await bcrypt.hash(password, 12);

      // Insert the user into the database
      // $1, $2, $3 are parameterized — prevents SQL injection attacks
      const result = await pool.query(
        `INSERT INTO users (username, email, password)
         VALUES ($1, $2, $3)
         RETURNING id, username, email, created_at`,
        [username, email, hashedPassword]
      );

      const user = result.rows[0];

      // Sign a JWT with the user's ID and username
      // It expires in 24 hours — after that, the user must log in again
      const token = jwt.sign(
        { userId: user.id, username: user.username },
        process.env.JWT_SECRET,
        { expiresIn: '24h' }
      );

      res.status(201).json({ user, token });
    } catch (err) {
      // PostgreSQL error code 23505 = unique constraint violation
      // This means the email or username is already taken
      if (err.code === '23505') {
        return res.status(409).json({ error: 'Username or email already exists' });
      }
      console.error('Register error:', err.message);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ── POST /auth/login ─────────────────────────────────────────────────────────
router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;

    try {
      const result = await pool.query(
        'SELECT * FROM users WHERE email = $1',
        [email]
      );
      const user = result.rows[0];

      // If no user found OR password does not match — return the SAME error message.
      // Never tell the attacker which part was wrong.
      if (!user || !(await bcrypt.compare(password, user.password))) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = jwt.sign(
        { userId: user.id, username: user.username },
        process.env.JWT_SECRET,
        { expiresIn: '24h' }
      );

      res.json({
        user: { id: user.id, username: user.username, email: user.email },
        token
      });
    } catch (err) {
      console.error('Login error:', err.message);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ── GET /auth/users/:id ──────────────────────────────────────────────────────
router.get('/users/:id', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, username, email, created_at FROM users WHERE id = $1',
      [req.params.id]
    );
    if (!result.rows[0]) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Get user error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;