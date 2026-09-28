import React from 'react';
import { CloseIcon } from '../icons/index.js';

export const InventoryToolbar = ({
  searchQuery,
  onSearchChange,
  onClearSearch,
  stockFilter,
  onStockFilterChange,
  selectedCategory,
  onCategoryChange,
  categories,
  filteredCount,
  totalCount,
}) => {
  return (
    <div className="inventory-toolbar-card">
      <div className="toolbar-search-wrapper">
        <svg className="toolbar-search-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="11" cy="11" r="8"></circle>
          <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
        </svg>
        <input
          id="inventory-search-input"
          type="text"
          className="toolbar-search-input"
          placeholder="Search components by name, brand, or model..."
          value={searchQuery}
          onChange={(e) => onSearchChange(e.target.value)}
        />
        {searchQuery && (
          <button
            type="button"
            className="toolbar-clear-btn"
            onClick={onClearSearch}
            title="Clear search"
          >
            <CloseIcon size={14} />
          </button>
        )}
      </div>

      <div className="toolbar-filters-group">
        {/* Status Select */}
        <div className="toolbar-select-item">
          <label className="toolbar-select-label" htmlFor="inv-status-filter">Status</label>
          <div className="select-with-chevron">
            <select
              id="inv-status-filter"
              className="toolbar-select"
              value={stockFilter}
              onChange={(e) => onStockFilterChange(e.target.value)}
            >
              <option value="all">All Statuses</option>
              <option value="instock">In Stock</option>
              <option value="lowstock">Low Stock</option>
              <option value="outofstock">Out of Stock</option>
            </select>
            <svg className="select-chevron-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="6 9 12 15 18 9"></polyline>
            </svg>
          </div>
        </div>

        {/* Category Select */}
        <div className="toolbar-select-item">
          <label className="toolbar-select-label" htmlFor="inv-cat-filter">Category</label>
          <div className="select-with-chevron">
            <select
              id="inv-cat-filter"
              className="toolbar-select"
              value={selectedCategory}
              onChange={(e) => onCategoryChange(e.target.value)}
            >
              <option value="all">All Categories</option>
              {categories.map((cat) => (
                <option key={cat.categoryId || cat.id} value={cat.categoryId || cat.id}>
                  {cat.name}
                </option>
              ))}
            </select>
            <svg className="select-chevron-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="6 9 12 15 18 9"></polyline>
            </svg>
          </div>
        </div>

        {/* Item Counter */}
        <div className="toolbar-count-badge">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#64748b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="8" y1="6" x2="21" y2="6"></line>
            <line x1="8" y1="12" x2="21" y2="12"></line>
            <line x1="8" y1="18" x2="21" y2="18"></line>
            <line x1="3" y1="6" x2="3.01" y2="6"></line>
            <line x1="3" y1="12" x2="3.01" y2="12"></line>
            <line x1="3" y1="18" x2="3.01" y2="18"></line>
          </svg>
          <span>Showing <strong>{filteredCount}</strong> of {totalCount} components</span>
        </div>
      </div>
    </div>
  );
};

export default InventoryToolbar;
