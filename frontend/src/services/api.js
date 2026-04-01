import axios from 'axios';

// These variables are set at BUILD TIME (when Docker builds the image).
// Locally, they come from frontend/.env.local
// In Kubernetes, the CI/CD pipeline passes them as Docker build arguments.
// IMPORTANT: There is no way to change them after the image is built —
// that is why dev and prod have separate Docker images.
const AUTH_URL     = import.meta.env.VITE_AUTH_URL     || 'http://localhost:3001';
const POKEMON_URL  = import.meta.env.VITE_POKEMON_URL  || 'http://localhost:3002';
const FAVORITES_URL = import.meta.env.VITE_FAVORITES_URL || 'http://localhost:3003';

// Helper to attach the JWT token to requests that need authentication
const authHeader = () => {
  const token = localStorage.getItem('token');
  return token ? { Authorization: `Bearer ${token}` } : {};
};

export const authApi = {
  register: (data) => axios.post(`${AUTH_URL}/auth/register`, data),
  login:    (data) => axios.post(`${AUTH_URL}/auth/login`,    data),
};

export const pokemonApi = {
  list:   (params = {}) => axios.get(`${POKEMON_URL}/pokemon`,       { params }),
  get:    (id)          => axios.get(`${POKEMON_URL}/pokemon/${id}`),
  random: ()            => axios.get(`${POKEMON_URL}/pokemon/random`),
};

export const favoritesApi = {
  list:   ()          => axios.get(`${FAVORITES_URL}/favorites`,        { headers: authHeader() }),
  add:    (pokedexId) => axios.post(`${FAVORITES_URL}/favorites`,       { pokedexId }, { headers: authHeader() }),
  remove: (pokedexId) => axios.delete(`${FAVORITES_URL}/favorites/${pokedexId}`, { headers: authHeader() }),
};