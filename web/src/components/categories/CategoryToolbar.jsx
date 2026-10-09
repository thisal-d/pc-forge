import React from 'react';
import { SearchIcon, CloseIcon, RefreshCwIcon } from '../icons/index.js';

export const CategoryToolbar = ({
  searchQuery,
  onSearchChange,
  onClearSearch,
  statusFilter,
  onStatusFilterChange,
  onResetFilters,
  onRefresh,
}) => {
  const isFiltered = searchQuery || statusFilter !== 'all';

  return (
    <div className="toolbar-card">
      <div className="search-filter-row">
        {/* Search Box */}
        <div className="search-input-wrapper">
          <span className="search-icon">
            <SearchIcon size={16} />
          </span>
          <input
            id="category-search-input"
            type="text"
            placeholder="Search categories by name or description..."
            value={searchQuery}
            onChange={onSearchChange}
          />
          {searchQuery && (
            <button
              type="button"
              className="clear-search-btn"
              onClick={onClearSearch}
              title="Clear Search"
            >
              <CloseIcon size={14} />
            </button>
          )}
        </div>

        {/* Status Dropdown */}
        <div className="filter-dropdowns">
          <div className="filter-item">
            <label htmlFor="category-status-filter">Status:</label>
            <select
              id="category-status-filter"
              value={statusFilter}
              onChange={(e) => onStatusFilterChange(e.target.value)}
            >
              <option value="all">All Statuses</option>
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
            </select>
          </div>

          {isFiltered && (
            <button
              type="button"
              onClick={onResetFilters}
              className="btn btn-outline-sm"
            >
              Reset Filters
            </button>
          )}

          {onRefresh && (
            <button
              type="button"
              onClick={onRefresh}
              className="btn btn-outline-sm"
              title="Refresh Categories"
              style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
            >
              <RefreshCwIcon size={14} /> Refresh
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default CategoryToolbar;
