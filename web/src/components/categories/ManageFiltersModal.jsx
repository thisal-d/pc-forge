import React from 'react';
import AssignedFiltersList from './AssignedFiltersList.jsx';
import AddFilterForm from './AddFilterForm.jsx';
import { CloseIcon } from '../icons/index.js';

export const ManageFiltersModal = ({
  category,
  onClose,
  assignedFilters,
  filtersLoading,
  onReorderFilter,
  onToggleFilterActive,
  onRemoveFilter,
  filterActionError,
  filterActionSuccess,
  filterMode,
  onFilterModeChange,
  selectedPoolFilterKey,
  onSelectedPoolFilterKeyChange,
  availableFiltersPool,
  customFilterData,
  onCustomFilterDataChange,
  onAddFilterAssignment,
}) => {
  if (!category) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '680px' }}
        onClick={(e) => e.stopPropagation()}
        id="manage-filters-modal"
      >
        <div className="modal-header">
          <div>
            <h3 style={{ marginBottom: '0.2rem' }}>
              Dynamic Filters: {category.name}
            </h3>
            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
              Configure product technical specifications and search filter attributes
            </span>
          </div>
          <button onClick={onClose} className="modal-close-btn">
            <CloseIcon size={16} />
          </button>
        </div>

        <div className="modal-body" style={{ maxHeight: '72vh', overflowY: 'auto' }}>
          {/* Feedback banners */}
          {filterActionError && (
            <div className="alert alert-error" style={{ marginBottom: '1rem', padding: '0.6rem 0.85rem' }}>
              {filterActionError}
            </div>
          )}
          {filterActionSuccess && (
            <div className="alert alert-success" style={{ marginBottom: '1rem', padding: '0.6rem 0.85rem' }}>
              {filterActionSuccess}
            </div>
          )}

          {/* Section 1: Assigned Filters List with Reordering */}
          <AssignedFiltersList
            filters={assignedFilters}
            loading={filtersLoading}
            onReorder={onReorderFilter}
            onToggleActive={onToggleFilterActive}
            onRemove={onRemoveFilter}
          />

          {/* Section 2: Add / Assign Filter */}
          <AddFilterForm
            filterMode={filterMode}
            onFilterModeChange={onFilterModeChange}
            selectedPoolFilterKey={selectedPoolFilterKey}
            onSelectedPoolFilterKeyChange={onSelectedPoolFilterKeyChange}
            availableFiltersPool={availableFiltersPool}
            assignedFilters={assignedFilters}
            customFilterData={customFilterData}
            onCustomFilterDataChange={onCustomFilterDataChange}
            onSubmit={onAddFilterAssignment}
          />
        </div>

        <div className="modal-footer" style={{ borderTop: '1px solid var(--border)', background: '#f8fafc', padding: '0.85rem 1.5rem', display: 'flex', justifyContent: 'flex-end' }}>
          <button
            type="button"
            onClick={onClose}
            className="btn btn-primary-sm"
            style={{ minWidth: '90px', fontWeight: 600 }}
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};

export default ManageFiltersModal;
