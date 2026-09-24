import React, { useState } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const from = location.state?.from?.pathname || '/dashboard';

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSubmitting(true);

    try {
      await login(email, password);
      navigate(from, { replace: true });
    } catch (err) {
      const msg = err.response?.data?.message || 'Login failed. Please verify your credentials.';
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  const fillCredentials = (quickEmail, quickPassword) => {
    setEmail(quickEmail);
    setPassword(quickPassword);
    setError('');
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <div className="auth-header">
          <img src="/logo.png" alt="PCForge Logo" className="auth-logo-img" />
          <h2>Welcome to PCForge</h2>
          <p>Sign in to access your platform account</p>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <form onSubmit={handleSubmit} className="auth-form">
          <div className="form-group">
            <label htmlFor="email">Email Address</label>
            <input
              id="email"
              type="email"
              placeholder="user@pcforge.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <button type="submit" disabled={submitting} className="btn btn-primary btn-block">
            {submitting ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <div className="demo-credentials-box">
          <span className="demo-title">Quick Test Credentials:</span>
          <div className="demo-chips">
            <button
              type="button"
              className="chip chip-admin"
              onClick={() => fillCredentials('admin@pcforge.com', 'Admin123!')}
            >
              Admin
            </button>
            <button
              type="button"
              className="chip chip-staff"
              onClick={() => fillCredentials('staff@pcforge.com', 'Staff123!')}
            >
              Staff
            </button>
            <button
              type="button"
              className="chip chip-customer"
              onClick={() => fillCredentials('customer@pcforge.com', 'Cust123!')}
            >
              Customer
            </button>
          </div>
        </div>

        <p className="auth-footer">
          Don't have an account? <Link to="/register">Create one here</Link>
        </p>
      </div>
    </div>
  );
};

export default Login;
