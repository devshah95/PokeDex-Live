const request = require('supertest');
const app     = require('../index');

jest.mock('../db',             () => ({ query: jest.fn() }));
jest.mock('../kafka/producer', () => ({ publish: jest.fn().mockResolvedValue(undefined) }));
jest.mock('jsonwebtoken', () => ({
  verify: jest.fn().mockReturnValue({ userId: 'user-123', username: 'ash' }),
}));

const pool    = require('../db');
const { publish } = require('../kafka/producer');

// Helper to create a request with a fake auth token
const withAuth = (req) => req.set('Authorization', 'Bearer fake.test.token');

describe('Favorites Service', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('GET /health', () => {
    it('returns healthy status', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.service).toBe('favorites-service');
    });
  });

  describe('GET /favorites', () => {
    it('requires authentication', async () => {
      const res = await request(app).get('/favorites');
      expect(res.status).toBe(401);
    });

    it('returns user favorites when authenticated', async () => {
      pool.query.mockResolvedValue({
        rows: [{ id: 'fav-1', user_id: 'user-123', pokedex_id: 25 }]
      });

      const res = await withAuth(request(app).get('/favorites'));
      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(1);
    });
  });

  describe('POST /favorites', () => {
    it('adds a favorite and publishes Kafka event', async () => {
      pool.query.mockResolvedValue({
        rows: [{ id: 'fav-1', user_id: 'user-123', pokedex_id: 25 }]
      });

      const res = await withAuth(request(app).post('/favorites'))
        .send({ pokedexId: 25 });

      expect(res.status).toBe(201);
      // Verify Kafka event was published
      expect(publish).toHaveBeenCalledWith('pokemon.favorited', expect.objectContaining({
        pokedexId: 25,
        userId: 'user-123',
      }));
    });

    it('returns 400 if pokedexId is missing', async () => {
      const res = await withAuth(request(app).post('/favorites')).send({});
      expect(res.status).toBe(400);
    });

    it('returns 409 if already favorited', async () => {
      pool.query.mockRejectedValue({ code: '23505' });
      const res = await withAuth(request(app).post('/favorites')).send({ pokedexId: 25 });
      expect(res.status).toBe(409);
    });
  });

  describe('DELETE /favorites/:pokedexId', () => {
    it('removes a favorite', async () => {
      pool.query.mockResolvedValue({ rows: [{ id: 'fav-1' }] });
      const res = await withAuth(request(app).delete('/favorites/25'));
      expect(res.status).toBe(204);
    });

    it('returns 404 if favorite not found', async () => {
      pool.query.mockResolvedValue({ rows: [] });
      const res = await withAuth(request(app).delete('/favorites/99'));
      expect(res.status).toBe(404);
    });
  });
});