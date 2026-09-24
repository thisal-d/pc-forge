import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export const ProtectedRoute = ({ children, allowedRoles = [] }) => {
  const { isAuthenticated, role, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <p>Loading session...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    // Redirect unauthenticated users to /login and preserve return URL
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (allowedRoles.length > 0) {
    const userRoleLower = (role || '').trim().toLowerCase();
    // Admin is a superuser with full access to any Staff/Customer-authorized route
    const isAllowed =
      allowedRoles.some((r) => r.toLowerCase() === userRoleLower) ||
      (userRoleLower === 'admin' && allowedRoles.some((r) => ['staff', 'customer'].includes(r.toLowerCase())));

    if (!isAllowed) {
      // User does not possess the required role (e.g., Staff accessing Admin-only screen)
      return <Navigate to="/unauthorized" replace />;
    }
  }

  return children;
};

export default ProtectedRoute;
