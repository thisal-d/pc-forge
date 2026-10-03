import React from 'react';

export const SupportStats = ({ stats }) => {
  return (
    <div className="stats-grid">
      <div className="stat-card stat-card-total">
        <span className="stat-label">Open Tickets</span>
        <span className="stat-value">{stats.open}</span>
        <span className="stat-subtext">Awaiting technician review</span>
      </div>

      <div className="stat-card stat-card-active">
        <span className="stat-label">In Review / Testing</span>
        <span className="stat-value">{stats.inReview}</span>
        <span className="stat-subtext">Active diagnostics</span>
      </div>

      <div className="stat-card stat-card-inactive">
        <span className="stat-label">RMA Approved</span>
        <span className="stat-value">{stats.rmaApproved}</span>
        <span className="stat-subtext">Return shipping in progress</span>
      </div>

      <div className="stat-card stat-card-tech">
        <span className="stat-label">Resolved / Closed</span>
        <span className="stat-value">{stats.resolved}</span>
        <span className="stat-subtext">Completed resolutions</span>
      </div>
    </div>
  );
};

export default SupportStats;
