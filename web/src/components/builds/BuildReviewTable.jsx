import React from 'react';
import BuildReviewTableRow from './BuildReviewTableRow.jsx';
import { ClipboardListIcon } from '../icons/index.js';
import { Pagination } from '../common/Pagination.jsx';
import { TableSkeleton } from '../common/TableSkeleton.jsx';

export const BuildReviewTable = ({
  builds = [],
  paginatedBuilds = [],
  totalCount = 0,
  loading = false,
  currentPage = 1,
  totalPages = 1,
  pageSize = 10,
  onPageChange,
  onPageSizeChange,
  onResetFilters,
  onInspect,
}) => {
  const displayedItems = paginatedBuilds.length > 0 || builds.length === 0
    ? paginatedBuilds
    : builds.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  return (
    <div className="data-table-card">
      <div className="table-header-banner">
        <h3>Custom Build Reviews ({builds.length})</h3>
        <span className="table-header-subtitle">
          Showing {displayedItems.length} of {totalCount || builds.length} custom configurations
        </span>
      </div>
      <div className="table-responsive">
        <table className="data-table" id="custom-builds-table">
          <thead>
            <tr>
              <th style={{ width: '80px' }}>Build ID</th>
              <th>Build Name & Customer</th>
              <th>Total Cost</th>
              <th>Estimated Power</th>
              <th>Compatibility</th>
              <th>Status</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          {loading ? (
            <TableSkeleton rows={pageSize} columns={7} />
          ) : displayedItems.length === 0 ? (
            <tbody>
              <tr>
                <td colSpan="7" style={{ padding: 0 }}>
                  <div className="empty-state">
                    <div className="empty-state-icon">
                      <ClipboardListIcon size={40} />
                    </div>
                    <h4>No Custom Builds Found</h4>
                    <p>No builds match your current filter criteria.</p>
                    <button
                      type="button"
                      onClick={onResetFilters}
                      className="btn btn-outline"
                    >
                      Clear All Filters
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          ) : (
            <tbody>
              {displayedItems.map((build) => (
                <BuildReviewTableRow
                  key={build.buildId}
                  build={build}
                  onInspect={onInspect}
                />
              ))}
            </tbody>
          )}
        </table>
      </div>

      {!loading && builds.length > 0 && (
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={builds.length}
          pageSize={pageSize}
          pageSizeOptions={[10, 25, 50]}
          onPageChange={onPageChange}
          onPageSizeChange={onPageSizeChange}
          itemLabel="custom builds"
        />
      )}
    </div>
  );
};

export default BuildReviewTable;

