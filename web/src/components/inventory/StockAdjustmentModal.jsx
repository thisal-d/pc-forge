import React from 'react';
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
          </div>

          <div className="saas-modal-footer">
            <button
              type="button"
              className="btn btn-secondary"
              onClick={onClose}
              disabled={isSubmitting}
              id="btn-cancel-adjust-stock"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={isSubmitting}
              id="btn-confirm-adjust-stock"
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
