import React from 'react';
import { CloseIcon, ZapIcon } from '../icons/index.js';

export const ViewProductModal = ({
  product,
  onClose,
  onEdit,
  viewingFilters,
  viewingFilterValues,
}) => {
  if (!product) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '640px' }}
        onClick={(e) => e.stopPropagation()}
        id="view-product-modal"
      >
        <div className="modal-header">
          <div>
            <h3 style={{ marginBottom: '0.2rem' }}>{product.name}</h3>
            <span className="id-badge">
              PRD-{String(product.productId || product.id).padStart(2, '0')}
            </span>
          </div>
          <button onClick={onClose} className="modal-close-btn" title="Close modal">
            <CloseIcon size={16} />
          </button>
        </div>

        <div className="modal-body" style={{ maxHeight: '72vh' }}>
          {/* Product Header & Image */}
          <div style={{ display: 'flex', gap: '1.25rem', alignItems: 'flex-start' }}>
            {product.imageUrl ? (
              <img
                src={product.imageUrl}
                alt={product.name}
                style={{
                  width: '100px',
                  height: '100px',
                  objectFit: 'cover',
                  borderRadius: '8px',
                  border: '1px solid var(--border)',
                  flexShrink: 0,
                }}
                onError={(e) => {
                  e.target.style.display = 'none';
                }}
              />
            ) : (
              <div
                style={{
                  width: '80px',
                  height: '80px',
                  borderRadius: '8px',
                  background: '#f1f5f9',
                  border: '1px solid var(--border)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '2rem',
                  flexShrink: 0,
                }}
              >
                <ZapIcon size={32} color="var(--text-muted)" />
              </div>
            )}

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem', flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span className="cat-pill cat-badge-default">
                  {product.categoryName || 'General'}
                </span>
                <span className={`badge ${product.status === 'Active' ? 'badge-success' : 'badge-warning'}`}>
                  {product.status || 'Active'}
                </span>
              </div>
              <div style={{ fontSize: '1.4rem', fontWeight: 700, color: 'var(--text-main)' }}>
                LKR {Number(product.price).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                Inventory: <strong style={{ color: 'var(--text-main)' }}>{product.stockQuantity} units available</strong>
              </div>
            </div>
          </div>

          {/* Details Grid */}
          <div className="details-grid" style={{ marginTop: '0.5rem' }}>
            <div className="detail-item">
              <span className="detail-item-label">Brand</span>
              <span className="detail-item-value">{product.brand}</span>
            </div>
            <div className="detail-item">
              <span className="detail-item-label">Model / SKU</span>
              <span className="detail-item-value">{product.model || '—'}</span>
            </div>
            <div className="detail-item">
              <span className="detail-item-label">Warranty</span>
              <span className="detail-item-value" style={{ color: '#10b981', fontWeight: 600 }}>
                {product.warrantyMonths >= 12
                  ? `${Math.floor(product.warrantyMonths / 12)} Year${Math.floor(product.warrantyMonths / 12) > 1 ? 's' : ''}${product.warrantyMonths % 12 > 0 ? ` ${product.warrantyMonths % 12} Mos` : ''}`
                  : `${product.warrantyMonths || 36} Months`}
              </span>
            </div>
            <div className="detail-item">
              <span className="detail-item-label">Stock Status</span>
              <span className="detail-item-value">
                {product.stockQuantity <= 0 ? 'Out of Stock' : product.stockQuantity <= 5 ? 'Low Stock' : 'In Stock'}
              </span>
            </div>
            <div className="detail-item">
              <span className="detail-item-label">Added Date</span>
              <span className="detail-item-value">
                {product.createdDate || (product.createdAt ? product.createdAt.split('T')[0] : '—')}
              </span>
            </div>
          </div>

          {/* Description */}
          {product.description && (
            <div style={{ marginTop: '0.5rem' }}>
              <span className="detail-item-label" style={{ display: 'block', marginBottom: '0.35rem' }}>
                Description
              </span>
              <div style={{ fontSize: '0.9rem', color: '#cbd5e1', lineHeight: '1.5', background: 'rgba(15, 23, 42, 0.6)', padding: '0.75rem', borderRadius: '6px' }}>
                {product.description}
              </div>
            </div>
          )}

          {/* Configured Category Filter Values / Specifications */}
          <div style={{ marginTop: '0.75rem' }}>
            <h4 style={{ color: '#a78bfa', fontSize: '0.95rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.4rem', marginBottom: '0.75rem' }}>
              Hardware Specifications (Product Filter Values)
            </h4>

            {viewingFilterValues.length === 0 && (!product.specifications || Object.keys(product.specifications).length === 0) ? (
              <div style={{ padding: '0.75rem', color: 'var(--text-muted)', fontSize: '0.85rem', fontStyle: 'italic' }}>
                No dynamic specifications assigned to this product yet.
              </div>
            ) : (
              <div className="details-grid">
                {viewingFilterValues.map((fv) => {
                  const matchedFilter = viewingFilters.find((f) => f.filterKey === fv.filterKey || f.filterId === fv.filterId);
                  const label = matchedFilter?.displayName || fv.filterKey || `Filter #${fv.filterId}`;
                  const unit = matchedFilter?.unit;
                  return (
                    <div className="detail-item" key={fv.productFilterValueId || `${fv.filterId}-${fv.rawValue}`}>
                      <span className="detail-item-label">{label}</span>
                      <span className="detail-item-value" style={{ color: '#93c5fd' }}>
                        {fv.rawValue} {unit && !fv.rawValue.includes(unit) ? unit : ''}
                      </span>
                    </div>
                  );
                })}

                {/* Show fallback specs from JSON if not in relational values */}
                {product.specifications &&
                  typeof product.specifications === 'object' &&
                  Object.entries(product.specifications).map(([key, val]) => {
                    // Skip if already in viewingFilterValues
                    if (viewingFilterValues.some((fv) => fv.filterKey === key)) return null;
                    return (
                      <div className="detail-item" key={key}>
                        <span className="detail-item-label">{key.replace(/_/g, ' ')}</span>
                        <span className="detail-item-value" style={{ color: '#cbd5e1' }}>
                          {String(val)}
                        </span>
                      </div>
                    );
                  })}
              </div>
            )}
          </div>
        </div>

        <div className="modal-footer">
          <button
            type="button"
            onClick={() => {
              onClose();
              onEdit(product);
            }}
            className="btn btn-primary-sm"
          >
            Edit Product
          </button>
          <button type="button" onClick={onClose} className="btn btn-outline-sm">
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default ViewProductModal;
