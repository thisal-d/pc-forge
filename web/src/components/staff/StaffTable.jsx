import React from 'react';
import StaffTableRow from './StaffTableRow.jsx';
import { UsersIcon } from '../icons/index.js';
import { Pagination } from '../common/Pagination.jsx';
import { TableSkeleton } from '../common/TableSkeleton.jsx';

export const StaffTable = ({
  staffList = [],
  paginatedStaff = [],
  totalCount = 0,
  loading = false,
  currentPage = 1,
  totalPages = 1,
  pageSize = 10,
  onPageChange,
  onPageSizeChange,
  onResetFilters,
  onOpenAddModal,
  onView,
  onEdit,
  onResetPassword,
  onToggleStatus,
  onDelete,
}) => {
  const displayedItems = paginatedStaff.length > 0 || staffList.length === 0
    ? paginatedStaff
    : staffList.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  return (
    <div className="data-table-card">
      <div className="table-header-banner">
        <h3>Staff Directory ({staffList.length})</h3>
        <span className="table-header-subtitle">
          Showing {displayedItems.length} of {totalCount} registered accounts
        </span>
      </div>

      <div className="table-responsive">
        <table className="data-table" id="staff-table">
          <thead>
            <tr>
              <th>User / Name</th>
              <th>Staff ID</th>
              <th>Department & Specialization</th>
              <th>Phone</th>
              <th>Status</th>
              <th>Joined Date</th>
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
                      <UsersIcon size={36} />
                    </div>
                    <h4>No staff members found</h4>
                    <p>Try adjusting your search criteria or clear your active filters.</p>
                    <div style={{ display: 'flex', justifyContent: 'center', gap: '0.75rem', marginTop: '0.5rem' }}>
                      <button
                        type="button"
                        onClick={onResetFilters}
                        className="btn btn-outline-sm"
                      >
                        Clear Filters
                      </button>
                      <button
                        type="button"
                        onClick={onOpenAddModal}
                        className="btn btn-primary-sm"
                      >
                        + Register Staff Member
                      </button>
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          ) : (
            <tbody>
              {displayedItems.map((member) => (
                <StaffTableRow
                  key={member.id}
                  member={member}
                  onView={onView}
                  onEdit={onEdit}
                  onResetPassword={onResetPassword}
                  onToggleStatus={onToggleStatus}
                  onDelete={onDelete}
                />
              ))}
            </tbody>
          )}
        </table>
      </div>

      {!loading && staffList.length > 0 && (
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={staffList.length}
          pageSize={pageSize}
          pageSizeOptions={[10, 25, 50]}
          onPageChange={onPageChange}
          onPageSizeChange={onPageSizeChange}
          itemLabel="staff accounts"
        />
      )}
    </div>
  );
};

export default StaffTable;

