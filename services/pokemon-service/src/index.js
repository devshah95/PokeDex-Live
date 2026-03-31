require('dotenv').config();
const express = require('express');
const morgan  = require('morgan');
const cors    = require('cors');
const { collectDefaultMetrics, register } = require('prom-client');
const { startConsumer } = require('./kafka/consumer');

collectDefaultMetrics({ prefix: 'pokemon_service_' });

const app  = express();
const PORT = process.env.PORT || 3002;

app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'pokemon-service', timestamp: new Date().toISOString() });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.use('/pokemon', require('./routes/pokemon'));

app.listen(PORT, async () => {
  console.log(`Pokemon service running on port ${PORT} [${process.env.NODE_ENV}]`);
  // Start the Kafka consumer after the HTTP server is up.
  // If Kafka is not available, the service still starts — it just won't process events.
  await startConsumer();
});

module.exports = app;