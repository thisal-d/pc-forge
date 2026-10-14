import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export const Register = () => {
  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    email: '',
    password: '',
    confirmPassword: '',
    role: 'Customer',
  });
  const [fieldErrors, setFieldErrors] = useState({});
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const { register } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    // Clear field-specific error as user types
    if (fieldErrors[name]) {
      setFieldErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const validate = () => {
    const errors = {};

    if (!formData.firstName.trim()) {
      errors.firstName = 'First name is required.';
    } else if (formData.firstName.trim().length < 2) {
      errors.firstName = 'First name must be at least 2 characters.';
    }

    if (!formData.lastName.trim()) {
      errors.lastName = 'Last name is required.';
    } else if (formData.lastName.trim().length < 2) {
      errors.lastName = 'Last name must be at least 2 characters.';
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!formData.email.trim()) {
      errors.email = 'Email address is required.';
    } else if (!emailRegex.test(formData.email.trim())) {
      errors.email = 'Please enter a valid email address (e.g. user@example.com).';
    }

    if (!formData.password) {
      errors.password = 'Password is required.';
    } else if (formData.password.length < 8) {
      errors.password = 'Password must be at least 8 characters long.';
    }

    if (!formData.confirmPassword) {
      errors.confirmPassword = 'Confirming your password is required.';
    } else if (formData.password !== formData.confirmPassword) {
      errors.confirmPassword = 'Passwords do not match.';
    }

    return errors;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    const validationErrors = validate();
    if (Object.keys(validationErrors).length > 0) {
      setFieldErrors(validationErrors);
      setError('Please resolve the highlighted errors before submitting.');
      return;
    }

    setSubmitting(true);

    try {
      const { confirmPassword, ...payload } = formData;
      await register(payload);
      navigate('/dashboard', { replace: true });
    } catch (err) {
      const msg = err.response?.data?.message || 'Registration failed. Please check your inputs.';
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <div className="auth-header">
          <h2>Create an Account</h2>
          <p>Register as a Customer, Admin, or Staff</p>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <form onSubmit={handleSubmit} className="auth-form" noValidate>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="firstName">First Name *</label>
              <input
                id="firstName"
                name="firstName"
                type="text"
                placeholder="John"
                value={formData.firstName}
                onChange={handleChange}
                className={fieldErrors.firstName ? 'input-error' : ''}
                required
              />
              {fieldErrors.firstName && <span className="field-error-text">{fieldErrors.firstName}</span>}
            </div>
            <div className="form-group">
              <label htmlFor="lastName">Last Name *</label>
              <input
                id="lastName"
                name="lastName"
                type="text"
                placeholder="Doe"
                value={formData.lastName}
                onChange={handleChange}
                className={fieldErrors.lastName ? 'input-error' : ''}
                required
              />
              {fieldErrors.lastName && <span className="field-error-text">{fieldErrors.lastName}</span>}
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="email">Email Address *</label>
            <input
              id="email"
              name="email"
              type="email"
              placeholder="user@example.com"
              value={formData.email}
              onChange={handleChange}
              className={fieldErrors.email ? 'input-error' : ''}
              required
            />
            {fieldErrors.email && <span className="field-error-text">{fieldErrors.email}</span>}
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="password">Password (min 8 characters) *</label>
              <input
                id="password"
                name="password"
                type="password"
                placeholder="At least 8 characters"
                value={formData.password}
                onChange={handleChange}
                minLength={8}
                className={fieldErrors.password ? 'input-error' : ''}
                required
              />
              {fieldErrors.password && <span className="field-error-text">{fieldErrors.password}</span>}
            </div>

            <div className="form-group">
              <label htmlFor="confirmPassword">Confirm Password *</label>
              <input
                id="confirmPassword"
                name="confirmPassword"
                type="password"
                placeholder="Re-enter password"
                value={formData.confirmPassword}
                onChange={handleChange}
                className={fieldErrors.confirmPassword ? 'input-error' : ''}
                required
              />
              {fieldErrors.confirmPassword && (
                <span className="field-error-text">{fieldErrors.confirmPassword}</span>
              )}
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="role">Assign Role</label>
            <select
              id="role"
              name="role"
              value={formData.role}
              onChange={handleChange}
            >
              <option value="Customer">Customer (Mobile/Store user)</option>
              <option value="Admin">Admin (Full inventory & system oversight)</option>
              <option value="Staff">Staff (Build, inventory & support oversight)</option>
            </select>
          </div>

          <button type="submit" disabled={submitting} className="btn btn-primary btn-block">
            {submitting ? 'Registering...' : 'Register Account'}
          </button>
        </form>

        <p className="auth-footer">
          Already registered? <Link to="/login">Sign in here</Link>
        </p>
      </div>
    </div>
  );
};

export default Register;
