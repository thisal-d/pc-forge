import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ProtectedRoute } from './components/ProtectedRoute';
import { Navbar } from './components/Navbar';
import { Sidebar } from './components/Sidebar';

import { Login } from './pages/Login';
import { Register } from './pages/Register';
import { Dashboard } from './pages/Dashboard';
import { Inventory } from './pages/Inventory';
import { Unauthorized } from './pages/Unauthorized';
import { StaffManagement } from './pages/StaffManagement';
import { CategoryManagement } from './pages/CategoryManagement';
import { ProductManagement } from './pages/ProductManagement';
import { SupportTickets } from './pages/SupportTickets';
import { BuildReviews } from './pages/BuildReviews';
import { OrderManagement } from './pages/OrderManagement';
import { CouponManagement } from './pages/CouponManagement';
import { FilterManagement } from './pages/FilterManagement';

const AppLayout = () => {
  const { isAuthenticated } = useAuth();

  return (
    <div className="app-layout">
      <Navbar />
      <div className={`app-body ${isAuthenticated ? 'has-sidebar' : 'no-sidebar'}`}>
        {isAuthenticated && <Sidebar />}
        <main className="main-content">
          <Routes>
            {/* Public Routes */}
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/unauthorized" element={<Unauthorized />} />

            {/* Protected Routes (All Authenticated Roles) */}
            <Route
              path="/dashboard"
              element={
                <ProtectedRoute>
                  <Dashboard />
                </ProtectedRoute>
              }
            />

            {/* Staff & Admin Protected Route */}
            <Route
              path="/orders"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <OrderManagement />
                </ProtectedRoute>
              }
            />
            <Route
              path="/inventory"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <Inventory />
                </ProtectedRoute>
              }
            />
            <Route
              path="/build-reviews"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <BuildReviews />
                </ProtectedRoute>
              }
            />
            <Route
              path="/support"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <SupportTickets />
                </ProtectedRoute>
              }
            />
            <Route
              path="/service-requests"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <SupportTickets />
                </ProtectedRoute>
              }
            />
            <Route
              path="/coupons"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <CouponManagement />
                </ProtectedRoute>
              }
            />
            <Route
              path="/staff"
              element={
                <ProtectedRoute allowedRoles={['Admin']}>
                  <StaffManagement />
                </ProtectedRoute>
              }
            />
            <Route
              path="/products"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <ProductManagement />
                </ProtectedRoute>
              }
            />
            <Route
              path="/categories"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <CategoryManagement />
                </ProtectedRoute>
              }
            />
            <Route
              path="/filters"
              element={
                <ProtectedRoute allowedRoles={['Admin', 'Staff']}>
                  <FilterManagement />
                </ProtectedRoute>
              }
            />

            {/* Default Redirect */}
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </main>
      </div>
    </div>
  );
};

export const App = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppLayout />
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;
