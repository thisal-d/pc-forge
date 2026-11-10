import React, { useMemo } from 'react';
import { PackageIcon } from '../icons/index.js';

export const DashboardStatusChart = ({ orders = [] }) => {
  const statusStats = useMemo(() => {
    const total = orders.length;
    const counts = {
      placed: 0,
      processing: 0,
      ready: 0,
      outForDelivery: 0,
      completed: 0,
      cancelled: 0,
    };

    orders.forEach((o) => {
      const s = (o.status || '').toLowerCase().trim();
      if (s === 'order placed') counts.placed++;
      else if (s === 'processing') counts.processing++;
      else if (s === 'ready for delivery' || s === 'ready for pickup') counts.ready++;
      else if (s === 'out for delivery') counts.outForDelivery++;
      else if (s === 'paid & completed' || s === 'paid and completed') counts.completed++;
      else if (s === 'cancelled') counts.cancelled++;
      else counts.placed++; // default fallback
    });

    const segments = [
      {
        key: 'placed',
        label: 'Order Placed',
        count: counts.placed,
        color: '#f59e0b', // warning / amber
        pct: total > 0 ? (counts.placed / total) * 100 : 0,
      },
      {
        key: 'processing',
        label: 'Processing',
        count: counts.processing,
        color: '#3b82f6', // blue / info
        pct: total > 0 ? (counts.processing / total) * 100 : 0,
      },
      {
        key: 'ready',
        label: 'Ready for Dispatch / Pickup',
        count: counts.ready,
        color: '#8b5cf6', // purple
        pct: total > 0 ? (counts.ready / total) * 100 : 0,
      },
      {
        key: 'outForDelivery',
        label: 'Out for Delivery',
        count: counts.outForDelivery,
        color: '#06b6d4', // cyan
        pct: total > 0 ? (counts.outForDelivery / total) * 100 : 0,
      },
      {
        key: 'completed',
        label: 'Paid & Completed',
        count: counts.completed,
        color: '#10b981', // emerald green / success
        pct: total > 0 ? (counts.completed / total) * 100 : 0,
      },
      {
        key: 'cancelled',
        label: 'Cancelled',
        count: counts.cancelled,
        color: '#ef4444', // red / danger
        pct: total > 0 ? (counts.cancelled / total) * 100 : 0,
      },
    ];

    return { total, segments };
  }, [orders]);

  // SVG Donut calculation
  const radius = 64;
  const strokeWidth = 18;
  const circumference = 2 * Math.PI * radius;

  // Compute stroke offsets for each segment
  let accumulatedPercent = 0;
  const donutSegments = statusStats.segments.map((seg) => {
    const strokeDasharray = `${(seg.pct / 100) * circumference} ${circumference}`;
    const strokeDashoffset = -((accumulatedPercent / 100) * circumference);
    accumulatedPercent += seg.pct;
    return {
      ...seg,
      strokeDasharray,
      strokeDashoffset,
    };
  });

  return (
    <div className="dashboard-chart-card" id="order-status-breakdown-card">
      <div className="chart-card-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <span className="attention-icon-badge icon-badge-package">
              <PackageIcon size={16} />
            </span>
            <h3 className="chart-card-title">Order Status Breakdown</h3>
          </div>
          <p className="chart-card-subtitle">
            Pipeline distribution across placement, processing, fulfillment, and completion.
          </p>
        </div>
        <span className="badge badge-info" style={{ fontSize: '0.75rem' }}>
          {statusStats.total} Total
        </span>
      </div>

      <div className="status-chart-body">
        {/* SVG Donut */}
        <div className="donut-chart-container">
          <svg viewBox="0 0 180 180" className="donut-svg">
            {/* Background empty track */}
            <circle
              cx="90"
              cy="90"
              r={radius}
              fill="transparent"
              stroke="var(--border)"
              strokeWidth={strokeWidth}
            />

            {/* Render Donut Segments */}
            {statusStats.total > 0 &&
              donutSegments.map((seg) => {
                if (seg.count === 0) return null;
                return (
                  <circle
                    key={seg.key}
                    cx="90"
                    cy="90"
                    r={radius}
                    fill="transparent"
                    stroke={seg.color}
                    strokeWidth={strokeWidth}
                    strokeDasharray={seg.strokeDasharray}
                    strokeDashoffset={seg.strokeDashoffset}
                    strokeLinecap="round"
                    transform="rotate(-90 90 90)"
                    style={{ transition: 'stroke-dashoffset 0.4s ease, stroke-dasharray 0.4s ease' }}
                  />
                );
              })}

            {/* Center Label */}
            <text x="90" y="84" textAnchor="middle" className="donut-center-count">
              {statusStats.total}
            </text>
            <text x="90" y="104" textAnchor="middle" className="donut-center-label">
              Total Orders
            </text>
          </svg>
        </div>

        {/* Breakdown Progress Bars & Legend */}
        <div className="status-legend-list">
          {statusStats.segments.map((seg) => (
            <div key={seg.key} className="status-legend-item">
              <div className="status-legend-row">
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span
                    className="legend-color-dot"
                    style={{ backgroundColor: seg.color }}
                  />
                  <span className="legend-label">{seg.label}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span className="legend-count">{seg.count}</span>
                  <span className="legend-pct">({seg.pct.toFixed(0)}%)</span>
                </div>
              </div>
              <div className="legend-progress-track">
                <div
                  className="legend-progress-bar"
                  style={{
                    width: `${seg.pct}%`,
                    backgroundColor: seg.color,
                  }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="chart-card-footer">
        <span className="footer-note">
          {statusStats.total > 0
            ? `${(statusStats.segments.find((s) => s.key === 'completed')?.pct || 0).toFixed(1)}% fulfillment completion rate across current order volume.`
            : 'No orders logged in the database.'}
        </span>
      </div>
    </div>
  );
};

export default DashboardStatusChart;
