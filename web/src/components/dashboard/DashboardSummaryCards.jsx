import React from 'react';
import { PackageIcon, WrenchIcon, ToolsIcon, TrendingUpIcon, ClockIcon } from '../icons/index.js';

export const DashboardSummaryCards = ({
  stats = {},
  role = 'Staff',
  onCardClick,
  activeFilter = null,
}) => {
  const isAdmin = (role || '').toLowerCase() === 'admin';

  const cards = [
    {
      id: 'total-orders',
      label: 'Total Orders',
      value: stats.totalOrders?.toLocaleString() ?? '0',
      subtext: `${stats.completedOrders ?? 0} fulfilled / completed`,
      icon: <PackageIcon size={22} />,
      colorClass: 'icon-circle-blue',
      borderClass: 'stat-card-total',
      badge: 'All Time',
      badgeClass: 'badge-info',
      trend: '+12% vs last month',
      trendUp: true,
    },
    {
      id: 'pending-orders',
      label: 'Pending Orders',
      value: stats.pendingOrders?.toLocaleString() ?? '0',
      subtext: 'Requires picking & fulfillment',
      icon: <ClockIcon size={22} />,
      colorClass: 'icon-circle-amber',
      borderClass: 'stat-card-inactive',
      badge: stats.pendingOrders > 0 ? 'Action Needed' : 'All Clear',
      badgeClass: stats.pendingOrders > 0 ? 'badge-warning' : 'badge-success',
      trend: stats.pendingOrders > 0 ? 'Awaiting dispatch' : 'No backlog',
    },
    {
      id: 'total-revenue',
      label: 'Total Revenue',
      value: isAdmin
        ? `LKR ${Number(stats.totalRevenue || 0).toLocaleString('en-US', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2,
          })}`
        : 'LKR ••••••••',
      subtext: isAdmin
        ? 'From verified orders'
        : 'Restricted to Administrators',
      icon: <TrendingUpIcon size={22} />,
      colorClass: 'icon-circle-green',
      borderClass: 'stat-card-active',
      badge: isAdmin ? 'Net Sales' : 'Confidential',
      badgeClass: isAdmin ? 'badge-success' : 'badge-neutral',
      trend: isAdmin ? '+18.4% growth' : 'Admin only',
      trendUp: isAdmin,
    },
    {
      id: 'pending-services',
      label: 'Service Requests Awaiting Action',
      value: stats.pendingServices?.toLocaleString() ?? '0',
      subtext: `${stats.totalServices ?? 0} total requests logged`,
      icon: <WrenchIcon size={22} />,
      colorClass: 'icon-circle-purple',
      borderClass: 'stat-card-tech',
      badge: stats.pendingServices > 0 ? 'Technician Queue' : 'Up to date',
      badgeClass: stats.pendingServices > 0 ? 'badge-warning' : 'badge-success',
      trend: stats.pendingServices > 0 ? 'Requires diagnosis' : 'Queue clear',
    },
    {
      id: 'pending-builds',
      label: 'Pending Custom Builds',
      value: stats.pendingBuilds?.toLocaleString() ?? '0',
      subtext: `${stats.totalBuilds ?? 0} custom builds submitted`,
      icon: <ToolsIcon size={22} />,
      colorClass: 'icon-circle-blue',
      borderClass: 'stat-card-total',
      badge: stats.pendingBuilds > 0 ? 'Review Needed' : 'Cleared',
      badgeClass: stats.pendingBuilds > 0 ? 'badge-error' : 'badge-success',
      trend: stats.pendingBuilds > 0 ? 'Compatibility check' : 'All reviewed',
    },
  ];

  return (
    <div className="dashboard-summary-grid" id="dashboard-summary-cards">
      {cards.map((card) => {
        const isSelected = activeFilter === card.id;
        return (
          <div
            key={card.id}
            id={`kpi-card-${card.id}`}
            className={`metric-card ${card.borderClass} ${isSelected ? 'card-active-ring' : ''}`}
            onClick={() => onCardClick && onCardClick(card.id)}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                onCardClick && onCardClick(card.id);
              }
            }}
          >
            <div className="metric-card-top">
              <div className={`metric-icon-circle ${card.colorClass}`}>
                {card.icon}
              </div>
              <div className="metric-details">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span className="metric-label">{card.label}</span>
                  <span className={`badge ${card.badgeClass}`} style={{ fontSize: '0.7rem' }}>
                    {card.badge}
                  </span>
                </div>
                <span className="metric-value">{card.value}</span>
                <span className="metric-subtext">{card.subtext}</span>
              </div>
            </div>
            <div className="metric-trend" style={{ color: card.trendUp ? 'var(--success-text)' : 'var(--text-muted)' }}>
              <span>{card.trend}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export default DashboardSummaryCards;
