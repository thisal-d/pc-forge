import React, { useState, useEffect, useMemo } from 'react';
import { orderService, ORDER_STATUSES } from '../services/orderService.js';
import { useAuth } from '../context/AuthContext.jsx';
import { Pagination } from '../components/common/Pagination.jsx';
import { TableSkeleton } from '../components/common/TableSkeleton.jsx';
import '../styles/pages/orders.css';

export const OrderManagement = () => {
  const { user } = useAuth();

  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('date_desc');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Selected order for detailed modal
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [newStatus, setNewStatus] = useState('');
  const [statusUpdating, setStatusUpdating] = useState(false);

  // Toast notification
  const [notification, setNotification] = useState(null);

  const showNotification = (message, type = 'success') => {
    setNotification({ message, type });
    setTimeout(() => {
      setNotification(null);
    }, 4500);
  };

  // Fetch orders from API
  const loadOrders = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);

    try {
      const data = await orderService.getOrders({
        status: statusFilter,
        search: searchQuery,
      });
      setOrders(data);
    } catch (err) {
      console.error('Failed to load orders:', err);
      showNotification('Failed to fetch orders from backend.', 'error');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadOrders();
  }, [statusFilter]);

  // Reset pagination on filter or search change
  useEffect(() => {
    setCurrentPage(1);
  }, [statusFilter, searchQuery, sortBy]);

  // Derived sorted, filtered, and paginated orders
  const filteredOrders = useMemo(() => {
    let result = [...orders];

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter((o) => {
        const orderIdStr = String(o.orderId || '').toLowerCase();
        const customerName = String(o.customerName || '').toLowerCase();
        const customerEmail = String(o.customerEmail || '').toLowerCase();
        const tracking = String(o.trackingNumber || '').toLowerCase();
        return (
          orderIdStr.includes(q.replace(/^#ord-|^#/i, '')) ||
          customerName.includes(q) ||
          customerEmail.includes(q) ||
          tracking.includes(q)
        );
      });
    }

    return result.sort((a, b) => {
      switch (sortBy) {
        case 'date_asc':
          return new Date(a.createdAt || 0) - new Date(b.createdAt || 0);
        case 'total_desc':
          return (Number(b.totalAmount) || 0) - (Number(a.totalAmount) || 0);
        case 'total_asc':
          return (Number(a.totalAmount) || 0) - (Number(b.totalAmount) || 0);
        case 'date_desc':
        default:
          return new Date(b.createdAt || 0) - new Date(a.createdAt || 0);
      }
    });
  }, [orders, searchQuery, sortBy]);

  const sortedOrders = filteredOrders;
  const totalPages = Math.max(1, Math.ceil(filteredOrders.length / pageSize));
  const paginatedOrders = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredOrders.slice(start, start + pageSize);
  }, [filteredOrders, currentPage, pageSize]);

  // Handle search with enter or button
  const handleSearchSubmit = (e) => {
    e.preventDefault();
    loadOrders();
  };

  // Open detailed inspection modal
  const handleViewOrder = async (orderSummary) => {
    setSelectedOrder(orderSummary);
    setNewStatus(orderSummary.status || 'Pending');
    setModalLoading(true);

    try {
      const details = await orderService.getOrderById(orderSummary.orderId);
      setSelectedOrder(details);
      setNewStatus(details.status || 'Pending');
    } catch (err) {
      console.error('Failed to load order details:', err);
      showNotification('Failed to load complete order details.', 'error');
    } finally {
      setModalLoading(false);
    }
  };

  // Update order status
  const handleUpdateStatus = async () => {
    if (!selectedOrder || !newStatus) return;

    if (newStatus === selectedOrder.status) {
      showNotification('Order is already in this status.', 'error');
      return;
    }

    if (newStatus === 'Cancelled') {
      const confirmed = window.confirm(
        `Are you sure you want to cancel Order #${selectedOrder.orderId}? All ordered items will be automatically restocked into inventory.`
      );
      if (!confirmed) return;
    }

    setStatusUpdating(true);
    try {
      const updated = await orderService.updateOrderStatus(selectedOrder.orderId, newStatus);
      setSelectedOrder(updated);

      // Update in orders list
      setOrders((prev) =>
        prev.map((o) =>
          o.orderId === updated.orderId
            ? { ...o, status: updated.status, updatedAt: updated.updatedAt }
            : o
        )
      );

      showNotification(`Order #${updated.orderId} status updated to ${updated.status}.`);
    } catch (err) {
      console.error('Failed to update order status:', err);
      showNotification(err.message || 'Failed to update order status.', 'error');
    } finally {
      setStatusUpdating(false);
    }
  };

  // Overall KPI metrics
  const stats = useMemo(() => orderService.calculateStats(orders), [orders]);

  // Stepper progress index
  const getStepIndex = (status) => {
    const s = (status || '').toLowerCase();
    switch (s) {
      case 'pending':
        return 0;
      case 'paid':
        return 1;
      case 'processing':
        return 2;
      case 'shipped':
        return 3;
      case 'delivered':
        return 4;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  };

  // Status Badge CSS class helper
  const getBadgeClass = (status) => {
    const s = (status || '').toLowerCase();
    switch (s) {
      case 'paid':
        return 'status-paid';
      case 'processing':
        return 'status-processing';
      case 'shipped':
        return 'status-shipped';
      case 'delivered':
        return 'status-delivered';
      case 'cancelled':
        return 'status-cancelled';
      default:
        return 'status-pending';
    }
  };

  return (
    <div className="orders-page">
      {/* Toast Notification */}
      {notification && (
        <div className={`order-toast ${notification.type === 'error' ? 'toast-error' : 'toast-success'}`}>
          {notification.type === 'error' ? (
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
          ) : (
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
              <polyline points="22 4 12 14.01 9 11.01" />
            </svg>
          )}
          <span>{notification.message}</span>
        </div>
      )}

      {/* Page Header */}
      <div className="orders-header">
        <div className="orders-title-group">
          <h1>Order Management</h1>
          <p className="orders-subtitle">
            Track customer orders, manage fulfillment pipeline, and update shipping statuses.
          </p>
        </div>
        <div className="orders-header-actions">
          <button
            className="btn-secondary"
            onClick={() => loadOrders(true)}
            disabled={refreshing || loading}
          >
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              className={refreshing ? 'spin' : ''}
            >
              <path d="M23 4v6h-6" />
              <path d="M1 20v-6h6" />
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
            </svg>
            <span>{refreshing ? 'Refreshing...' : 'Refresh'}</span>
          </button>
        </div>
      </div>

      {/* KPI Summary Cards */}
      <div className="orders-metrics-grid">
        <div className="order-metric-card">
          <div className="metric-icon-box metric-icon-blue">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="2" y="7" width="20" height="14" rx="2" ry="2" />
              <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
            </svg>
          </div>
          <div className="metric-info">
            <span className="metric-label">Total Orders</span>
            <span className="metric-value">{stats.total}</span>
          </div>
        </div>

        <div className="order-metric-card">
          <div className="metric-icon-box metric-icon-amber">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <polyline points="12 6 12 12 16 14" />
            </svg>
          </div>
          <div className="metric-info">
            <span className="metric-label">Paid / Confirmed</span>
            <span className="metric-value">{stats.paid}</span>
          </div>
        </div>

        <div className="order-metric-card">
          <div className="metric-icon-box metric-icon-blue">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <polyline points="16.5 9.4 7.55 4.24 7.55 14.6" />
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
            </svg>
          </div>
          <div className="metric-info">
            <span className="metric-label">Processing</span>
            <span className="metric-value">{stats.processing}</span>
          </div>
        </div>

        <div className="order-metric-card">
          <div className="metric-icon-box metric-icon-purple">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="1" y="3" width="15" height="13" />
              <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
              <circle cx="5.5" cy="18.5" r="2.5" />
              <circle cx="18.5" cy="18.5" r="2.5" />
            </svg>
          </div>
          <div className="metric-info">
            <span className="metric-label">Shipped</span>
            <span className="metric-value">{stats.shipped}</span>
          </div>
        </div>

        <div className="order-metric-card">
          <div className="metric-icon-box metric-icon-emerald">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
              <polyline points="22 4 12 14.01 9 11.01" />
            </svg>
          </div>
          <div className="metric-info">
            <span className="metric-label">Delivered</span>
            <span className="metric-value">{stats.delivered}</span>
          </div>
        </div>

        <div className="order-metric-card">
          <div className="metric-icon-box metric-icon-emerald">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="12" y1="1" x2="12" y2="23" />
              <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
          </div>
          <div className="metric-info">
            <span className="metric-label">Total Revenue</span>
            <span className="metric-value">{orderService.formatCurrency(stats.totalRevenue)}</span>
          </div>
        </div>
      </div>

      {/* Filter and Search Toolbar */}
      <div className="orders-toolbar">
        <div className="toolbar-top-row">
          <form onSubmit={handleSearchSubmit} className="orders-search-box">
            <svg
              className="orders-search-icon"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              className="orders-search-input"
              placeholder="Search by Order #, Customer Name, or Email..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </form>

            {searchQuery.trim() && (
              <button
                className="btn-secondary"
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setTimeout(() => loadOrders(), 0);
                }}
              >
                Clear Search
              </button>
            )}

            {/* Sort Dropdown */}
            <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <label htmlFor="order-sort-select" style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Sort:</label>
              <select
                id="order-sort-select"
                className="orders-search-input"
                style={{ width: 'auto', padding: '0.4rem 0.75rem', fontSize: '0.85rem' }}
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
              >
                <option value="date_desc">Newest Orders First</option>
                <option value="date_asc">Oldest Orders First</option>
                <option value="total_desc">Total Amount: High to Low</option>
                <option value="total_asc">Total Amount: Low to High</option>
              </select>
            </div>
          </div>

          {/* Status Pills */}
          <div className="status-pills-row">
            <button
              className={`status-pill ${statusFilter === 'all' ? 'active' : ''}`}
              onClick={() => setStatusFilter('all')}
            >
              All Orders
              <span className="pill-count">{orders.length}</span>
            </button>
            {ORDER_STATUSES.map((st) => {
              const count = orders.filter((o) => (o.status || '').toLowerCase() === st.toLowerCase()).length;
              return (
                <button
                  key={st}
                  className={`status-pill ${statusFilter.toLowerCase() === st.toLowerCase() ? 'active' : ''}`}
                  onClick={() => setStatusFilter(st)}
                >
                  {st}
                  <span className="pill-count">{count}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Orders Table */}
        <div className="data-table-card">
          <div className="table-header-banner">
            <h3>Orders Directory ({filteredOrders.length})</h3>
            <span className="table-header-subtitle">
              Showing {paginatedOrders.length} of {orders.length} total orders
            </span>
          </div>
          <div className="table-responsive">
            <table className="data-table orders-table" id="orders-table">
              <thead>
                <tr>
                  <th>Order ID</th>
                  <th>Date & Time</th>
                  <th>Customer</th>
                  <th>Items</th>
                  <th>Total (LKR)</th>
                  <th>Payment</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              {loading ? (
                <TableSkeleton rows={pageSize} columns={8} />
              ) : filteredOrders.length === 0 ? (
                <tbody>
                  <tr>
                    <td colSpan="8" style={{ padding: 0 }}>
                      <div className="empty-state">
                        <div className="empty-state-icon">
                          <svg
                            width="36"
                            height="36"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth="1.5"
                          >
                            <rect x="2" y="7" width="20" height="14" rx="2" ry="2" />
                            <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
                          </svg>
                        </div>
                        <h4>No orders found</h4>
                        <p>No orders match the selected status or search filter.</p>
                        <button
                          type="button"
                          className="btn btn-outline-sm"
                          onClick={() => {
                            setSearchQuery('');
                            setStatusFilter('all');
                          }}
                        >
                          Clear Filters
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              ) : (
              <tbody>
                {paginatedOrders.map((order) => (
                  <tr key={order.orderId}>
                    <td className="order-id-cell">#ORD-{order.orderId}</td>
                    <td style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                      {orderService.formatDateTime(order.createdAt)}
                    </td>
                    <td>
                      <div className="customer-cell-wrapper">
                        <span className="customer-name">{order.customerName || 'Customer'}</span>
                        <span className="customer-email">{order.customerEmail || 'No email provided'}</span>
                      </div>
                    </td>
                    <td>
                      <span style={{ fontWeight: 600 }}>{order.itemCount}</span> items
                    </td>
                    <td className="order-total-cell">
                      {orderService.formatCurrency(order.totalAmount)}
                    </td>
                    <td>
                      <span style={{ fontSize: '0.8rem', color: 'var(--text-body)' }}>
                        {order.paymentMethod || 'Credit Card'}
                      </span>
                    </td>
                    <td>
                      <span className={`order-status-badge ${getBadgeClass(order.status)}`}>
                        {order.status}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button
                        className="btn btn-outline-sm"
                        onClick={() => handleViewOrder(order)}
                      >
                        View Details
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            )}
          </table>
        </div>

        {!loading && orders.length > 0 && (
          <Pagination
            currentPage={currentPage}
            totalPages={totalPages}
            totalItems={filteredOrders.length}
            pageSize={pageSize}
            pageSizeOptions={[10, 25, 50]}
            onPageChange={setCurrentPage}
            onPageSizeChange={(newSize) => {
              setPageSize(newSize);
              setCurrentPage(1);
            }}
            itemLabel="orders"
          />
        )}
      </div>

      {/* Order Detail Modal / Drawer */}
      {selectedOrder && (
        <div className="modal-overlay" onClick={() => setSelectedOrder(null)}>
          <div className="order-modal" onClick={(e) => e.stopPropagation()}>
            {/* Modal Header */}
            <div className="order-modal-header">
              <div className="modal-header-left">
                <h3 className="modal-header-title">Order #ORD-{selectedOrder.orderId}</h3>
                <span className={`order-status-badge ${getBadgeClass(selectedOrder.status)}`}>
                  {selectedOrder.status}
                </span>
              </div>
              <button
                className="order-modal-close-btn"
                onClick={() => setSelectedOrder(null)}
                aria-label="Close modal"
              >
                &times;
              </button>
            </div>

            {/* Modal Body */}
            <div className="order-modal-body">
              {modalLoading ? (
                <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                  Loading order details...
                </div>
              ) : (
                <>
                  {/* Fulfillment Stepper */}
                  <div className="order-stepper">
                    <div className="stepper-line" />
                    {selectedOrder.status === 'Cancelled' ? (
                      <div className="stepper-step cancelled">
                        <div className="stepper-circle">&times;</div>
                        <span className="stepper-label">Order Cancelled</span>
                      </div>
                    ) : (
                      ['Paid', 'Processing', 'Shipped', 'Delivered'].map((stepName, idx) => {
                        const currentStep = getStepIndex(selectedOrder.status);
                        const isCompleted = currentStep > idx + 1;
                        const isActive = currentStep === idx + 1;

                        return (
                          <div
                            key={stepName}
                            className={`stepper-step ${isActive ? 'active' : ''} ${
                              isCompleted ? 'completed' : ''
                            }`}
                          >
                            <div className="stepper-circle">
                              {isCompleted ? '✓' : idx + 1}
                            </div>
                            <span className="stepper-label">{stepName}</span>
                          </div>
                        );
                      })
                    )}
                  </div>

                  {/* Customer & Order Information Grid */}
                  <div className="modal-info-grid">
                    <div className="modal-info-card">
                      <div className="modal-card-title">Customer Details</div>
                      <div className="modal-info-row">
                        <span className="info-label">Name</span>
                        <span className="info-val">{selectedOrder.customerName || 'Customer'}</span>
                      </div>
                      <div className="modal-info-row">
                        <span className="info-label">Email</span>
                        <span className="info-val">{selectedOrder.customerEmail || 'N/A'}</span>
                      </div>
                      <div className="modal-info-row">
                        <span className="info-label">Shipping Address</span>
                        <span className="info-val" style={{ maxWidth: '240px' }}>
                          {selectedOrder.shippingAddress}
                        </span>
                      </div>
                    </div>

                    <div className="modal-info-card">
                      <div className="modal-card-title">Order Information</div>
                      <div className="modal-info-row">
                        <span className="info-label">Placed On</span>
                        <span className="info-val">{orderService.formatDateTime(selectedOrder.createdAt)}</span>
                      </div>
                      <div className="modal-info-row">
                        <span className="info-label">Payment Method</span>
                        <span className="info-val">{selectedOrder.paymentMethod || 'Credit Card'}</span>
                      </div>
                      <div className="modal-info-row">
                        <span className="info-label">Total Amount</span>
                        <span className="info-val" style={{ color: 'var(--primary)', fontSize: '1rem' }}>
                          {orderService.formatCurrency(selectedOrder.totalAmount)}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Itemized Hardware List */}
                  <div>
                    <h4 style={{ margin: '0 0 0.75rem 0', fontSize: '0.95rem', fontWeight: 700 }}>
                      Ordered Components ({selectedOrder.items?.length || 0})
                    </h4>
                    <div style={{ border: '1px solid var(--border)', borderRadius: 'var(--radius-md)', overflow: 'hidden' }}>
                      <table className="order-items-table">
                        <thead>
                          <tr>
                            <th>Product</th>
                            <th>Unit Price (LKR)</th>
                            <th>Quantity</th>
                            <th style={{ textAlign: 'right' }}>Subtotal (LKR)</th>
                          </tr>
                        </thead>
                        <tbody>
                          {selectedOrder.items && selectedOrder.items.length > 0 ? (
                            selectedOrder.items.map((item) => (
                              <tr key={item.orderItemId || item.productId}>
                                <td>
                                  <div className="item-product-cell">
                                    {item.imageUrl ? (
                                      <img
                                        src={item.imageUrl}
                                        alt={item.productName}
                                        className="item-thumb"
                                        onError={(e) => {
                                          e.target.style.display = 'none';
                                        }}
                                      />
                                    ) : (
                                      <div className="item-thumb-placeholder">PC</div>
                                    )}
                                    <div>
                                      <div className="item-name">{item.productName}</div>
                                      <div className="item-brand-model">
                                        {item.brand} {item.model ? `• ${item.model}` : ''}
                                      </div>
                                    </div>
                                  </div>
                                </td>
                                <td>{orderService.formatCurrency(item.unitPrice)}</td>
                                <td style={{ fontWeight: 600 }}>&times; {item.quantity}</td>
                                <td style={{ textAlign: 'right', fontWeight: 700, color: 'var(--text-main)' }}>
                                  {orderService.formatCurrency(item.subtotal || item.unitPrice * item.quantity)}
                                </td>
                              </tr>
                            ))
                          ) : (
                            <tr>
                              <td colSpan="4" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '1.5rem' }}>
                                No item details available.
                              </td>
                            </tr>
                          )}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </>
              )}
            </div>

            {/* Modal Footer */}
            <div className="order-modal-footer">
              <button
                className="btn-secondary"
                onClick={() => window.print()}
                title="Print Packing Slip / Invoice"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <polyline points="6 9 6 2 18 2 18 9" />
                  <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                  <rect x="6" y="14" width="12" height="8" />
                </svg>
                Print Slip
              </button>

              <div className="status-change-group">
                <label style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>
                  Change Status:
                </label>
                <select
                  className="status-select"
                  value={newStatus}
                  onChange={(e) => setNewStatus(e.target.value)}
                  disabled={statusUpdating}
                >
                  <option value="Pending">Pending</option>
                  <option value="Paid">Paid</option>
                  <option value="Processing">Processing</option>
                  <option value="Shipped">Shipped</option>
                  <option value="Delivered">Delivered</option>
                  <option value="Cancelled">Cancelled</option>
                </select>

                <button
                  className="btn-primary"
                  onClick={handleUpdateStatus}
                  disabled={statusUpdating || newStatus === selectedOrder.status}
                >
                  {statusUpdating ? 'Updating...' : 'Update Status'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default OrderManagement;
