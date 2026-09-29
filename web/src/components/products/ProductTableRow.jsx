import React from 'react';
import { ZapIcon } from '../icons/index.js';

export const ProductTableRow = ({
  product,
  onView,
  onEdit,
  onToggleStatus,
  onDelete,
}) => {
  const prodId = product.productId || product.id;
  const isActive = (product.status || 'Active').toLowerCase() === 'active';
  const isOutOfStock = product.stockQuantity <= 0;
  const isLowStock = product.stockQuantity > 0 && product.stockQuantity <= 5;

  return (
    <tr id={`product-row-${prodId}`}>
      {/* Product ID */}
      <td>
        <span className="id-badge">PRD-{String(prodId).padStart(2, '0')}</span>
      </td>

      {/* Product Name */}
      <td>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          {product.imageUrl ? (
            <img
              src={product.imageUrl}
              alt={product.name}
              style={{
                width: '36px',
                height: '36px',
                objectFit: 'cover',
                borderRadius: '4px',
                border: '1px solid var(--border)',
              }}
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
          ) : (
            <div
              style={{
                width: '36px',
                height: '36px',
                borderRadius: '4px',
                background: '#f1f5f9',
                border: '1px solid var(--border)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1rem',
              }}
            >
              <ZapIcon size={18} color="var(--text-muted)" />
            </div>
          )}
          <div>
            <strong style={{ color: 'var(--text-main)', fontSize: '0.95rem' }}>{product.name}</strong>
            {product.model && (
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                Model: {product.model}
              </div>
            )}
          </div>
        </div>
      </td>

      {/* Category */}
      <td>
        <span className="cat-pill cat-badge-default">
          {product.categoryName || 'General'}
        </span>
      </td>

      {/* Brand */}
      <td>
        <strong style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>{product.brand}</strong>
      </td>

      {/* Price */}
      <td>
        <span style={{ color: 'var(--text-main)', fontWeight: 700 }}>
          LKR {Number(product.price).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </span>
      </td>

      {/* Stock */}
      <td>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
          <span style={{ color: 'var(--text-main)', fontWeight: 600 }}>
            {product.stockQuantity} units
          </span>
          <span
            className={`badge ${
              isOutOfStock
                ? 'badge-error'
                : isLowStock
                ? 'badge-warning'
                : 'badge-success'
            }`}
            style={{ fontSize: '0.675rem', width: 'fit-content' }}
          >
            {isOutOfStock ? 'Depleted' : isLowStock ? 'Low Stock' : 'In Stock'}
          </span>
        </div>
      </td>

      {/* Status */}
      <td>
        <span className={`badge ${isActive ? 'badge-success' : 'badge-warning'}`}>
          {product.status || 'Active'}
        </span>
      </td>

      {/* Created Date */}
      <td style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
        {product.createdDate || (product.createdAt ? product.createdAt.split('T')[0] : '—')}
      </td>

      {/* Actions */}
      <td>
        <div className="action-btn-group" style={{ justifyContent: 'flex-end' }}>
          <button
            onClick={() => onView(product)}
            className="btn btn-outline-sm"
            title="View product specifications"
            id={`view-product-btn-${prodId}`}
          >
            View
          </button>
          <button
            onClick={() => onEdit(product)}
            className="btn btn-outline-sm"
            title="Edit product information"
            id={`edit-product-btn-${prodId}`}
          >
            Edit
          </button>
          <button
            onClick={() => onToggleStatus(product)}
            className={isActive ? 'btn-warning-sm' : 'btn-success-sm'}
            title={isActive ? 'Mark as Inactive' : 'Mark as Active'}
            id={`toggle-product-btn-${prodId}`}
          >
            {isActive ? 'Deactivate' : 'Activate'}
          </button>
          <button
            onClick={() => onDelete(product)}
            className="btn-danger-sm"
            title="Delete product"
            id={`delete-product-btn-${prodId}`}
          >
            Delete
          </button>
        </div>
      </td>
    </tr>
  );
};

export default ProductTableRow;
