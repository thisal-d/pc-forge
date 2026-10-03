import React from 'react';
import { ISSUE_TYPES, PRIORITY_OPTIONS } from '../../constants/ticketConstants.js';
import { CloseIcon } from '../icons/index.js';

export const CreateTicketModal = ({
  isOpen,
  onClose,
  formData,
  onFormChange,
  submitting,
  onSubmit,
}) => {
  if (!isOpen) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '600px' }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="modal-header">
          <h3>+ Open New Support Ticket</h3>
          <button onClick={onClose} className="modal-close-btn">
            <CloseIcon size={16} />
          </button>
        </div>

        <form onSubmit={onSubmit}>
          <div className="modal-body">
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="create-cust-name">Customer Name *</label>
                <input
                  id="create-cust-name"
                  type="text"
                  required
                  placeholder="e.g. Alex Mercer"
                  value={formData.customerName}
                  onChange={(e) =>
                    onFormChange({ ...formData, customerName: e.target.value })
                  }
                />
              </div>
              <div className="form-group">
                <label htmlFor="create-cust-email">Customer Email *</label>
                <input
                  id="create-cust-email"
                  type="email"
                  required
                  placeholder="customer@example.com"
                  value={formData.customerEmail}
                  onChange={(e) =>
                    onFormChange({ ...formData, customerEmail: e.target.value })
                  }
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="create-order-id">Order ID (Optional)</label>
                <input
                  id="create-order-id"
                  type="number"
                  placeholder="e.g. 1001"
                  value={formData.orderId}
                  onChange={(e) =>
                    onFormChange({ ...formData, orderId: e.target.value })
                  }
                />
              </div>
              <div className="form-group">
                <label htmlFor="create-phone">Phone Number</label>
                <input
                  id="create-phone"
                  type="text"
                  placeholder="+94 77 123 4567"
                  value={formData.customerPhone}
                  onChange={(e) =>
                    onFormChange({ ...formData, customerPhone: e.target.value })
                  }
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="create-issue-type">Issue Category</label>
                <select
                  id="create-issue-type"
                  value={formData.issueType}
                  onChange={(e) =>
                    onFormChange({ ...formData, issueType: e.target.value })
                  }
                >
                  {ISSUE_TYPES.map((type) => (
                    <option key={type} value={type}>
                      {type}
                    </option>
                  ))}
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="create-priority">Priority</label>
                <select
                  id="create-priority"
                  value={formData.priority}
                  onChange={(e) =>
                    onFormChange({ ...formData, priority: e.target.value })
                  }
                >
                  {PRIORITY_OPTIONS.map((p) => (
                    <option key={p} value={p}>
                      {p}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="create-product-name">Reported Component / Product</label>
              <input
                id="create-product-name"
                type="text"
                placeholder="e.g. ASUS TUF GeForce RTX 4070 Ti"
                value={formData.productName}
                onChange={(e) =>
                  onFormChange({ ...formData, productName: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label htmlFor="create-subject">Ticket Subject *</label>
              <input
                id="create-subject"
                type="text"
                required
                placeholder="Brief summary of the issue"
                value={formData.subject}
                onChange={(e) =>
                  onFormChange({ ...formData, subject: e.target.value })
                }
              />
            </div>

            <div className="form-group">
              <label htmlFor="create-desc">Detailed Description *</label>
              <textarea
                id="create-desc"
                required
                rows={3}
                placeholder="Describe symptoms, troubleshooting steps, and customer report..."
                value={formData.description}
                onChange={(e) =>
                  onFormChange({ ...formData, description: e.target.value })
                }
                style={{ resize: 'vertical' }}
              />
            </div>

            <div className="form-group">
              <label htmlFor="create-attachment">Attachment / Photo URL (Optional)</label>
              <input
                id="create-attachment"
                type="url"
                placeholder="https://..."
                value={formData.attachmentUrl}
                onChange={(e) =>
                  onFormChange({ ...formData, attachmentUrl: e.target.value })
                }
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
              disabled={submitting}
              className="btn btn-primary-sm"
            >
              {submitting ? 'Creating...' : '+ Create Ticket'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CreateTicketModal;
