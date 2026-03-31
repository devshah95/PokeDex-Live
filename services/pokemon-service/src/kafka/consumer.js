// This module listens for 'pokemon.favorited' events published by the Favorites Service.
// When an event arrives, it increments the favorite_count on that Pokémon.
// This is async — the Favorites Service publishes and forgets. It does not wait.
const { Kafka } = require('kafkajs');
const pool = require('../db');
const cache = require('../cache/redis');

const kafka = new Kafka({
  clientId: 'pokemon-service-consumer',
  brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
  // In production, MSK requires SSL
  ssl: process.env.NODE_ENV === 'production',
});

const consumer = kafka.consumer({ groupId: 'pokemon-service-group' });

async function startConsumer() {
  try {
    await consumer.connect();
    // Subscribe to the topic. fromBeginning: false means only process new events.
    await consumer.subscribe({ topic: 'pokemon.favorited', fromBeginning: false });

    await consumer.run({
      eachMessage: async ({ message }) => {
        // Parse the event payload
        const event = JSON.parse(message.value.toString());
        console.log('Received pokemon.favorited event:', event);

        // Increment the favorite_count in the database
        await pool.query(
          'UPDATE pokemon SET favorite_count = favorite_count + 1 WHERE pokedex_id = $1',
          [event.pokedexId]
        );

        // Invalidate the Redis cache for this Pokémon so the next read gets fresh data
        await cache.del(`pokemon:${event.pokedexId}`);

        console.log(`Updated favorite_count for pokemon #${event.pokedexId}`);
      }
    });

    console.log('Kafka consumer started — listening for pokemon.favorited ✓');
  } catch (err) {
    // If Kafka is unavailable at startup, log but don't crash the service
    console.error('Kafka consumer failed to start:', err.message);
  }
}

module.exports = { startConsumer };