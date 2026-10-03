import React from 'react';
import { ZapIcon, CloseIcon, CheckIcon } from '../icons/index.js';

export const RmaModal = ({
  isOpen,
  onClose,
  ticket,
  rmaCarrier,
  onRmaCarrierChange,
  rmaReason,
  onRmaReasonChange,
  onSubmit,
}) => {
  if (!isOpen || !ticket) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '500px' }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="modal-header">
          <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <ZapIcon size={18} /> Authorize RMA & Generate Return Label
          </h3>
          <button onClick={onClose} className="modal-close-btn" aria-label="Close">
            <CloseIcon size={16} />
          </button>
        </div>

        <form onSubmit={onSubmit}>
          <div className="modal-body">
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
              Authorizing Return Merchandise Authorization for{' '}
              <strong>{ticket.customerName}</strong> under Order #{ticket.orderId}:
            </p>

            <div
              style={{
                background: 'var(--bg)',
                padding: '0.75rem',
                borderRadius: '6px',
                border: '1px solid var(--border)',
              }}
            >
              <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                TARGET COMPONENT:
              </div>
              <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>
                {ticket.productName}
              </div>
              <div style={{ fontSize: '0.75rem', color: 'var(--success-text)', marginTop: '0.2rem', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <CheckIcon size={14} /> 3-Year Manufacturer Warranty Active
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="rma-carrier-select" style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                Assigned Return Courier:
              </label>
              <select
                id="rma-carrier-select"
                value={rmaCarrier}
                onChange={(e) => onRmaCarrierChange(e.target.value)}
                style={{
                  width: '100%',
                  background: '#ffffff',
                  color: 'var(--text-main)',
                  border: '1px solid var(--border)',
                  borderRadius: '6px',
                  padding: '0.5rem',
                  fontSize: '0.85rem',
                  marginTop: '0.35rem',
                }}
              >
                <option value="PCForge Express / Prompt Courier">PCForge Express / Prompt Courier (Free Pickup)</option>
                <option value="DHL Express Domestic">DHL Express Domestic</option>
                <option value="Customer Walk-in / Store Drop-off">Customer Walk-in / Store Drop-off</option>
              </select>
            </div>

            <div className="form-group">
              <label htmlFor="rma-reason-input" style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                RMA Failure Diagnostics Reason:
              </label>
              <input
                id="rma-reason-input"
                type="text"
                placeholder="e.g., Thermal paste degradation / Core overheating > 95C"
                value={rmaReason}
                onChange={(e) => onRmaReasonChange(e.target.value)}
                style={{
                  width: '100%',
                  background: '#ffffff',
                  color: 'var(--text-main)',
                  border: '1px solid var(--border)',
                  borderRadius: '6px',
                  padding: '0.5rem',
                  fontSize: '0.85rem',
                  marginTop: '0.35rem',
                }}
              />
            </div>
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
              type="submit"
              className="btn btn-primary-sm"
              style={{ background: '#d97706', borderColor: '#f59e0b', display: 'inline-flex', alignItems: 'center', gap: '0.4rem' }}
            >
              <CheckIcon size={14} /> Confirm & Generate RMA
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default RmaModal;
