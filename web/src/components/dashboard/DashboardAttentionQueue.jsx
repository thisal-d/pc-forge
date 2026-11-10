import React from 'react';
import { Link } from 'react-router-dom';
import { ToolsIcon, WrenchIcon, PackageIcon, AlertTriangleIcon, CheckCircleIcon } from '../icons/index.js';

export const DashboardAttentionQueue = ({
  pendingBuilds = [],
  pendingServices = [],
  pendingOrders = [],
  lowStockProducts = [],
  role = 'Staff',
  perspective = 'all',
}) => {
  const isTechnicianFocused = perspective === 'technician';
  const isInventoryFocused = perspective === 'inventory';

  // Format date helper
  const formatDate = (dateStr) => {
    if (!dateStr) return 'Recent';
    try {
      const d = new Date(dateStr);
      if (isNaN(d.getTime())) return dateStr;
      return d.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
      });
    } catch {
      return dateStr;
    }
  };

  // Format currency helper
  const formatCurrency = (amt) => {
    const val = Number(amt) || 0;
    return `LKR ${val.toLocaleString('en-US', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    })}`;
  };

  return (
    <section className="dashboard-attention-section" id="items-requiring-attention">
      <div className="section-header-row">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <h2 className="section-title">Items Requiring Immediate Attention</h2>
            <span className="badge badge-warning" style={{ fontSize: '0.75rem', fontWeight: 600 }}>
              Action Queue
            </span>
          </div>
          <p className="section-subtitle">
            Prioritized operational queue for technical clearance, service diagnostics, and order fulfillment.
          </p>
        </div>
      </div>

      {/* Low Stock Warning Alert if any items are critically low */}
      {lowStockProducts.length > 0 && !isTechnicianFocused && (
        <div className="dashboard-alert-banner alert-warning" id="low-stock-alert">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
            <AlertTriangleIcon size={18} style={{ color: 'var(--warning-text)', flexShrink: 0 }} />
            <span>
              <strong>Inventory Notice:</strong> {lowStockProducts.length} product{lowStockProducts.length > 1 ? 's have' : ' has'} low stock (&le; 5 units). Replenishment required.
            </span>
          </div>
          <Link to="/inventory" className="btn btn-outline-sm" id="attention-restock-link">
            Check Stock &rarr;
          </Link>
        </div>
      )}

      <div className="attention-grid">
        {/* 1. Pending Custom Builds Queue */}
        {!isInventoryFocused && (
          <div className="attention-card" id="attention-card-builds">
            <div className="attention-card-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span className="attention-icon-badge icon-badge-tools">
                  <ToolsIcon size={16} />
                </span>
                <h3 className="attention-card-title">Custom Builds Pending Clearance</h3>
              </div>
              <span className={`badge ${pendingBuilds.length > 0 ? 'badge-error' : 'badge-success'}`}>
                {pendingBuilds.length} Awaiting
              </span>
            </div>

            <div className="attention-card-body">
              {pendingBuilds.length === 0 ? (
                <div className="attention-empty-state">
                  <CheckCircleIcon size={28} style={{ color: 'var(--success)' }} />
                  <p>All custom builds cleared!</p>
                  <span>No pending technical compatibility checks.</span>
                </div>
              ) : (
                <div className="attention-items-list">
                  {pendingBuilds.slice(0, 4).map((b) => (
                    <div key={b.buildId} className="attention-item-row" id={`attention-build-${b.buildId}`}>
                      <div className="attention-item-info">
                        <div className="attention-item-header">
                          <span className="attention-item-id">#BLD-{b.buildId}</span>
                          <span className="attention-item-date">{formatDate(b.createdAt)}</span>
                        </div>
                        <div className="attention-item-name">{b.buildName || 'Custom PC Build'}</div>
                        <div className="attention-item-meta">
                          <span>{formatCurrency(b.totalPrice)}</span>
                          <span className="meta-bullet">&bull;</span>
                          <span>{b.components?.length || 'Configured'} Parts</span>
                        </div>
                      </div>
                      <div className="attention-item-action">
                        <Link
                          to="/build-reviews"
                          className="btn btn-outline-sm btn-action-accent"
                          id={`btn-review-build-${b.buildId}`}
                        >
                          Review &rarr;
                        </Link>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="attention-card-footer">
              <Link to="/build-reviews" className="attention-view-all" id="view-all-builds-link">
                Open Build Reviews Queue ({pendingBuilds.length}) &rarr;
              </Link>
            </div>
          </div>
        )}

        {/* 2. Service Requests Awaiting Action */}
        {!isInventoryFocused && (
          <div className="attention-card" id="attention-card-services">
            <div className="attention-card-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span className="attention-icon-badge icon-badge-wrench">
                  <WrenchIcon size={16} />
                </span>
                <h3 className="attention-card-title">Service Requests Awaiting Action</h3>
              </div>
              <span className={`badge ${pendingServices.length > 0 ? 'badge-warning' : 'badge-success'}`}>
                {pendingServices.length} Pending
              </span>
            </div>

            <div className="attention-card-body">
              {pendingServices.length === 0 ? (
                <div className="attention-empty-state">
                  <CheckCircleIcon size={28} style={{ color: 'var(--success)' }} />
                  <p>Queue clear!</p>
                  <span>No service requests awaiting technician triage.</span>
                </div>
              ) : (
                <div className="attention-items-list">
                  {pendingServices.slice(0, 4).map((s) => {
                    const srNum = s.serviceRequestNumber || `SR-${s.serviceRequestId || s.id}`;
                    return (
                      <div key={s.serviceRequestId || s.id} className="attention-item-row" id={`attention-sr-${s.serviceRequestId || s.id}`}>
                        <div className="attention-item-info">
                          <div className="attention-item-header">
                            <span className="attention-item-id">{srNum}</span>
                            <span className="attention-item-date">{formatDate(s.createdAt)}</span>
                          </div>
                          <div className="attention-item-name">{s.title || 'Technical Service Diagnosis'}</div>
                          <div className="attention-item-meta">
                            <span>Status: {s.status || 'Booked'}</span>
                            {s.preferredDate && (
                              <>
                                <span className="meta-bullet">&bull;</span>
                                <span>Slot: {s.preferredDate} {s.preferredTime || ''}</span>
                              </>
                            )}
                          </div>
                        </div>
                        <div className="attention-item-action">
                          <Link
                            to="/service-requests"
                            className="btn btn-outline-sm btn-action-tech"
                            id={`btn-action-sr-${s.serviceRequestId || s.id}`}
                          >
                            Triage &rarr;
                          </Link>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            <div className="attention-card-footer">
              <Link to="/service-requests" className="attention-view-all" id="view-all-services-link">
                Open Service Workbench ({pendingServices.length}) &rarr;
              </Link>
            </div>
          </div>
        )}

        {/* 3. Orders Requiring Fulfillment */}
        {!isTechnicianFocused && (
          <div className="attention-card" id="attention-card-orders">
            <div className="attention-card-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span className="attention-icon-badge icon-badge-package">
                  <PackageIcon size={16} />
                </span>
                <h3 className="attention-card-title">Orders Awaiting Assembly & Dispatch</h3>
              </div>
              <span className={`badge ${pendingOrders.length > 0 ? 'badge-warning' : 'badge-success'}`}>
                {pendingOrders.length} To Process
              </span>
            </div>

            <div className="attention-card-body">
              {pendingOrders.length === 0 ? (
                <div className="attention-empty-state">
                  <CheckCircleIcon size={28} style={{ color: 'var(--success)' }} />
                  <p>All orders fulfilled!</p>
                  <span>No orders in placed or processing states.</span>
                </div>
              ) : (
                <div className="attention-items-list">
                  {pendingOrders.slice(0, 4).map((o) => (
                    <div key={o.orderId} className="attention-item-row" id={`attention-order-${o.orderId}`}>
                      <div className="attention-item-info">
                        <div className="attention-item-header">
                          <span className="attention-item-id">#ORD-{o.orderId}</span>
                          <span className="attention-item-date">{formatDate(o.createdAt)}</span>
                        </div>
                        <div className="attention-item-name">
                          {o.itemCount || 1} Item{(o.itemCount || 1) > 1 ? 's' : ''} &bull; {o.status || 'Order placed'}
                        </div>
                        <div className="attention-item-meta">
                          <span>{formatCurrency(o.totalAmount || o.TotalAmount)}</span>
                          <span className="meta-bullet">&bull;</span>
                          <span className={`status-pill-tiny status-${(o.status || '').toLowerCase().replace(/\s+/g, '-')}`}>
                            {o.status || 'Pending'}
                          </span>
                        </div>
                      </div>
                      <div className="attention-item-action">
                        <Link
                          to="/orders"
                          className="btn btn-outline-sm btn-action-order"
                          id={`btn-fulfill-order-${o.orderId}`}
                        >
                          Fulfill &rarr;
                        </Link>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="attention-card-footer">
              <Link to="/orders" className="attention-view-all" id="view-all-orders-link">
                Open Orders Pipeline ({pendingOrders.length}) &rarr;
              </Link>
            </div>
          </div>
        )}
      </div>
    </section>
  );
};

export default DashboardAttentionQueue;
