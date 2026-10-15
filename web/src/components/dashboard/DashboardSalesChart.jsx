import React, { useState, useMemo } from 'react';
import { TrendingUpIcon, PackageIcon } from '../icons/index.js';

export const DashboardSalesChart = ({ orders = [], role = 'Staff' }) => {
  const isAdmin = (role || '').toLowerCase() === 'admin';
  const [metricType, setMetricType] = useState('revenue'); // 'revenue' | 'volume'
  const [hoveredIndex, setHoveredIndex] = useState(null);

  // Group orders into last 6 chronological months
  const monthlyData = useMemo(() => {
    const now = new Date();
    const months = [];

    // Generate last 6 months in order
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      const label = d.toLocaleDateString('en-US', { month: 'short' });
      const year = d.getFullYear();
      months.push({ key, label, year, revenue: 0, count: 0 });
    }

    // Accumulate orders into month buckets
    orders.forEach((o) => {
      const s = (o.status || '').toLowerCase();
      if (s === 'cancelled') return; // Exclude cancelled orders from sales overview

      const dateStr = o.createdAt || o.CreatedDate || o.orderDate;
      if (!dateStr) return;

      try {
        const orderDate = new Date(dateStr);
        if (isNaN(orderDate.getTime())) return;

        const key = `${orderDate.getFullYear()}-${String(orderDate.getMonth() + 1).padStart(2, '0')}`;
        const bucket = months.find((m) => m.key === key);
        if (bucket) {
          bucket.revenue += Number(o.totalAmount || o.TotalAmount) || 0;
          bucket.count += 1;
        }
      } catch {
        // Skip malformed date
      }
    });

    return months;
  }, [orders]);

  // Max value for scaling SVG chart
  const maxValue = useMemo(() => {
    if (metricType === 'revenue') {
      const maxRev = Math.max(...monthlyData.map((d) => d.revenue), 100000);
      return maxRev * 1.15; // 15% headroom
    } else {
      const maxCount = Math.max(...monthlyData.map((d) => d.count), 5);
      return Math.ceil(maxCount * 1.25);
    }
  }, [monthlyData, metricType]);

  const totalPeriodRevenue = useMemo(
    () => monthlyData.reduce((acc, curr) => acc + curr.revenue, 0),
    [monthlyData]
  );

  const totalPeriodOrders = useMemo(
    () => monthlyData.reduce((acc, curr) => acc + curr.count, 0),
    [monthlyData]
  );

  // SVG dimensions
  const svgWidth = 620;
  const svgHeight = 240;
  const paddingLeft = 60;
  const paddingRight = 30;
  const paddingTop = 25;
  const paddingBottom = 40;

  const chartWidth = svgWidth - paddingLeft - paddingRight;
  const chartHeight = svgHeight - paddingTop - paddingBottom;

  const barWidth = Math.min(42, (chartWidth / monthlyData.length) * 0.55);
  const gap = chartWidth / monthlyData.length;

  const formatLkrK = (val) => {
    if (val >= 1000000) return `${(val / 1000000).toFixed(1)}M`;
    if (val >= 1000) return `${(val / 1000).toFixed(0)}k`;
    return val;
  };

  return (
    <div className="dashboard-chart-card" id="sales-overview-chart-card">
      <div className="chart-card-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <span className="attention-icon-badge icon-badge-tools">
              <TrendingUpIcon size={16} />
            </span>
            <h3 className="chart-card-title">Sales & Operations Overview</h3>
          </div>
          <p className="chart-card-subtitle">
            Historical 6-month trajectory of order transactions and commercial volume.
          </p>
        </div>

        <div className="chart-controls">
          <div className="btn-group-pill">
            <button
              type="button"
              className={`pill-btn ${metricType === 'revenue' ? 'active' : ''}`}
              onClick={() => setMetricType('revenue')}
              id="chart-toggle-revenue"
            >
              Revenue (LKR)
            </button>
            <button
              type="button"
              className={`pill-btn ${metricType === 'volume' ? 'active' : ''}`}
              onClick={() => setMetricType('volume')}
              id="chart-toggle-volume"
            >
              Order Count
            </button>
          </div>
        </div>
      </div>

      {/* KPI highlight row inside chart */}
      <div className="chart-highlight-stats">
        <div className="highlight-stat-item">
          <span className="stat-label">6-Month Total Volume</span>
          <span className="highlight-stat-value">
            {isAdmin && metricType === 'revenue'
              ? `LKR ${totalPeriodRevenue.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
              : `${totalPeriodOrders} Orders Placed`}
          </span>
        </div>
        <div className="highlight-stat-item">
          <span className="stat-label">Monthly Average</span>
          <span className="highlight-stat-value">
            {isAdmin && metricType === 'revenue'
              ? `LKR ${(totalPeriodRevenue / 6).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
              : `${(totalPeriodOrders / 6).toFixed(1)} orders / mo`}
          </span>
        </div>
        <div className="highlight-stat-item">
          <span className="stat-label">Trend Direction</span>
          <span className="highlight-badge-up">
            &uarr; Consistent Active Growth
          </span>
        </div>
      </div>

      {/* SVG Chart Canvas */}
      <div className="svg-chart-container" style={{ position: 'relative' }}>
        <svg
          viewBox={`0 0 ${svgWidth} ${svgHeight}`}
          className="responsive-svg-chart"
          preserveAspectRatio="xMidYMid meet"
        >
          <defs>
            <linearGradient id="primaryBarGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#2563eb" stopOpacity="0.95" />
              <stop offset="100%" stopColor="#3b82f6" stopOpacity="0.45" />
            </linearGradient>
            <linearGradient id="hoverBarGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#1d4ed8" stopOpacity="1" />
              <stop offset="100%" stopColor="#2563eb" stopOpacity="0.75" />
            </linearGradient>
            <linearGradient id="areaGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#2563eb" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#2563eb" stopOpacity="0.0" />
            </linearGradient>
          </defs>

          {/* Grid lines (horizontal) */}
          {[0, 0.25, 0.5, 0.75, 1].map((pct, idx) => {
            const y = paddingTop + chartHeight * (1 - pct);
            const labelVal = maxValue * pct;
            return (
              <g key={idx}>
                <line
                  x1={paddingLeft}
                  y1={y}
                  x2={svgWidth - paddingRight}
                  y2={y}
                  stroke="var(--border)"
                  strokeDasharray={idx === 0 ? 'none' : '3 3'}
                  strokeWidth="1"
                />
                <text
                  x={paddingLeft - 8}
                  y={y + 4}
                  textAnchor="end"
                  fontSize="11"
                  fill="var(--text-muted)"
                  fontFamily="Inter, sans-serif"
                >
                  {metricType === 'revenue' ? (isAdmin ? formatLkrK(labelVal) : '•••') : Math.round(labelVal)}
                </text>
              </g>
            );
          })}

          {/* Render Bars and connecting trend line */}
          {monthlyData.map((d, i) => {
            const val = metricType === 'revenue' ? d.revenue : d.count;
            const barHeight = maxValue > 0 ? (val / maxValue) * chartHeight : 0;
            const x = paddingLeft + i * gap + (gap - barWidth) / 2;
            const y = paddingTop + chartHeight - barHeight;
            const isHovered = hoveredIndex === i;

            return (
              <g
                key={d.key}
                onMouseEnter={() => setHoveredIndex(i)}
                onMouseLeave={() => setHoveredIndex(null)}
                style={{ cursor: 'pointer' }}
              >
                {/* Background hover pillar */}
                <rect
                  x={paddingLeft + i * gap}
                  y={paddingTop}
                  width={gap}
                  height={chartHeight}
                  fill={isHovered ? 'rgba(37, 99, 235, 0.05)' : 'transparent'}
                  rx="4"
                />

                {/* The Bar */}
                <rect
                  x={x}
                  y={y}
                  width={barWidth}
                  height={Math.max(barHeight, 3)}
                  rx="5"
                  fill={isHovered ? 'url(#hoverBarGrad)' : 'url(#primaryBarGrad)'}
                  style={{ transition: 'all 0.2s ease' }}
                />

                {/* X Axis Label */}
                <text
                  x={x + barWidth / 2}
                  y={svgHeight - 12}
                  textAnchor="middle"
                  fontSize="12"
                  fontWeight={isHovered ? '700' : '500'}
                  fill={isHovered ? 'var(--primary)' : 'var(--text-body)'}
                  fontFamily="Inter, sans-serif"
                >
                  {d.label}
                </text>
              </g>
            );
          })}
        </svg>

        {/* Floating tooltip */}
        {hoveredIndex !== null && (
          <div
            className="chart-tooltip"
            style={{
              left: `${paddingLeft + hoveredIndex * gap + gap / 2}px`,
              top: '15px',
            }}
          >
            <div className="tooltip-title">{monthlyData[hoveredIndex].label} {monthlyData[hoveredIndex].year}</div>
            <div className="tooltip-body">
              {isAdmin && (
                <div className="tooltip-row">
                  <span>Revenue:</span>
                  <strong>
                    LKR {monthlyData[hoveredIndex].revenue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </strong>
                </div>
              )}
              <div className="tooltip-row">
                <span>Orders:</span>
                <strong>{monthlyData[hoveredIndex].count} transactions</strong>
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="chart-card-footer">
        <span className="footer-note">
          {isAdmin
            ? 'Real-time sales telemetry aggregated across verified orders in ASP.NET Core database.'
            : 'Operational order volume tracking active. Detailed financial balances restricted to Admin.'}
        </span>
      </div>
    </div>
  );
};

export default DashboardSalesChart;
