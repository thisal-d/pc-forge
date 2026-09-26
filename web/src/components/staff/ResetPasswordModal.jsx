import React from 'react';
import { KeyIcon, CloseIcon } from '../icons/index.js';

const ResetPasswordModal = ({
  isOpen,
  candidate,
  onClose,
  onSubmit,
  passwordData,
  onChangePasswordData,
  errors,
  generalError,
  submitting,
}) => {
  if (!isOpen || !candidate) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" style={{ maxWidth: '460px' }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
            <KeyIcon size={18} /> Reset Staff Password
          </h3>
          <button onClick={onClose} className="modal-close-btn" title="Close">
            <CloseIcon size={16} />
          </button>
        </div>
        <form onSubmit={onSubmit} noValidate>
          <div className="modal-body">
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              Set a new temporary password for <strong>{candidate.firstName} {candidate.lastName}</strong> (<code>{candidate.id}</code>).
            </p>

            {generalError && <div className="alert alert-error">{generalError}</div>}

            <div className="form-group">
              <label htmlFor="reset-new-password">New Password *</label>
              <input
                id="reset-new-password"
                type="password"
                placeholder="Minimum 6 characters"
                className={errors.password ? 'input-error' : ''}
                value={passwordData.password}
                onChange={(e) => onChangePasswordData('password', e.target.value)}
                required
              />
              {errors.password && <span className="field-error-text">{errors.password}</span>}
            </div>

            <div className="form-group">
              <label htmlFor="reset-confirm-password">Confirm New Password *</label>
              <input
                id="reset-confirm-password"
                type="password"
                placeholder="Re-enter new password"
                className={errors.confirmPassword ? 'input-error' : ''}
                value={passwordData.confirmPassword}
                onChange={(e) => onChangePasswordData('confirmPassword', e.target.value)}
                required
              />
              {errors.confirmPassword && (
                <span className="field-error-text">{errors.confirmPassword}</span>
              )}
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" onClick={onClose} className="btn btn-outline-sm">
              Cancel
            </button>
            <button type="submit" disabled={submitting} className="btn btn-primary-sm">
              {submitting ? 'Updating...' : 'Update Password'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ResetPasswordModal;
