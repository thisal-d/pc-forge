import React from 'react';
import { AlertTriangleIcon, CloseIcon, BanIcon } from '../icons/index.js';

export const DeleteCategoryModal = ({
  category,
  onClose,
  onConfirm,
  error,
}) => {
  if (!category) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()} id="delete-category-modal">
        <div className="modal-header">
          <h3 style={{ color: '#f87171', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
            <AlertTriangleIcon size={18} /> Delete Category Confirmation
          </h3>
          <button onClick={onClose} className="modal-close-btn">
            <CloseIcon size={16} />
          </button>
        </div>

        <div className="modal-body">
          {error ? (
            <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
              {error}
            </div>
          ) : (
            <p style={{ color: 'var(--text-main)', fontSize: '0.95rem' }}>
              Are you sure you want to delete category{' '}
              <strong style={{ color: 'var(--primary)' }}>"{category.name}"</strong>?
            </p>
          )}

          {category.productCount > 0 ? (
            <div
              style={{
                background: 'rgba(239, 68, 68, 0.1)',
                border: '1px solid rgba(239, 68, 68, 0.3)',
                padding: '0.75rem',
                borderRadius: '6px',
                fontSize: '0.85rem',
                color: '#f87171',
                marginTop: '0.5rem',
              }}
            >
              <BanIcon size={16} style={{ marginRight: '0.35rem' }} /> <strong>Cannot delete category:</strong> There are currently{' '}
              <strong>{category.productCount} products</strong> assigned to this category in the catalog.
              Reassign or delete these products first.
            </div>
          ) : (
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '0.5rem' }}>
              This will remove the category and all its dynamic filter specifications. This action cannot be undone.
            </p>
          )}
        </div>

        <div className="modal-footer">
          <button
            type="button"
            onClick={onClose}
            className="btn btn-outline-sm"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={category.productCount > 0}
            onClick={onConfirm}
            className="btn btn-danger-sm"
            id="confirm-delete-cat-btn"
          >
            Delete Category
          </button>
        </div>
      </div>
    </div>
  );
};

export default DeleteCategoryModal;
