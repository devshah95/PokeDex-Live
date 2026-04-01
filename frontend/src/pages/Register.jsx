import { useState } from 'react';
import { authApi } from '../services/api';

export default function Register({ onLogin }) {
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const res = await authApi.register({ username, email, password });
      localStorage.setItem('token', res.data.token);
      localStorage.setItem('userId', res.data.user.id);
      onLogin(res.data.user);
    } catch (err) {
      setError(err.response?.data?.error || 'Registration failed');
    }
  };

  return (
    <div style={{ maxWidth: '400px', margin: '80px auto', padding: '32px',
      background: 'white', borderRadius: '12px', boxShadow: '0 4px 16px rgba(0,0,0,0.1)' }}>
      <h2 style={{ textAlign: 'center', color: '#CC0000' }}>Register</h2>
      {error && <p style={{ color: 'red', textAlign: 'center' }}>{error}</p>}
      <form onSubmit={handleSubmit}>
        <input type="text" placeholder="Username" value={username} onChange={e => setUsername(e.target.value)}
          style={{ width: '100%', padding: '10px', marginBottom: '12px', borderRadius: '6px',
          border: '1px solid #ddd', boxSizing: 'border-box' }} required />
        <input type="email" placeholder="Email" value={email} onChange={e => setEmail(e.target.value)}
          style={{ width: '100%', padding: '10px', marginBottom: '12px', borderRadius: '6px',
          border: '1px solid #ddd', boxSizing: 'border-box' }} required />
        <input type="password" placeholder="Password" value={password} onChange={e => setPassword(e.target.value)}
          style={{ width: '100%', padding: '10px', marginBottom: '16px', borderRadius: '6px',
          border: '1px solid #ddd', boxSizing: 'border-box' }} required />
        <button type="submit"
          style={{ width: '100%', padding: '12px', background: '#CC0000', color: 'white',
          border: 'none', borderRadius: '6px', cursor: 'pointer', fontSize: '16px' }}>
          Register
        </button>
      </form>
    </div>
  );
}