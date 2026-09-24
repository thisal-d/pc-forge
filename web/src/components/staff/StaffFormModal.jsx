import React from 'react';
import { DEPARTMENTS } from '../../constants/staffConstants.js';
import { PlusIcon, PencilIcon, CloseIcon, LockIcon } from '../icons/index.js';

export const StaffFormModal = ({
  isOpen,
  modalMode,
  onClose,
  formData,
  onFormChange,
  formErrors,
  formGeneralError,
  submitting,
  onSubmit,
}) => {
  if (!isOpen) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()} id="staff-modal">
        <div className="modal-header">
          <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
            {modalMode === 'add' ? <PlusIcon size={18} /> : <PencilIcon size={16} />}
            {modalMode === 'add' ? 'Register New Staff Member' : 'Edit Staff Member'}
          </h3>
          <button onClick={onClose} className="modal-close-btn">
            <CloseIcon size={16} />
          </button>
        </div>

        <form onSubmit={onSubmit}>
          <div className="modal-body">
            {formGeneralError && (
              <div className="alert alert-error">{formGeneralError}</div>
            )}

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="staff-first-name">First Name *</label>
                <input
                  id="staff-first-name"
                  type="text"
                  placeholder="e.g. Kasun"
                  value={formData.firstName}
                  onChange={(e) => onFormChange('firstName', e.target.value)}
                  className={formErrors.firstName ? 'input-error' : ''}
                />
                {formErrors.firstName && <span className="field-error-text">{formErrors.firstName}</span>}
              </div>

              <div className="form-group">
                <label htmlFor="staff-last-name">Last Name *</label>
                <input
                  id="staff-last-name"
                  type="text"
                  placeholder="e.g. Perera"
                  value={formData.lastName}
                  onChange={(e) => onFormChange('lastName', e.target.value)}
                  className={formErrors.lastName ? 'input-error' : ''}
                />
                {formErrors.lastName && <span className="field-error-text">{formErrors.lastName}</span>}
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="staff-email">Email Address *</label>
                <input
                  id="staff-email"
                  type="email"
                  placeholder="e.g. kasun@pcforge.com"
                  value={formData.email}
                  onChange={(e) => onFormChange('email', e.target.value)}
                  className={formErrors.email ? 'input-error' : ''}
                />
                {formErrors.email && <span className="field-error-text">{formErrors.email}</span>}
              </div>

              <div className="form-group">
                <label htmlFor="staff-phone">Phone Number *</label>
                <input
                  id="staff-phone"
                  type="text"
                  placeholder="+94 77 123 4567"
                  value={formData.phone}
                  onChange={(e) => onFormChange('phone', e.target.value)}
                  className={formErrors.phone ? 'input-error' : ''}
                />
                {formErrors.phone && <span className="field-error-text">{formErrors.phone}</span>}
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="staff-department">Department *</label>
                <select
                  id="staff-department"
                  value={formData.department}
                  onChange={(e) => onFormChange('department', e.target.value)}
                >
                  {DEPARTMENTS.map((dept) => (
                    <option key={dept} value={dept}>
                      {dept}
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label htmlFor="staff-status">Account Status</label>
                <select
                  id="staff-status"
                  value={formData.status}
                  onChange={(e) => onFormChange('status', e.target.value)}
                >
                  <option value="Active">Active</option>
                  <option value="Inactive">Inactive</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="staff-specialization">Hardware Specialization (Optional)</label>
              <input
                id="staff-specialization"
                type="text"
                placeholder="e.g. GPU Micro-soldering, Custom Loop Water Cooling, BIOS Recovery"
                value={formData.specialization}
                onChange={(e) => onFormChange('specialization', e.target.value)}
              />
            </div>

            {/* Password Fields only in 'add' mode */}
            {modalMode === 'add' ? (
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="staff-password">Account Password *</label>
                  <input
                    id="staff-password"
                    type="password"
                    placeholder="Min. 6 characters"
                    value={formData.password}
                    onChange={(e) => onFormChange('password', e.target.value)}
                    className={formErrors.password ? 'input-error' : ''}
                  />
                  {formErrors.password && <span className="field-error-text">{formErrors.password}</span>}
                </div>

                <div className="form-group">
                  <label htmlFor="staff-confirm-password">Confirm Password *</label>
                  <input
                    id="staff-confirm-password"
                    type="password"
                    placeholder="Re-enter password"
                    value={formData.confirmPassword}
                    onChange={(e) => onFormChange('confirmPassword', e.target.value)}
                    className={formErrors.confirmPassword ? 'input-error' : ''}
                  />
                  {formErrors.confirmPassword && (
                    <span className="field-error-text">{formErrors.confirmPassword}</span>
                  )}
                </div>
              </div>
            ) : (
              <div
                style={{
                  background: 'rgba(255, 255, 255, 0.03)',
                  border: '1px solid var(--border)',
                  padding: '0.75rem',
                  borderRadius: '6px',
                  fontSize: '0.8rem',
                  color: 'var(--text-muted)',
                  marginBottom: '1rem',
                }}
              >
                <LockIcon size={14} style={{ marginRight: '0.35rem' }} /> <strong>Password Protected:</strong> Existing passwords are never exposed directly. To change this account's password, use the separate <strong>Reset Pwd</strong> button in the staff table.
              </div>
            )}

            <div className="form-group">
              <label htmlFor="staff-notes">Internal Technician Notes (Optional)</label>
              <textarea
                id="staff-notes"
                rows="2"
                placeholder="Certifications, shift timings, hardware bench clearances..."
                value={formData.notes}
                onChange={(e) => onFormChange('notes', e.target.value)}
              />
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
              type="submit"
              className="btn btn-primary-sm"
              disabled={submitting}
              id="submit-staff-btn"
            >
              {submitting
                ? modalMode === 'add'
                  ? 'Registering...'
                  : 'Updating...'
                : modalMode === 'add'
                ? 'Register Staff Member'
                : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default StaffFormModal;
