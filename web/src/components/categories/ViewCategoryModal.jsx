import React from 'react';
import { CloseIcon, SettingsIcon } from '../icons/index.js';

export const ViewCategoryModal = ({
  category,
  filters,
  onClose,
  onManageFilters,
}) => {
  if (!category) return null;

  const catId = category.categoryId || category.id;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()} id="view-category-modal">
        <div className="modal-header">
          <div>
            <h3 style={{ marginBottom: '0.2rem' }}>{category.name}</h3>
            <span className="id-badge">
              CAT-{String(catId).padStart(2, '0')}
            </span>
          </div>
          <button onClick={onClose} className="modal-close-btn">
            <CloseIcon size={16} />
          </button>
        </div>

        <div className="modal-body">
          <div className="details-grid">
            <div className="detail-item">
              <span className="detail-item-label">Status</span>
              <span className="detail-item-value">
                <span className={`badge ${category.status === 'Active' ? 'badge-success' : 'badge-warning'}`}>
                  {category.status || 'Active'}
                </span>
              </span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Created Date</span>
              <span className="detail-item-value">
                {category.createdDate || (category.createdAt ? category.createdAt.split('T')[0] : '—')}
              </span>
            </div>

            <div className="detail-item" style={{ gridColumn: 'span 2' }}>
              <span className="detail-item-label">Description</span>
              <span className="detail-item-value" style={{ fontStyle: category.description ? 'normal' : 'italic' }}>
                {category.description || 'No description provided.'}
              </span>
            </div>
          </div>

          {/* Assigned Filters Breakdown */}
          <div style={{ marginTop: '1.25rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
              <h4 style={{ margin: 0, fontSize: '0.95rem' }}>
                Configured Dynamic Filters ({filters.length})
              </h4>
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onManageFilters(category);
                }}
                className="btn btn-outline-sm"
                style={{ fontSize: '0.75rem', padding: '0.25rem 0.5rem', display: 'inline-flex', alignItems: 'center' }}
              >
                <SettingsIcon size={13} style={{ marginRight: '0.35rem' }} /> Manage Filters
              </button>
            </div>

            {filters.length === 0 ? (
              <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontStyle: 'italic', margin: '0.5rem 0' }}>
                No filters currently assigned to this category. Click 'Manage Filters' to add specs like Chipset, VRAM, or Socket.
              </p>
            ) : (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem', marginTop: '0.5rem' }}>
                {filters.map((f) => (
                  <span
                    key={f.filterId}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                      background: f.isFilterable ? '#eff6ff' : '#f1f5f9',
                      border: '1px solid ' + (f.isFilterable ? '#bfdbfe' : 'var(--border)'),
                      color: f.isFilterable ? '#1d4ed8' : 'var(--text-muted)',
                      padding: '0.25rem 0.65rem',
                      borderRadius: '6px',
                      fontSize: '0.8rem',
                      fontWeight: 500,
                    }}
                  >
                    <strong>{f.displayName}</strong>
                    {f.unit && ` (${f.unit})`}
                    {!f.isFilterable && ' [Disabled]'}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="modal-footer">
          <button
            type="button"
            onClick={onClose}
            className="btn btn-outline-sm"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default ViewCategoryModal;
