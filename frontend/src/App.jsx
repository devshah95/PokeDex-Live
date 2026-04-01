import { useState } from 'react';
import { BrowserRouter, Routes, Route, Link, Navigate } from 'react-router-dom';
import Pokedex  from './pages/Pokedex';
import Login    from './pages/Login';
import Register from './pages/Register';

function Navbar({ user, onLogout }) {
  return (
    <nav style={{ background: '#CC0000', padding: '12px 24px', display: 'flex',
        justifyContent: 'space-between', alignItems: 'center', boxShadow: '0 2px 8px rgba(0,0,0,0.2)' }}>
      <Link to="/" style={{ color: 'white', textDecoration: 'none', fontWeight: 'bold', fontSize: '20px' }}>
        🔴 PokéDex Live
      </Link>
      <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
        {user ? (
          <>
            <span style={{ color: 'white', fontSize: '14px' }}>👤 {user.username}</span>
            <button onClick={onLogout}
              style={{ background: 'rgba(255,255,255,0.2)', color: 'white', border: '1px solid white',
                       padding: '6px 14px', borderRadius: '6px', cursor: 'pointer' }}>
              Logout
            </button>
          </>
        ) : (
          <>
            <Link to="/login"    style={{ color: 'white', textDecoration: 'none' }}>Login</Link>
            <Link to="/register" style={{ color: 'white', textDecoration: 'none',
                background: 'rgba(255,255,255,0.2)', padding: '6px 14px', borderRadius: '6px' }}>
              Register
            </Link>
          </>
        )}
      </div>
    </nav>
  );
}

export default function App() {
  const [user, setUser] = useState(
    localStorage.getItem('token')
      ? { username: 'User' }
      : null
  );

  const handleLogin = (userData) => setUser(userData);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('userId');
    setUser(null);
  };

  return (
    <BrowserRouter>
      <div style={{ minHeight: '100vh', background: '#f5f5f5' }}>
        <Navbar user={user} onLogout={handleLogout} />
        <Routes>
          <Route path="/"         element={<Pokedex />} />
          <Route path="/login"    element={<Login    onLogin={handleLogin} />} />
          <Route path="/register" element={<Register onLogin={handleLogin} />} />
          <Route path="*"         element={<Navigate to="/" />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}