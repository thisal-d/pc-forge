import React from 'react';

export const BuildReviewStats = ({ metrics }) => {
  return (
    <div className="stats-grid">
      <div className="stat-card stat-card-total">
        <span className="stat-label">Total Submissions</span>
        <span className="stat-value">{metrics.total}</span>
        <span className="stat-subtext">Customer custom build requests</span>
      </div>
      <div className="stat-card stat-card-inactive">
        <span className="stat-label">Pending Staff Review</span>
        <span className="stat-value">{metrics.pending}</span>
        <span className="stat-subtext">Awaiting technician workbench assignment</span>
      </div>
      <div className="stat-card stat-card-tech">
        <span className="stat-label">In Review by Staff</span>
        <span className="stat-value">{metrics.inReview}</span>
        <span className="stat-subtext">Under active bench audit</span>
      </div>
      <div className="stat-card stat-card-active">
        <span className="stat-label">Cleared & Approved</span>
        <span className="stat-value">{metrics.approved}</span>
        <span className="stat-subtext">Cleared for warehouse assembly</span>
      </div>
    </div>
  );
};

export default BuildReviewStats;
