import React from 'react';
import { getCategoryBadgeClass, getStockPercentage } from '../../constants/inventoryConstants.js';
import { MonitorIcon } from '../icons/index.js';

export const InventoryTableRow = ({
  product,
  isSelected,
  onToggleSelect,
  stepQty,
  onStepQtyChange,
  onApplyStepper,
  onOpenAdjustModal,
}) => {
  const prodId = product.productId || product.id;
  const stock = Number(product.stockQuantity) || 0;
  const isOut = stock <= 0;
  const isLow = stock > 0 && stock <= 5;
  const displayId = `P${String(prodId).padStart(2, '0')}`;
  const stockPercentage = getStockPercentage(stock);

  return (
    <tr
      id={`inventory-row-${prodId}`}
      className={`table-row ${isSelected ? 'row-selected' : ''}`}
    >
      {/* Checkbox */}
      <td className="td-checkbox">
        <input
          type="checkbox"
          className="saas-checkbox"
          checked={isSelected}
          onChange={() => onToggleSelect(prodId)}
          aria-label={`Select product ${product.name}`}
        />
      </td>

      {/* ID Pill */}
      <td className="td-id">
        <span className="id-pill-badge">{displayId}</span>
      </td>

      {/* Product Thumbnail + Name + Model */}
      <td className="td-product">
        <div className="product-cell-wrapper">
          <div className="product-thumb-box">
            {product.imageUrl ? (
              <img
                src={product.imageUrl}
                alt={product.name}
                className="product-thumb-img"
                onError={(e) => {
                  e.target.style.display = 'none';
                  e.target.nextElementSibling.style.display = 'flex';
                }}
              />
            ) : null}
            <div
              className="product-thumb-fallback"
              style={{ display: product.imageUrl ? 'none' : 'flex' }}
            >
              <MonitorIcon size={18} color="var(--text-muted)" />
            </div>
          </div>
          <div className="product-text-details">
            <span className="product-name-bold">{product.name}</span>
            <span className="product-meta-subtitle">
              {product.brand} {product.model ? `• Model: ${product.model}` : ''}
            </span>
          </div>
        </div>
      </td>

      {/* Category Pill */}
      <td className="td-category">
        <span className={`cat-pill ${getCategoryBadgeClass(product.categoryName)}`}>
          {product.categoryName || 'General'}
        </span>
      </td>

      {/* MSRP */}
      <td className="td-msrp">
        <span className="msrp-value">LKR {Number(product.price).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
      </td>

      {/* Current Stock + Bar */}
      <td className="td-stock">
        <div className="stock-cell-wrapper">
          <div className="stock-number-row">
            <span className="stock-units-bold">{stock} units</span>
          </div>
          <div className="stock-bar-row">
            <div className="stock-progress-track">
              <div
                className={`stock-progress-fill ${isOut ? 'fill-red' : isLow ? 'fill-amber' : 'fill-green'}`}
                style={{ width: `${stockPercentage}%` }}
              ></div>
            </div>
            <span className="stock-percent-text">{stockPercentage}%</span>
          </div>
        </div>
      </td>

      {/* Stock Status Pill with Dot */}
      <td className="td-status">
        <span
          className={`status-pill ${
            isOut
              ? 'status-pill-out'
              : isLow
              ? 'status-pill-low'
              : 'status-pill-in'
          }`}
        >
          <span className="status-dot"></span>
          {isOut ? 'OUT OF STOCK' : isLow ? 'LOW STOCK' : 'IN STOCK'}
        </span>
      </td>

      {/* Actions: Stepper + Adjust Button */}
      <td className="td-actions">
        <div className="actions-cell-wrapper">
          {/* Stepper: [-] [1] [+] */}
          <div className="stepper-control-group">
            <button
              type="button"
              className="stepper-btn stepper-btn-dec"
              onClick={() => onApplyStepper(product, -1)}
              disabled={isOut}
              title="Decrease stock by stepper value"
            >
              –
            </button>
            <input
              type="number"
              min="1"
              max="999"
              className="stepper-qty-input"
              value={stepQty}
              onChange={(e) => {
                const val = parseInt(e.target.value, 10);
                if (!isNaN(val) && val > 0) {
                  onStepQtyChange(prodId, val);
                }
              }}
            />
            <button
              type="button"
              className="stepper-btn stepper-btn-inc"
              onClick={() => onApplyStepper(product, 1)}
              title="Increase stock by stepper value"
            >
              +
            </button>
          </div>

          {/* Adjust Button */}
          <button
            type="button"
            className="btn-adjust-action"
            onClick={() => onOpenAdjustModal(product)}
            title="Adjust warehouse inventory"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <line x1="4" y1="21" x2="4" y2="14"></line>
              <line x1="4" y1="10" x2="4" y2="3"></line>
              <line x1="12" y1="21" x2="12" y2="12"></line>
              <line x1="12" y1="8" x2="12" y2="3"></line>
              <line x1="20" y1="21" x2="20" y2="16"></line>
              <line x1="20" y1="12" x2="20" y2="3"></line>
              <line x1="1" y1="14" x2="7" y2="14"></line>
              <line x1="9" y1="8" x2="15" y2="8"></line>
              <line x1="17" y1="16" x2="23" y2="16"></line>
            </svg>
            <span>Adjust</span>
          </button>
        </div>
      </td>
    </tr>
  );
};

export default InventoryTableRow;
