import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { OctagonAlertIcon } from '../components/icons';

export const Unauthorized = () => {
  const { role } = useAuth();

  return (
    <div className="auth-container">
      <div className="auth-card" style={{ textAlign: 'center' }}>
        <div style={{ marginBottom: '1rem', color: '#ef4444' }}>
          <OctagonAlertIcon size={56} />
        </div>
        <h2>403 - Access Denied</h2>
        <p style={{ color: '#64748b', marginTop: '0.5rem', marginBottom: '1.5rem' }}>
          Your current role (<strong>{role || 'Unauthenticated'}</strong>) is not authorized to access this protected area.
        </p>
        <div className="alert alert-error" style={{ textAlign: 'left', marginBottom: '1.5rem' }}>
          <strong>Policy Notice:</strong> This section is strictly restricted to authorized administrative personnel.
        </div>
        <Link to="/dashboard" className="btn btn-primary btn-block">
          Return to Dashboard
        </Link>
      </div>
    </div>
  );
};

export default Unauthorized;
