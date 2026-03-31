// This script fetches all 151 original Pokémon from PokéAPI and inserts them
// into the database. It runs once during initial setup and again via Lambda nightly.
require('dotenv').config();
const axios = require('axios');
const pool  = require('./index');

async function seed() {
  console.log('Seeding 151 Pokémon from PokéAPI...');
  const client = await pool.connect();

  try {
    for (let i = 1; i <= 151; i++) {
      // Fetch Pokémon data from the public PokéAPI
      const { data } = await axios.get(`https://pokeapi.co/api/v2/pokemon/${i}`);

      // Extract the stats we need from the API response
      const getStat = (name) =>
        data.stats.find(s => s.stat.name === name)?.base_stat || 0;

      await client.query(`
        INSERT INTO pokemon
          (pokedex_id, name, primary_type, secondary_type,
           hp, attack, defense, speed, special_attack, special_defense,
           height, weight, base_experience, sprite_url)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
        ON CONFLICT (pokedex_id) DO UPDATE SET
          favorite_count = pokemon.favorite_count
      `, [
        i,
        data.name,
        data.types[0].type.name,
        data.types[1]?.type.name || null,
        getStat('hp'),
        getStat('attack'),
        getStat('defense'),
        getStat('speed'),
        getStat('special-attack'),
        getStat('special-defense'),
        data.height,
        data.weight,
        data.base_experience || 0,
        data.sprites.front_default || null,
      ]);

      console.log(`  Seeded #${i} ${data.name}`);

      // Small delay to be polite to the free PokéAPI
      await new Promise(r => setTimeout(r, 100));
    }
    console.log('Seeding complete ✓');
  } finally {
    client.release();
    await pool.end();
  }
}

seed().catch(err => { console.error(err); process.exit(1); });