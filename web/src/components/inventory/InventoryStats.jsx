import React from 'react';

export const InventoryStats = ({ stats, stockFilter, onSelectFilter }) => {
  return (
    <div className="metric-cards-grid">
      {/* Card 1: Total Components */}
      <div
        className={`metric-card ${stockFilter === 'all' ? 'card-active-ring' : ''}`}
        onClick={() => onSelectFilter('all')}
        role="button"
        tabIndex={0}
      >
        <div className="metric-card-top">
          <div className="metric-icon-circle icon-circle-blue">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2563eb" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
            </svg>
          </div>
          <div className="metric-details">
            <span className="metric-label">Total Components</span>
            <span className="metric-value">{stats.totalItems}</span>
            <span className="metric-subtext">Active catalog items</span>
          </div>
        </div>
      </div>

      {/* Card 2: In Stock */}
      <div
        className={`metric-card ${stockFilter === 'instock' ? 'card-active-ring' : ''}`}
        onClick={() => onSelectFilter('instock')}
        role="button"
        tabIndex={0}
      >
        <div className="metric-card-top">
          <div className="metric-icon-circle icon-circle-green">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#059669" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path>
              <polyline points="9 22 9 12 15 12 15 22"></polyline>
            </svg>
          </div>
          <div className="metric-details">
            <span className="metric-label">In Stock</span>
            <span className="metric-value">{stats.inStock}</span>
            <span className="metric-subtext">Healthy operational inventory</span>
          </div>
        </div>
      </div>

      {/* Card 3: Low Stock */}
      <div
        className={`metric-card ${stockFilter === 'lowstock' ? 'card-active-ring' : ''}`}
        onClick={() => onSelectFilter('lowstock')}
        role="button"
        tabIndex={0}
      >
        <div className="metric-card-top">
          <div className="metric-icon-circle icon-circle-amber">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#d97706" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"></path>
              <line x1="12" y1="9" x2="12" y2="13"></line>
              <line x1="12" y1="17" x2="12.01" y2="17"></line>
            </svg>
          </div>
          <div className="metric-details">
            <span className="metric-label">Low Stock</span>
            <span className="metric-value">{stats.lowStock}</span>
            <span className="metric-subtext">Items need restock soon</span>
          </div>
        </div>
      </div>

      {/* Card 4: Out of Stock */}
      <div
        className={`metric-card ${stockFilter === 'outofstock' ? 'card-active-ring' : ''}`}
        onClick={() => onSelectFilter('outofstock')}
        role="button"
        tabIndex={0}
      >
        <div className="metric-card-top">
          <div className="metric-icon-circle icon-circle-red">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#dc2626" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10" />
              <line x1="4.93" y1="4.93" x2="19.07" y2="19.07"></line>
            </svg>
          </div>
          <div className="metric-details">
            <span className="metric-label">Out of Stock</span>
            <span className="metric-value">{stats.outOfStock}</span>
            <span className="metric-subtext">Currently not available</span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default InventoryStats;
