import { useState, useEffect } from 'react';
import { pokemonApi, favoritesApi } from '../services/api';

// Type colors for the badges
const TYPE_COLORS = {
  fire: '#F08030', water: '#6890F0', grass: '#78C850', electric: '#F8D030',
  psychic: '#F85888', normal: '#A8A878', fighting: '#C03028', poison: '#A040A0',
  ground: '#E0C068', rock: '#B8A038', ghost: '#705898', dragon: '#7038F8',
  dark: '#705848', steel: '#B8B8D0', fairy: '#EE99AC', ice: '#98D8D8',
  bug: '#A8B820', flying: '#A890F0',
};

const TYPES = Object.keys(TYPE_COLORS);

export default function Pokedex() {
  const [pokemon, setPokemon]     = useState([]);
  const [total, setTotal]         = useState(0);
  const [page, setPage]           = useState(1);
  const [typeFilter, setTypeFilter] = useState('');
  const [loading, setLoading]     = useState(true);
  const [favorites, setFavorites] = useState(new Set());

  // Fetch Pokémon whenever page or type filter changes
  useEffect(() => {
    setLoading(true);
    pokemonApi.list({ page, limit: 20, ...(typeFilter && { type: typeFilter }) })
      .then(res => {
        setPokemon(res.data.data);
        setTotal(res.data.total);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [page, typeFilter]);

  // Fetch favorites if logged in
  useEffect(() => {
    if (localStorage.getItem('token')) {
      favoritesApi.list()
        .then(res => setFavorites(new Set(res.data.map(f => f.pokedex_id))))
        .catch(() => {});
    }
  }, []);

  const toggleFavorite = async (pokedexId) => {
    if (!localStorage.getItem('token')) {
      alert('Please log in to save favorites');
      return;
    }
    if (favorites.has(pokedexId)) {
      await favoritesApi.remove(pokedexId);
      setFavorites(prev => { const s = new Set(prev); s.delete(pokedexId); return s; });
    } else {
      await favoritesApi.add(pokedexId);
      setFavorites(prev => new Set([...prev, pokedexId]));
    }
  };

  return (
    <div style={{ padding: '20px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ color: '#CC0000', textAlign: 'center', marginBottom: '20px' }}>
        Pokédex Live
      </h1>

      {/* Type filter buttons */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '20px', justifyContent: 'center' }}>
        <button
          onClick={() => { setTypeFilter(''); setPage(1); }}
          style={{ padding: '4px 12px', borderRadius: '12px', border: 'none', cursor: 'pointer',
                   background: !typeFilter ? '#CC0000' : '#eee', color: !typeFilter ? 'white' : 'black' }}
        >
          All
        </button>
        {TYPES.map(t => (
          <button key={t} onClick={() => { setTypeFilter(t); setPage(1); }}
            style={{ padding: '4px 12px', borderRadius: '12px', border: 'none', cursor: 'pointer',
                     background: typeFilter === t ? TYPE_COLORS[t] : '#eee',
                     color: typeFilter === t ? 'white' : 'black', textTransform: 'capitalize' }}
          >{t}</button>
        ))}
      </div>

      {loading && <p style={{ textAlign: 'center' }}>Loading...</p>}

      {/* Pokémon grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '16px' }}>
        {pokemon.map(p => (
          <div key={p.id} style={{ background: 'white', borderRadius: '12px', padding: '16px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.1)', textAlign: 'center', position: 'relative' }}>
            {/* Favorite star button */}
            <button onClick={() => toggleFavorite(p.pokedex_id)}
              style={{ position: 'absolute', top: '8px', right: '8px', background: 'none',
                       border: 'none', fontSize: '18px', cursor: 'pointer' }}>
              {favorites.has(p.pokedex_id) ? '⭐' : '☆'}
            </button>
            <img src={p.sprite_url} alt={p.name}
              style={{ width: '80px', height: '80px', objectFit: 'contain' }} />
            <p style={{ color: '#999', fontSize: '12px' }}>
              #{String(p.pokedex_id).padStart(3, '0')}
            </p>
            <p style={{ fontWeight: 'bold', textTransform: 'capitalize', marginBottom: '8px' }}>
              {p.name}
            </p>
            <div style={{ display: 'flex', gap: '4px', justifyContent: 'center', flexWrap: 'wrap' }}>
              <span style={{ background: TYPE_COLORS[p.primary_type] || '#999', color: 'white',
                  padding: '2px 8px', borderRadius: '8px', fontSize: '11px', textTransform: 'capitalize' }}>
                {p.primary_type}
              </span>
              {p.secondary_type && (
                <span style={{ background: TYPE_COLORS[p.secondary_type] || '#999', color: 'white',
                    padding: '2px 8px', borderRadius: '8px', fontSize: '11px', textTransform: 'capitalize' }}>
                  {p.secondary_type}
                </span>
              )}
            </div>
            {p.favorite_count > 0 && (
              <p style={{ color: '#999', fontSize: '11px', marginTop: '4px' }}>
                ⭐ {p.favorite_count}
              </p>
            )}
          </div>
        ))}
      </div>

      {/* Pagination */}
      <div style={{ display: 'flex', justifyContent: 'center', gap: '16px', marginTop: '24px', alignItems: 'center' }}>
        <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
          style={{ padding: '8px 20px', background: '#CC0000', color: 'white', border: 'none',
                   borderRadius: '6px', cursor: 'pointer', opacity: page === 1 ? 0.5 : 1 }}>
          Previous
        </button>
        <span>Page {page} of {Math.ceil(total / 20)}</span>
        <button onClick={() => setPage(p => p + 1)} disabled={page >= Math.ceil(total / 20)}
          style={{ padding: '8px 20px', background: '#CC0000', color: 'white', border: 'none',
                   borderRadius: '6px', cursor: 'pointer', opacity: page >= Math.ceil(total / 20) ? 0.5 : 1 }}>
          Next
        </button>
      </div>
    </div>
  );
}