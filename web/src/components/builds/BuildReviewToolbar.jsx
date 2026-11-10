import React from 'react';
import { SearchIcon, CloseIcon } from '../icons/index.js';

export const BuildReviewToolbar = ({
  searchQuery,
  onSearchChange,
  onClearSearch,
  statusFilter,
  onStatusFilterChange,
  metrics,
  onResetFilters,
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
            type="text"
            placeholder="Search by Build #, Name, Customer, Email, or Notes..."
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            id="build-search-input"
          />
          {searchQuery && (
            <button
              type="button"
              className="clear-search-btn"
              onClick={onClearSearch}
              title="Clear search"
            >
              <CloseIcon size={14} />
            </button>
          )}
        </div>

        {/* Status Filter */}
        <div className="filter-item">
          <label htmlFor="filter-status">Status:</label>
          <select
            id="filter-status"
            className="filter-select"
            value={statusFilter}
            onChange={(e) => onStatusFilterChange(e.target.value)}
          >
            <option value="all">All Statuses ({metrics.total})</option>
            <option value="Pending Staff Review">Pending Review ({metrics.pending})</option>
            <option value="In Review by Staff">In Review ({metrics.inReview})</option>
            <option value="Approved by Staff">Approved ({metrics.approved})</option>
            <option value="Changes Requested">Changes Requested ({metrics.changesRequested})</option>
          </select>
        </div>

        {isFiltered && (
          <button
            type="button"
            onClick={onResetFilters}
            className="btn btn-outline-sm"
            id="reset-build-filters-btn"
          >
            Reset Filters
          </button>
        )}
      </div>
    </div>
  );
};

export default BuildReviewToolbar;
