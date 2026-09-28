import React from 'react';
import ProductImageUploader from './ProductImageUploader.jsx';
import ProductDynamicSpecs from './ProductDynamicSpecs.jsx';
import { CloseIcon } from '../icons/index.js';

export const EditProductModal = ({
  isOpen,
  onClose,
  product,
  categories,
  formData,
  onFormChange,
  errors,
  submitting,
  onSubmit,
  cloudinaryStatus,
  blobPreview,
  isUploadingImage,
  onImageFileChange,
  onImageUrlChange,
  onRemoveImage,
  categoryFilters,
  filterValues,
  filtersLoading,
  onDynamicFilterChange,
}) => {
  if (!isOpen || !product) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '680px' }}
        onClick={(e) => e.stopPropagation()}
        id="edit-product-modal"
      >
        <div className="modal-header">
          <h3>Edit Product: {product.name}</h3>
          <button onClick={onClose} className="modal-close-btn" title="Close modal">
            <CloseIcon size={16} />
          </button>
        </div>

        <form onSubmit={onSubmit}>
          <div className="modal-body" style={{ maxHeight: '72vh' }}>
            {errors.general && (
              <div className="alert alert-error">{errors.general}</div>
            )}

            {/* Common Product Information */}
            <h4 style={{ color: '#60a5fa', fontSize: '0.95rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.4rem' }}>
              1. Common Product Information
            </h4>

            <div className="form-group">
              <label htmlFor="edit-product-name">Product Name *</label>
              <input
                id="edit-product-name"
                name="name"
                type="text"
                value={formData.name}
                onChange={onFormChange}
                className={errors.name ? 'input-error' : ''}
              />
              {errors.name && <span className="field-error-text">{errors.name}</span>}
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="edit-product-category">Category *</label>
                <select
                  id="edit-product-category"
                  name="categoryId"
                  value={formData.categoryId}
                  onChange={onFormChange}
                  className={errors.categoryId ? 'input-error' : ''}
                >
                  <option value="">-- Select Category --</option>
                  {categories.map((cat) => (
                    <option key={cat.categoryId || cat.id} value={cat.categoryId || cat.id}>
                      {cat.name}
                    </option>
                  ))}
                </select>
                {errors.categoryId && <span className="field-error-text">{errors.categoryId}</span>}
              </div>

              <div className="form-group">
                <label htmlFor="edit-product-brand">Brand / Manufacturer *</label>
                <input
                  id="edit-product-brand"
                  name="brand"
                  type="text"
                  value={formData.brand}
                  onChange={onFormChange}
                  className={errors.brand ? 'input-error' : ''}
                />
                {errors.brand && <span className="field-error-text">{errors.brand}</span>}
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="edit-product-model">Model Number / SKU</label>
                <input
                  id="edit-product-model"
                  name="model"
                  type="text"
                  value={formData.model}
                  onChange={onFormChange}
                />
              </div>

              <div className="form-group">
                <label htmlFor="edit-product-status">Status</label>
                <select
                  id="edit-product-status"
                  name="status"
                  value={formData.status}
                  onChange={onFormChange}
                >
                  <option value="Active">Active</option>
                  <option value="Inactive">Inactive</option>
                </select>
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="edit-product-price">Price (LKR) *</label>
                <input
                  id="edit-product-price"
                  name="price"
                  type="number"
                  step="0.01"
                  min="0.01"
                  value={formData.price}
                  onChange={onFormChange}
                  className={errors.price ? 'input-error' : ''}
                />
                {errors.price && <span className="field-error-text">{errors.price}</span>}
              </div>

              <div className="form-group">
                <label htmlFor="edit-product-stock">Stock Quantity *</label>
                <input
                  id="edit-product-stock"
                  name="stockQuantity"
                  type="number"
                  min="0"
                  step="1"
                  value={formData.stockQuantity}
                  onChange={onFormChange}
                  className={errors.stockQuantity ? 'input-error' : ''}
                />
                {errors.stockQuantity && <span className="field-error-text">{errors.stockQuantity}</span>}
              </div>
            </div>

            <ProductImageUploader
              idPrefix="edit"
              imageUrl={formData.imageUrl}
              blobPreview={blobPreview}
              isUploading={isUploadingImage}
              cloudinaryStatus={cloudinaryStatus}
              onFileChange={onImageFileChange}
              onUrlChange={onImageUrlChange}
              onRemoveImage={onRemoveImage}
            />

            <div className="form-group">
              <label htmlFor="edit-product-description">Description</label>
              <textarea
                id="edit-product-description"
                name="description"
                rows="3"
                value={formData.description}
                onChange={onFormChange}
                style={{
                  background: '#ffffff',
                  border: '1px solid var(--border)',
                  color: 'var(--text-main)',
                  padding: '0.65rem 0.85rem',
                  borderRadius: '6px',
                  fontSize: '0.95rem',
                  outline: 'none',
                  resize: 'vertical',
                }}
              />
            </div>

            <ProductDynamicSpecs
              categoryId={formData.categoryId}
              filters={categoryFilters}
              filterValues={filterValues}
              loading={filtersLoading}
              onChange={onDynamicFilterChange}
              containerId="edit-dynamic-category-filters-container"
              titleColor="var(--primary)"
            />
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
              id="submit-edit-product-btn"
            >
              {submitting ? 'Updating Product...' : 'Update Product'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default EditProductModal;
