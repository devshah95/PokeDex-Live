const request = require('supertest');
const app     = require('../index');

// Mock all external dependencies
jest.mock('../db',           () => ({ query: jest.fn() }));
jest.mock('../cache/redis',  () => ({ get: jest.fn(), set: jest.fn(), del: jest.fn() }));
jest.mock('../kafka/consumer', () => ({ startConsumer: jest.fn().mockResolvedValue(undefined) }));

const pool  = require('../db');
const cache = require('../cache/redis');

describe('Pokemon Service', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('GET /health', () => {
    it('returns healthy status', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.service).toBe('pokemon-service');
    });
  });

  describe('GET /pokemon', () => {
    it('returns cached data on cache hit', async () => {
      // Simulate a cache hit — cache.get returns data
      cache.get.mockResolvedValue({
        data: [{ pokedex_id: 1, name: 'bulbasaur' }],
        total: 1, page: 1, totalPages: 1
      });

      const res = await request(app).get('/pokemon');
      expect(res.status).toBe(200);
      expect(res.body.data[0].name).toBe('bulbasaur');
      // Verify the database was NOT called — that is the point of caching
      expect(pool.query).not.toHaveBeenCalled();
    });

    it('queries database on cache miss and caches result', async () => {
      cache.get.mockResolvedValue(null); // cache miss
      pool.query
        .mockResolvedValueOnce({ rows: [{ pokedex_id: 1, name: 'bulbasaur' }] }) // data query
        .mockResolvedValueOnce({ rows: [{ count: '1' }] }); // count query

      const res = await request(app).get('/pokemon');
      expect(res.status).toBe(200);
      expect(pool.query).toHaveBeenCalled();
      // Verify the result was stored in cache
      expect(cache.set).toHaveBeenCalled();
    });
  });

  describe('GET /pokemon/:id', () => {
    it('returns pokemon by pokedex number from cache', async () => {
      cache.get.mockResolvedValue({ pokedex_id: 25, name: 'pikachu' });

      const res = await request(app).get('/pokemon/25');
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('pikachu');
    });

    it('returns 404 for non-existent pokemon', async () => {
      cache.get.mockResolvedValue(null);
      pool.query.mockResolvedValue({ rows: [] });

      const res = await request(app).get('/pokemon/999');
      expect(res.status).toBe(404);
    });
  });

  describe('GET /metrics', () => {
    it('returns prometheus metrics', async () => {
      const res = await request(app).get('/metrics');
      expect(res.status).toBe(200);
      expect(res.text).toContain('pokemon_service_');
    });
  });
});