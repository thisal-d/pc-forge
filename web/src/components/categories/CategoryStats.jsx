import React from 'react';

export const CategoryStats = ({ stats }) => {
  return (
    <div className="stats-grid">
      <div className="stat-card stat-card-total">
        <span className="stat-label">Total Categories</span>
        <span className="stat-value">{stats.total}</span>
        <span className="stat-subtext">Component categories configured</span>
      </div>

      <div className="stat-card stat-card-active">
        <span className="stat-label">Active Categories</span>
        <span className="stat-value" style={{ color: '#34d399' }}>{stats.active}</span>
        <span className="stat-subtext">Visible on store frontend</span>
      </div>

      <div className="stat-card stat-card-inactive">
        <span className="stat-label">Inactive</span>
        <span className="stat-value" style={{ color: stats.inactive > 0 ? '#fbbf24' : '#94a3b8' }}>
          {stats.inactive}
        </span>
        <span className="stat-subtext">Hidden from customer catalog</span>
      </div>

      <div className="stat-card stat-card-tech">
        <span className="stat-label">Configured Filters</span>
        <span className="stat-value" style={{ color: '#818cf8' }}>{stats.totalFilters}</span>
        <span className="stat-subtext">Across all categories</span>
      </div>
    </div>
  );
};

export default CategoryStats;
