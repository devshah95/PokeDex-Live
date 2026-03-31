// supertest lets you make HTTP requests against your app without a running server
const request = require('supertest');
const app     = require('../index');

// We mock the database pool so tests don't need a real PostgreSQL database.
// jest.mock replaces the real module with a fake version for the duration of tests.
jest.mock('../db', () => ({
  query: jest.fn(),
}));

// We also mock bcryptjs and jsonwebtoken so tests run instantly
jest.mock('bcryptjs', () => ({
  hash:    jest.fn().mockResolvedValue('hashed_password'),
  compare: jest.fn().mockResolvedValue(true),
}));

jest.mock('jsonwebtoken', () => ({
  sign: jest.fn().mockReturnValue('mock.jwt.token'),
}));

const pool = require('../db');

// describe groups related tests together
describe('Auth Service', () => {

  // beforeEach runs before every test — clears any previous mock state
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // ── Health Check ──────────────────────────────────────────────────────────
  describe('GET /health', () => {
    it('should return healthy status', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
      expect(res.body.service).toBe('auth-service');
    });
  });

  // ── Register ──────────────────────────────────────────────────────────────
  describe('POST /auth/register', () => {
    it('should register a new user and return a token', async () => {
      // Arrange: set up what the mock database will return
      pool.query.mockResolvedValue({
        rows: [{ id: 'mock-uuid', username: 'ash', email: 'ash@pallet.com', created_at: new Date() }]
      });

      // Act: make the request
      const res = await request(app)
        .post('/auth/register')
        .send({ username: 'ash', email: 'ash@pallet.com', password: 'pikachu123' });

      // Assert: check the response
      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('token');
      expect(res.body.user.username).toBe('ash');
    });

    it('should return 400 if email is invalid', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ username: 'ash', email: 'not-an-email', password: 'pikachu123' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('errors');
    });

    it('should return 400 if password is too short', async () => {
      const res = await request(app)
        .post('/auth/register')
        .send({ username: 'ash', email: 'ash@pallet.com', password: 'abc' });

      expect(res.status).toBe(400);
    });

    it('should return 409 if email already exists', async () => {
      // Simulate a unique constraint violation from PostgreSQL
      pool.query.mockRejectedValue({ code: '23505' });

      const res = await request(app)
        .post('/auth/register')
        .send({ username: 'ash', email: 'ash@pallet.com', password: 'pikachu123' });

      expect(res.status).toBe(409);
    });
  });

  // ── Login ─────────────────────────────────────────────────────────────────
  describe('POST /auth/login', () => {
    it('should login successfully and return a token', async () => {
      pool.query.mockResolvedValue({
        rows: [{ id: 'mock-uuid', username: 'ash', email: 'ash@pallet.com', password: 'hashed' }]
      });

      const res = await request(app)
        .post('/auth/login')
        .send({ email: 'ash@pallet.com', password: 'pikachu123' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
    });

    it('should return 401 if user not found', async () => {
      pool.query.mockResolvedValue({ rows: [] });

      const res = await request(app)
        .post('/auth/login')
        .send({ email: 'nobody@nowhere.com', password: 'password' });

      expect(res.status).toBe(401);
    });
  });

  // ── Metrics ───────────────────────────────────────────────────────────────
  describe('GET /metrics', () => {
    it('should return prometheus metrics', async () => {
      const res = await request(app).get('/metrics');
      expect(res.status).toBe(200);
      expect(res.text).toContain('auth_service_');
    });
  });
});