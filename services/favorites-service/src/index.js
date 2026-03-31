require('dotenv').config();
const express = require('express');
const morgan  = require('morgan');
const cors    = require('cors');
const { collectDefaultMetrics, register } = require('prom-client');

collectDefaultMetrics({ prefix: 'favorites_service_' });

const app  = express();
const PORT = process.env.PORT || 3003;

app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'favorites-service', timestamp: new Date().toISOString() });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.use('/favorites', require('./routes/favorites'));

app.listen(PORT, () => {
  console.log(`Favorites service running on port ${PORT} [${process.env.NODE_ENV}]`);
});

module.exports = app;