import React from 'react';
import CategoryTableRow from './CategoryTableRow.jsx';
import { FolderOpenIcon } from '../icons/index.js';
import { Pagination } from '../common/Pagination.jsx';
import { TableSkeleton } from '../common/TableSkeleton.jsx';

export const CategoryTable = ({
  filteredCategories = [],
  paginatedCategories = [],
  totalCount = 0,
  loading = false,
  currentPage = 1,
  totalPages = 1,
  pageSize = 10,
  onPageChange,
  onPageSizeChange,
  onResetFilters,
  onOpenAddModal,
  onViewCategory,
  onEditCategory,
  onManageFilters,
  onToggleStatus,
  onDeleteCategory,
}) => {
  const displayedItems = paginatedCategories.length > 0 || filteredCategories.length === 0
    ? paginatedCategories
    : filteredCategories.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  return (
    <div className="data-table-card">
      <div className="table-header-banner">
        <h3>Category Directory ({filteredCategories.length})</h3>
        <span className="table-header-subtitle">
          Showing {displayedItems.length} of {totalCount} categories
        </span>
      </div>

      <div className="table-responsive">
        <table className="data-table" id="categories-table">
          <thead>
            <tr>
              <th style={{ width: '80px' }}>ID</th>
              <th style={{ width: '180px' }}>Category Name</th>
              <th>Description</th>
              <th style={{ width: '130px' }}>Assigned Filters</th>
              <th style={{ width: '100px' }}>Status</th>
              <th style={{ width: '120px' }}>Created Date</th>
              <th style={{ textAlign: 'right', width: '280px' }}>Actions</th>
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
                      <FolderOpenIcon size={36} />
                    </div>
                    <h4>No categories found</h4>
                    <p>No component categories match your current search or status filter.</p>
                    <div style={{ display: 'flex', justifyContent: 'center', gap: '0.75rem' }}>
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
                        + Add Category
                      </button>
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          ) : (
            <tbody>
              {displayedItems.map((cat) => (
                <CategoryTableRow
                  key={cat.categoryId || cat.id}
                  category={cat}
                  onView={onViewCategory}
                  onEdit={onEditCategory}
                  onManageFilters={onManageFilters}
                  onToggleStatus={onToggleStatus}
                  onDelete={onDeleteCategory}
                />
              ))}
            </tbody>
          )}
        </table>
      </div>

      {onPageChange && (
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={filteredCategories.length}
          pageSize={pageSize}
          onPageChange={onPageChange}
          onPageSizeChange={onPageSizeChange}
          itemLabel="categories"
        />
      )}
    </div>
  );
};

export default CategoryTable;
