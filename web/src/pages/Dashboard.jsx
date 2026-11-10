import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useAuth } from '../context/AuthContext';
import { orderService } from '../services/orderService';
import { buildReviewService } from '../services/buildReviewService';
import { serviceRequestService } from '../services/serviceRequestService';
import { productService } from '../services/productService';
import {
  DashboardSummaryCards,
  DashboardAttentionQueue,
  DashboardSalesChart,
  DashboardStatusChart,
  DashboardRoleNav,
} from '../components/dashboard';
import { RefreshCwIcon, AlertTriangleIcon } from '../components/icons';
import '../styles/pages/dashboard.css';

export const Dashboard = () => {
  const { user, role } = useAuth();

  // State management
  const [orders, setOrders] = useState([]);
  const [builds, setBuilds] = useState([]);
  const [services, setServices] = useState([]);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);
  const [lastRefreshed, setLastRefreshed] = useState(null);

  // Operational perspective filter: 'all' | 'technician' | 'inventory'
  const [perspective, setPerspective] = useState('all');
  const [activeKpiFilter, setActiveKpiFilter] = useState(null);

  // Fetch dashboard telemetry from existing ASP.NET Core API endpoints
  const loadDashboardData = useCallback(async (isManualRefresh = false) => {
    if (isManualRefresh) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }
    setError(null);

    try {
      const [ordersRes, buildsRes, servicesRes, productsRes] = await Promise.allSettled([
        orderService.getOrders(),
        buildReviewService.fetchBuilds(),
        serviceRequestService.fetchServiceRequests(),
        productService.getProducts(),
      ]);

      let hasSuccess = false;

      if (ordersRes.status === 'fulfilled' && Array.isArray(ordersRes.value)) {
        setOrders(ordersRes.value);
        hasSuccess = true;
      } else {
        console.warn('Orders telemetry unavailable:', ordersRes.reason);
      }

      if (buildsRes.status === 'fulfilled' && Array.isArray(buildsRes.value)) {
        setBuilds(buildsRes.value);
        hasSuccess = true;
      } else {
        console.warn('Custom builds telemetry unavailable:', buildsRes.reason);
      }

      if (servicesRes.status === 'fulfilled' && Array.isArray(servicesRes.value)) {
        setServices(servicesRes.value);
        hasSuccess = true;
      } else {
        console.warn('Service requests telemetry unavailable:', servicesRes.reason);
      }

      if (productsRes.status === 'fulfilled' && Array.isArray(productsRes.value)) {
        setProducts(productsRes.value);
        hasSuccess = true;
      } else {
        console.warn('Product catalog telemetry unavailable:', productsRes.reason);
      }

      // If all 4 calls failed, record error banner
      if (!hasSuccess && (ordersRes.reason || buildsRes.reason || servicesRes.reason)) {
        setError('Unable to synchronize with backend services. Please check connection and retry.');
      } else {
        setLastRefreshed(new Date());
      }
    } catch (err) {
      console.error('Unexpected dashboard load error:', err);
      setError(err.message || 'An error occurred while loading dashboard metrics.');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    loadDashboardData(false);
  }, [loadDashboardData]);

  // Compute live high-level KPI stats
  const dashboardStats = useMemo(() => {
    const totalOrders = orders.length;
    let completedOrders = 0;
    let pendingOrders = 0;
    let totalRevenue = 0;

    orders.forEach((o) => {
      const s = (o.status || '').toLowerCase().trim();
      if (s === 'paid & completed' || s === 'paid and completed') {
        completedOrders++;
      } else if (s === 'order placed' || s === 'processing') {
        pendingOrders++;
      }

      if (s !== 'cancelled') {
        totalRevenue += Number(o.totalAmount || o.TotalAmount) || 0;
      }
    });

    const pendingBuildsList = builds.filter((b) => {
      const s = (b.status || '').toLowerCase();
      return (
        s === 'pending staff review' ||
        s === 'submitted' ||
        s.includes('pending') ||
        s === 'changes requested'
      );
    });

    const pendingServicesList = services.filter((sr) => {
      const s = (sr.status || '').toUpperCase().replace(/_/g, ' ');
      return s === 'BOOKED' || s === 'PENDING';
    });

    return {
      totalOrders,
      completedOrders,
      pendingOrders,
      totalRevenue,
      totalBuilds: builds.length,
      pendingBuilds: pendingBuildsList.length,
      totalServices: services.length,
      pendingServices: pendingServicesList.length,
    };
  }, [orders, builds, services]);

  // Filtered action queue items
  const pendingBuildsQueue = useMemo(() => {
    return builds.filter((b) => {
      const s = (b.status || '').toLowerCase();
      return (
        s === 'pending staff review' ||
        s === 'submitted' ||
        s.includes('pending') ||
        s === 'changes requested'
      );
    });
  }, [builds]);

  const pendingServicesQueue = useMemo(() => {
    return services.filter((sr) => {
      const s = (sr.status || '').toUpperCase().replace(/_/g, ' ');
      return s === 'BOOKED' || s === 'PENDING';
    });
  }, [services]);

  const pendingOrdersQueue = useMemo(() => {
    return orders.filter((o) => {
      const s = (o.status || '').toLowerCase();
      return s === 'order placed' || s === 'processing';
    });
  }, [orders]);

  const lowStockProductsList = useMemo(() => {
    return products.filter((p) => Number(p.stockQuantity) <= 5);
  }, [products]);

  // Handle card click filter
  const handleKpiCardClick = (cardId) => {
    if (activeKpiFilter === cardId) {
      setActiveKpiFilter(null);
    } else {
      setActiveKpiFilter(cardId);
      // Smoothly scroll down to the relevant section
      if (cardId === 'pending-builds' || cardId === 'pending-services' || cardId === 'pending-orders') {
        const el = document.getElementById('items-requiring-attention');
        if (el) el.scrollIntoView({ behavior: 'smooth' });
      } else if (cardId === 'total-orders' || cardId === 'total-revenue') {
        const el = document.getElementById('sales-overview-chart-card');
        if (el) el.scrollIntoView({ behavior: 'smooth' });
      }
    }
  };

  return (
    <div className="page-container dashboard-page">
      {/* 1. Header with greeting, role badge, last refreshed, and action controls */}
      <div className="dashboard-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
            <h1>System Overview</h1>
            <span className={`badge badge-lg badge-${(role || 'staff').toLowerCase()}`}>
              {role === 'Admin' ? 'Administrator' : 'Staff Member'}
            </span>
            {lastRefreshed && (
              <span className="last-sync-time">
                Synced at {lastRefreshed.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              </span>
            )}
          </div>
          <p className="subtitle">
            Welcome back, <strong>{user?.firstName || 'Staff'} {user?.lastName || ''}</strong>. Here is the operational pulse across orders, custom builds, and service requests.
          </p>
        </div>

        <div className="dashboard-header-actions">
          <button
            type="button"
            className="btn btn-outline"
            onClick={() => loadDashboardData(true)}
            disabled={refreshing || loading}
            id="dashboard-refresh-btn"
          >
            <RefreshCwIcon size={16} className={refreshing ? 'spin' : ''} />
            <span>{refreshing ? 'Synchronizing...' : 'Refresh Telemetry'}</span>
          </button>
        </div>
      </div>

      {/* Error Banner with retry */}
      {error && (
        <div className="dashboard-alert-banner alert-error" id="dashboard-error-banner">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
            <AlertTriangleIcon size={18} style={{ color: 'var(--danger)', flexShrink: 0 }} />
            <span>{error}</span>
          </div>
          <button
            type="button"
            className="btn btn-outline-sm"
            onClick={() => loadDashboardData(false)}
          >
            Retry
          </button>
        </div>
      )}

      {/* Loading Skeletons */}
      {loading ? (
        <div className="dashboard-skeleton-wrapper" id="dashboard-loading-state">
          <div className="dashboard-skeleton-grid">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="skeleton-card" />
            ))}
          </div>
          <div className="skeleton-card skeleton-attention" style={{ height: '240px', marginTop: '1.5rem' }} />
          <div className="skeleton-charts-row" style={{ marginTop: '1.5rem', display: 'grid', gridTemplateColumns: '3fr 2fr', gap: '1.5rem' }}>
            <div className="skeleton-card" style={{ height: '320px' }} />
            <div className="skeleton-card" style={{ height: '320px' }} />
          </div>
        </div>
      ) : (
        <>
          {/* 2. Top Summary KPI Cards */}
          <DashboardSummaryCards
            stats={dashboardStats}
            role={role}
            onCardClick={handleKpiCardClick}
            activeFilter={activeKpiFilter}
          />

          {/* 3. Items Requiring Immediate Attention (Placed First, Before Charts) */}
          <DashboardAttentionQueue
            pendingBuilds={pendingBuildsQueue}
            pendingServices={pendingServicesQueue}
            pendingOrders={pendingOrdersQueue}
            lowStockProducts={lowStockProductsList}
            role={role}
            perspective={perspective}
          />

          {/* 4. Useful Charts (Sales Overview & Order Status Breakdown) */}
          <div className="dashboard-charts-grid" id="dashboard-charts-section">
            <DashboardSalesChart orders={orders} role={role} />
            <DashboardStatusChart orders={orders} />
          </div>

          {/* 5. Role-Based Operations & Quick Navigation */}
          <DashboardRoleNav
            role={role}
            perspective={perspective}
            onSelectPerspective={setPerspective}
          />
        </>
      )}
    </div>
  );
};

export default Dashboard;
