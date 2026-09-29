import React from 'react';
import { STATUS_OPTIONS, PRIORITY_OPTIONS, ISSUE_TYPES } from '../../constants/ticketConstants.js';
import { SearchIcon, CloseIcon, RefreshCwIcon } from '../icons/index.js';

export const SupportToolbar = ({
  searchQuery,
  onSearchChange,
  onClearSearch,
  statusFilter,
  onStatusFilterChange,
  priorityFilter,
  onPriorityFilterChange,
  issueTypeFilter,
  onIssueTypeFilterChange,
  technicianFilter,
  onTechnicianFilterChange,
  technicians,
  onClearFilters,
  onRefresh,
}) => {
  const isFiltered =
    searchQuery ||
    statusFilter !== 'all' ||
    priorityFilter !== 'all' ||
    issueTypeFilter !== 'all' ||
    technicianFilter !== 'all';

  return (
    <div className="toolbar-card" style={{ marginBottom: '1.25rem' }}>
      <div className="search-filter-row">
        {/* Search Input */}
        <div className="search-input-wrapper">
          <span className="search-icon">
            <SearchIcon size={16} />
          </span>
          <input
            id="ticket-search-input"
            type="text"
            placeholder="Search by Ticket ID (#505), customer, email, order (#1001), or product..."
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
          {/* Status Filter */}
          <div className="filter-item">
            <label htmlFor="ticket-status-filter">Status:</label>
            <select
              id="ticket-status-filter"
              value={statusFilter}
              onChange={(e) => onStatusFilterChange(e.target.value)}
            >
              <option value="all">All Statuses</option>
              {STATUS_OPTIONS.map((opt) => (
                <option key={opt} value={opt}>
                  {opt}
                </option>
              ))}
            </select>
          </div>

          {/* Priority Filter */}
          <div className="filter-item">
            <label htmlFor="ticket-priority-filter">Priority:</label>
            <select
              id="ticket-priority-filter"
              value={priorityFilter}
              onChange={(e) => onPriorityFilterChange(e.target.value)}
            >
              <option value="all">All Priorities</option>
              {PRIORITY_OPTIONS.map((opt) => (
                <option key={opt} value={opt}>
                  {opt}
                </option>
              ))}
            </select>
          </div>

          {/* Issue Type Filter */}
          <div className="filter-item">
            <label htmlFor="ticket-type-filter">Issue Type:</label>
            <select
              id="ticket-type-filter"
              value={issueTypeFilter}
              onChange={(e) => onIssueTypeFilterChange(e.target.value)}
            >
              <option value="all">All Categories</option>
              {ISSUE_TYPES.map((type) => (
                <option key={type} value={type}>
                  {type}
                </option>
              ))}
            </select>
          </div>

          {/* Technician Filter */}
          <div className="filter-item">
            <label htmlFor="ticket-tech-filter">Technician:</label>
            <select
              id="ticket-tech-filter"
              value={technicianFilter}
              onChange={(e) => onTechnicianFilterChange(e.target.value)}
            >
              <option value="all">All Technicians</option>
              <option value="unassigned">Unassigned</option>
              {technicians.map((t) => (
                <option key={t.id || t.staffId} value={t.staffId || t.userId || t.id}>
                  {t.firstName} {t.lastName}
                </option>
              ))}
            </select>
          </div>

          {/* Reset Button */}
          {isFiltered && (
            <button
              type="button"
              onClick={onClearFilters}
              className="btn btn-outline-sm"
              style={{ alignSelf: 'flex-end', height: '38px' }}
            >
              Clear Filters
            </button>
          )}

          <button
            type="button"
            onClick={onRefresh}
            className="btn btn-outline-sm"
            style={{ alignSelf: 'flex-end', height: '38px', display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
            title="Refresh tickets from live database"
          >
            <RefreshCwIcon size={14} /> Refresh
          </button>
        </div>
      </div>
    </div>
  );
};

export default SupportToolbar;
