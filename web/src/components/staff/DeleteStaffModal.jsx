import React from 'react';
import { CloseIcon } from '../icons/index.js';

const DeleteStaffModal = ({
  candidate,
  onClose,
  onConfirm,
}) => {
  if (!candidate) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" style={{ maxWidth: '440px' }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Confirm Deletion</h3>
          <button onClick={onClose} className="modal-close-btn">
            <CloseIcon size={16} />
          </button>
        </div>
        <div className="modal-body">
          <p>
            Are you sure you want to remove staff member{' '}
            <strong>{candidate.firstName} {candidate.lastName}</strong> (
            <code>{candidate.id}</code>)?
          </p>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            This will revoke all technician privileges and workshop bench access for this account.
          </p>
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
            onClick={onConfirm}
            className="btn-danger-sm"
            style={{ padding: '0.45rem 1rem' }}
          >
            Confirm Delete
          </button>
        </div>
      </div>
    </div>
  );
};

export default DeleteStaffModal;
