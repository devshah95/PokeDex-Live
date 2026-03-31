const jwt = require('jsonwebtoken');

// This is a middleware function — it runs before your route handler.
// If verification succeeds, it calls next() to pass control to the route.
// If it fails, it returns a 401 and the route never runs.
function verifyToken(req, res, next) {
  // The Authorization header looks like: "Bearer eyJhbGciOiJIUzI1NiIsInR5..."
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const token = authHeader.split(' ')[1]; // Extract the token part

  try {
    // jwt.verify throws an error if the token is invalid, expired, or tampered with
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // Attach the decoded payload to the request so the route can use it
    req.user = decoded; // { userId: '...', username: '...' }
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = verifyToken;