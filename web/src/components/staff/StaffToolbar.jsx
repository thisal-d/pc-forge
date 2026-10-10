import React from 'react';
import { SearchIcon, CloseIcon } from '../icons/index.js';

export const StaffToolbar = ({
  searchQuery,
  onSearchChange,
  onClearSearch,
  statusFilter,
  onStatusFilterChange,
  departmentFilter = 'all',
  onDepartmentFilterChange,
  onResetFilters,
}) => {
  const isFiltered = searchQuery || statusFilter !== 'all' || departmentFilter !== 'all';

  return (
    <div className="toolbar-card">
      <div className="search-filter-row">
        {/* Search by Name, Email, or Phone */}
        <div className="search-input-wrapper">
          <span className="search-icon">
            <SearchIcon size={16} />
          </span>
          <input
            id="staff-search-input"
            type="text"
            placeholder="Search by name, email, phone, or staff ID..."
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
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

        {/* Filter Dropdowns */}
        <div className="filter-dropdowns">
          <div className="filter-item">
            <label htmlFor="staff-dept-filter">Department:</label>
            <select
              id="staff-dept-filter"
              value={departmentFilter}
              onChange={(e) => onDepartmentFilterChange && onDepartmentFilterChange(e.target.value)}
            >
              <option value="all">All Departments</option>
              <option value="Hardware Diagnostics & Repair">Hardware Diagnostics & Repair</option>
              <option value="Assembly & QC">Assembly & QC</option>
              <option value="After-Sales & Warranty">After-Sales & Warranty</option>
              <option value="Custom Rig Architecture">Custom Rig Architecture</option>
              <option value="Inventory & Logistics">Inventory & Logistics</option>
            </select>
          </div>

          <div className="filter-item">
            <label htmlFor="staff-status-filter">Status:</label>
            <select
              id="staff-status-filter"
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
              title="Clear all filters"
            >
              Reset Filters
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default StaffToolbar;
