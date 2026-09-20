import React from 'react';
import { ADJUSTMENT_REASONS } from '../../constants/inventoryConstants.js';
import { CloseIcon, PackageIcon, TargetIcon } from '../icons/index.js';

export const StockAdjustmentModal = ({
  isOpen,
  product,
  onClose,
  adjustMode,
  onAdjustModeChange,
  amountInput,
  onAmountInputChange,
  previewNewStock,
  reasonInput,
  onReasonInputChange,
  notesInput,
  onNotesInputChange,
  modalError,
  isSubmitting,
  onSubmit,
}) => {
  if (!isOpen || !product) return null;

  return (
    <div className="saas-modal-backdrop" onClick={onClose}>
      <div
        className="saas-modal-card"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-labelledby="modal-adjust-title"
      >
        <div className="saas-modal-header">
          <div>
            <h3 id="modal-adjust-title" className="saas-modal-title">
              Adjust Inventory: {product.name}
            </h3>
            <p className="saas-modal-subtitle">
              {product.brand} • Current Level:{' '}
              <strong>{product.stockQuantity} units</strong>
            </p>
          </div>
          <button
            type="button"
            className="saas-modal-close"
            onClick={onClose}
          >
            <CloseIcon size={16} />
          </button>
        </div>

        <form onSubmit={onSubmit}>
          <div className="saas-modal-body">
            {modalError && <div className="saas-modal-alert-error">{modalError}</div>}

            {/* Operation Mode */}
            <div className="form-group-saas">
              <label className="form-label-saas">Adjustment Operation</label>
              <div className="mode-toggle-group">
                <button
                  type="button"
                  className={`mode-toggle-btn ${adjustMode === 'add' ? 'mode-active' : ''}`}
                  onClick={() => onAdjustModeChange('add')}
                  style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  <PackageIcon size={14} style={{ marginRight: '0.35rem' }} /> Restock (Add Units)
                </button>
                <button
                  type="button"
                  className={`mode-toggle-btn ${adjustMode === 'set' ? 'mode-active' : ''}`}
                  onClick={() => onAdjustModeChange('set')}
                  style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  <TargetIcon size={14} style={{ marginRight: '0.35rem' }} /> Set Exact Stock
                </button>
              </div>
            </div>

            {/* Quantity */}
            <div className="form-group-saas">
              <label className="form-label-saas" htmlFor="modal-amount-input">
                {adjustMode === 'add' ? 'Quantity to Add *' : 'New Exact Stock Level *'}
              </label>
              <input
                id="modal-amount-input"
                type="number"
                min="0"
                step="1"
                className="form-input-saas"
                value={amountInput}
                onChange={(e) => onAmountInputChange(e.target.value)}
                required
              />
              <span className="form-help-text">
                Resulting Stock:{' '}
                <strong style={{ color: '#2563eb' }}>{previewNewStock} units</strong>
              </span>
            </div>

            {/* Reason */}
            <div className="form-group-saas">
              <label className="form-label-saas" htmlFor="modal-reason-select">
                Reason for Adjustment
              </label>
              <select
                id="modal-reason-select"
                className="form-select-saas"
                value={reasonInput}
                onChange={(e) => onReasonInputChange(e.target.value)}
              >
                {ADJUSTMENT_REASONS.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Notes */}
            <div className="form-group-saas">
              <label className="form-label-saas" htmlFor="modal-notes-input">
                Internal Notes (Optional)
              </label>
              <textarea
                id="modal-notes-input"
                className="form-textarea-saas"
                rows="2"
                placeholder="e.g., PO #108492 received from distributor..."
                value={notesInput}
                onChange={(e) => onNotesInputChange(e.target.value)}
              />
            </div>
          </div>

          <div className="saas-modal-footer">
            <button
              type="button"
              className="btn-outline-saas"
              onClick={onClose}
              disabled={isSubmitting}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn-primary-saas"
              disabled={isSubmitting}
            >
              {isSubmitting ? 'Updating...' : 'Confirm Stock Adjustment'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default StockAdjustmentModal;
