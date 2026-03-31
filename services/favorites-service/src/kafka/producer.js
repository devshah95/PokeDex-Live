const { Kafka } = require('kafkajs');

const kafka = new Kafka({
  clientId: 'favorites-service',
  brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
  ssl: process.env.NODE_ENV === 'production',
  // Retry configuration — if the broker is temporarily unavailable, retry up to 5 times
  retry: { initialRetryTime: 300, retries: 5 },
});

const producer = kafka.producer();
let isConnected = false;

async function connect() {
  if (!isConnected) {
    await producer.connect();
    isConnected = true;
    console.log('Kafka producer connected ✓');
  }
}

// Publish an event to a Kafka topic.
// topic: the channel name (e.g. 'pokemon.favorited')
// message: the event payload (gets serialized to JSON)
async function publish(topic, message) {
  try {
    await connect();
    await producer.send({
      topic,
      messages: [{
        // key is used for partitioning — events with the same key go to the same partition
        key:   String(message.pokedexId || 'unknown'),
        value: JSON.stringify(message),
      }]
    });
    console.log(`Published to ${topic}:`, JSON.stringify(message));
  } catch (err) {
    // Log the error but don't throw — we don't want a Kafka failure to break favoriting
    console.error(`Failed to publish to ${topic}:`, err.message);
  }
}

module.exports = { publish };