import React from 'react';

export const StaffStats = ({ stats }) => {
  return (
    <div className="stats-grid">
      <div className="stat-card stat-card-total">
        <span className="stat-label">Total Staff</span>
        <span className="stat-value">{stats.total}</span>
        <span className="stat-subtext">Registered technicians</span>
      </div>

      <div className="stat-card stat-card-active">
        <span className="stat-label">Active Technicians</span>
        <span className="stat-value" style={{ color: '#34d399' }}>{stats.active}</span>
        <span className="stat-subtext">Bench active & ready</span>
      </div>

      <div className="stat-card stat-card-inactive">
        <span className="stat-label">Inactive / Suspended</span>
        <span className="stat-value" style={{ color: stats.inactive > 0 ? '#fbbf24' : '#94a3b8' }}>
          {stats.inactive}
        </span>
        <span className="stat-subtext">Access paused</span>
      </div>

      <div className="stat-card stat-card-tech">
        <span className="stat-label">Active Departments</span>
        <span className="stat-value" style={{ color: '#818cf8' }}>{stats.departments}</span>
        <span className="stat-subtext">Specialized units</span>
      </div>
    </div>
  );
};

export default StaffStats;
