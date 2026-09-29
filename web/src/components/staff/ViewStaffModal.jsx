import React from 'react';
import { CloseIcon, PencilIcon, KeyIcon } from '../icons/index.js';

const ViewStaffModal = ({
  staff,
  onClose,
  onOpenEdit,
  onOpenReset,
}) => {
  if (!staff) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" style={{ maxWidth: '620px' }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <div className="avatar-circle">
              {`${staff.firstName?.[0] || ''}${staff.lastName?.[0] || ''}`.toUpperCase()}
            </div>
            <div>
              <h3 style={{ margin: 0 }}>{staff.firstName} {staff.lastName}</h3>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Staff ID: {staff.id}</span>
            </div>
          </div>
          <button onClick={onClose} className="modal-close-btn" title="Close">
            <CloseIcon size={16} />
          </button>
        </div>

        <div className="modal-body">
          <div className="details-grid">
            <div className="detail-item">
              <span className="detail-item-label">Full Name</span>
              <span className="detail-item-value">{staff.firstName} {staff.lastName}</span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Email Address</span>
              <span className="detail-item-value">{staff.email}</span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Phone Number</span>
              <span className="detail-item-value">{staff.phone || '—'}</span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Account Status</span>
              <span className="detail-item-value">
                <span className={`badge ${staff.status === 'Active' ? 'badge-success' : 'badge-error'}`}>
                  {staff.status}
                </span>
              </span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Department</span>
              <span className="detail-item-value">{staff.department || '—'}</span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Specialization / Technical Expertise</span>
              <span className="detail-item-value">{staff.specialization || '—'}</span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Created Date</span>
              <span className="detail-item-value">{staff.createdDate || staff.joinedDate || '—'}</span>
            </div>

            <div className="detail-item">
              <span className="detail-item-label">Last Login</span>
              <span className="detail-item-value">{staff.lastLogin || 'Never'}</span>
            </div>
          </div>

          <div style={{ marginTop: '1rem', borderTop: '1px solid var(--border)', paddingTop: '1rem' }}>
            <span className="detail-item-label">Basic Account Information & Notes</span>
            <p style={{ marginTop: '0.4rem', color: '#cbd5e1', fontSize: '0.9rem', lineHeight: 1.6 }}>
              {staff.notes || 'No additional notes provided for this staff account.'}
            </p>
          </div>
        </div>

        <div className="modal-footer" style={{ justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <button
              type="button"
              onClick={() => {
                const target = staff;
                onClose();
                onOpenEdit(target);
              }}
              className="btn btn-outline-sm"
              style={{ display: 'inline-flex', alignItems: 'center' }}
            >
              <PencilIcon size={14} style={{ marginRight: '0.35rem' }} /> Edit Staff
            </button>
            <button
              type="button"
              onClick={() => {
                const target = staff;
                onClose();
                onOpenReset(target);
              }}
              className="btn btn-outline-sm"
              style={{ display: 'inline-flex', alignItems: 'center' }}
            >
              <KeyIcon size={14} style={{ marginRight: '0.35rem' }} /> Reset Password
            </button>
          </div>
          <button type="button" onClick={onClose} className="btn btn-primary-sm">
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default ViewStaffModal;
