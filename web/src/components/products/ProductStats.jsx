import React from 'react';

export const ProductStats = ({ stats }) => {
  return (
    <div className="stats-grid">
      <div className="stat-card stat-card-total">
        <span className="stat-label">Total Products</span>
        <span className="stat-value">{stats.total}</span>
        <span className="stat-subtext">Components in catalog</span>
      </div>
      <div className="stat-card stat-card-active">
        <span className="stat-label">Active Catalog</span>
        <span className="stat-value" style={{ color: '#34d399' }}>{stats.active}</span>
        <span className="stat-subtext">Available for purchase</span>
      </div>
      <div className="stat-card stat-card-inactive">
        <span className="stat-label">Stock Alerts</span>
        <span className="stat-value" style={{ color: stats.lowStock + stats.outOfStock > 0 ? '#fbbf24' : '#34d399' }}>
          {stats.lowStock + stats.outOfStock}
        </span>
        <span className="stat-subtext">{stats.lowStock} low / {stats.outOfStock} depleted</span>
      </div>
      <div className="stat-card stat-card-tech">
        <span className="stat-label">Inventory Valuation</span>
        <span className="stat-value" style={{ color: '#818cf8', fontSize: '1.65rem' }}>
          LKR {stats.totalInventoryValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </span>
        <span className="stat-subtext">Total on-hand retail value</span>
      </div>
    </div>
  );
};

export default ProductStats;
