import React from 'react';
import { CloseIcon } from '../icons/index.js';

export const AddCategoryModal = ({
  isOpen,
  onClose,
  formData,
  onFormChange,
  errors,
  submitting,
  onSubmit,
}) => {
  if (!isOpen) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()} id="add-category-modal">
        <div className="modal-header">
          <h3>Add New Category</h3>
          <button onClick={onClose} className="modal-close-btn">
            <CloseIcon size={16} />
          </button>
        </div>

        <form onSubmit={onSubmit}>
          <div className="modal-body">
            {errors.general && <div className="alert alert-error">{errors.general}</div>}

            <div className="form-group">
              <label htmlFor="add-cat-name">Category Name *</label>
              <input
                id="add-cat-name"
                name="name"
                type="text"
                placeholder="e.g. Graphics Cards (GPU)"
                value={formData.name}
                onChange={onFormChange}
                className={errors.name ? 'input-error' : ''}
              />
              {errors.name && <span className="field-error-text">{errors.name}</span>}
            </div>

            <div className="form-group">
              <label htmlFor="add-cat-desc">Description</label>
              <textarea
                id="add-cat-desc"
                name="description"
                rows="3"
                placeholder="Describe what components belong in this category..."
                value={formData.description}
                onChange={onFormChange}
              />
            </div>

            <div className="form-group">
              <label htmlFor="add-cat-status">Status</label>
              <select
                id="add-cat-status"
                name="status"
                value={formData.status}
                onChange={onFormChange}
              >
                <option value="Active">Active</option>
                <option value="Inactive">Inactive</option>
              </select>
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
              id="submit-add-cat-btn"
            >
              {submitting ? 'Saving Category...' : 'Save Category'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default AddCategoryModal;
