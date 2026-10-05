import React from 'react';
import { SettingsIcon } from '../icons/index.js';

export const CategoryTableRow = ({
  category,
  onView,
  onEdit,
  onManageFilters,
  onToggleStatus,
  onDelete,
}) => {
  const catId = category.categoryId || category.id;
  const isActive = (category.status || 'Active').toLowerCase() === 'active';
  const filterCount = category.filterCount ?? (category.assignedFilters ? category.assignedFilters.length : 0);

  return (
    <tr id={`category-row-${catId}`}>
      {/* Category ID */}
      <td>
        <span className="id-badge">CAT-{String(catId).padStart(2, '0')}</span>
      </td>

      {/* Category Name */}
      <td>
        <strong style={{ color: 'var(--text-main)', fontSize: '0.95rem' }}>
          {category.name}
        </strong>
      </td>

      {/* Description */}
      <td>
        <span className="table-desc-text" title={category.description}>
          {category.description || 'No description provided.'}
        </span>
      </td>

      {/* Number of Filters */}
      <td>
        <button
          type="button"
          onClick={() => onManageFilters(category)}
          className="cat-pill cat-badge-default"
          style={{ cursor: 'pointer', border: 'none', display: 'inline-flex', alignItems: 'center' }}
          title="Click to manage dynamic filters for this category"
          id={`manage-filters-badge-${catId}`}
        >
          <SettingsIcon size={13} style={{ marginRight: '0.35rem' }} /> {filterCount} {filterCount === 1 ? 'Filter' : 'Filters'}
        </button>
      </td>

      {/* Status */}
      <td>
        <span className={`badge ${isActive ? 'badge-success' : 'badge-warning'}`}>
          {category.status || 'Active'}
        </span>
      </td>

      {/* Created Date */}
      <td style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
        {category.createdDate || (category.createdAt ? category.createdAt.split('T')[0] : '—')}
      </td>

      {/* Actions */}
      <td>
        <div className="action-btn-group" style={{ justifyContent: 'flex-end' }}>
          <button
            type="button"
            onClick={() => onView(category)}
            className="btn btn-outline-sm"
            title="View category details & filters"
            id={`view-cat-btn-${catId}`}
          >
            View
          </button>
          <button
            type="button"
            onClick={() => onEdit(category)}
            className="btn btn-outline-sm"
            title="Edit category"
            id={`edit-cat-btn-${catId}`}
          >
            Edit
          </button>
          <button
            type="button"
            onClick={() => onManageFilters(category)}
            className="btn btn-outline-sm"
            style={{ borderColor: 'var(--primary)', color: 'var(--primary)' }}
            title="Configure dynamic filters"
            id={`manage-filters-btn-${catId}`}
          >
            Filters
          </button>
          <button
            type="button"
            onClick={() => onToggleStatus(category)}
            className={isActive ? 'btn-warning-sm' : 'btn-success-sm'}
            title={isActive ? 'Deactivate category' : 'Activate category'}
            id={`toggle-cat-btn-${catId}`}
          >
            {isActive ? 'Deactivate' : 'Activate'}
          </button>
          <button
            type="button"
            onClick={() => onDelete(category)}
            className="btn-danger-sm"
            title="Delete category"
            id={`delete-cat-btn-${catId}`}
          >
            Delete
          </button>
        </div>
      </td>
    </tr>
  );
};

export default CategoryTableRow;
