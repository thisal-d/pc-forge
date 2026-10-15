import React, { createContext, useContext, useState, useEffect } from 'react';
import { authService } from '../services/authService';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);

  // Initialize authentication state on load
  useEffect(() => {
    const storedToken = authService.getToken();
    const storedUser = authService.getCurrentUser();

    if (storedToken && storedUser) {
      const userRole = (storedUser.role || '').trim().toLowerCase();
      if (userRole === 'customer') {
        authService.logout();
        setToken(null);
        setUser(null);
      } else {
        setToken(storedToken);
        setUser(storedUser);
      }
    }
    setLoading(false);
  }, []);

  const login = async (email, password) => {
    const data = await authService.login(email, password);
    const userRole = (data?.role || '').trim().toLowerCase();
    if (userRole === 'customer') {
      logout();
      throw new Error('Access denied. Customer accounts are not permitted to log into the Web Portal. Please use the PCForge mobile application.');
    }
    setToken(data.token);
    setUser({
      userId: data.userId,
      email: data.email,
      role: data.role,
      firstName: data.firstName,
      lastName: data.lastName,
    });
    return data;
  };

  const register = async (userData) => {
    const data = await authService.register(userData);
    const userRole = (data?.role || '').trim().toLowerCase();
    if (userRole === 'customer') {
      logout();
      throw new Error('Access denied. Customer accounts cannot access the Web Portal.');
    }
    setToken(data.token);
    setUser({
      userId: data.userId,
      email: data.email,
      role: data.role,
      firstName: data.firstName,
      lastName: data.lastName,
    });
    return data;
  };

  const logout = () => {
    authService.logout();
    setToken(null);
    setUser(null);
  };

  const value = {
    user,
    token,
    role: user?.role || null,
    isAuthenticated: !!token && !!user,
    loading,
    login,
    register,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export default AuthContext;
