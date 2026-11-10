import React from 'react';
import { CloseIcon, AlertTriangleIcon } from '../icons/index.js';

export const DeleteProductModal = ({
  product,
  onClose,
  onConfirm,
  submitting,
}) => {
  if (!product) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '480px' }}
        onClick={(e) => e.stopPropagation()}
        id="delete-product-modal"
      >
        <div className="modal-header">
          <h3 style={{ color: '#f87171' }}>Confirm Product Deletion</h3>
          <button onClick={onClose} className="modal-close-btn" title="Close modal">
            <CloseIcon size={16} />
          </button>
        </div>

        <div className="modal-body">
          <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
            Are you sure you want to permanently delete{' '}
            <strong style={{ color: 'var(--text-main)' }}>"{product.name}"</strong>?
          </p>
          <div
            style={{
              background: 'var(--danger-light)',
              border: '1px solid #fecaca',
              padding: '0.75rem 1rem',
              borderRadius: '6px',
              fontSize: '0.85rem',
              color: 'var(--danger-text)',
            }}
          >
            <AlertTriangleIcon size={16} style={{ marginRight: '0.35rem' }} /> <strong>Safety Warning:</strong> This will also remove all associated dynamic filter values (specs) and remove this component from store listings.
          </div>
        </div>

        <div className="modal-footer">
          <button
            type="button"
            onClick={onClose}
            className="btn btn-outline-sm"
            disabled={submitting}
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            className="btn-danger-sm"
            style={{ padding: '0.5rem 1rem' }}
            disabled={submitting}
            id="confirm-delete-product-btn"
          >
            {submitting ? 'Deleting...' : 'Delete Product'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default DeleteProductModal;
