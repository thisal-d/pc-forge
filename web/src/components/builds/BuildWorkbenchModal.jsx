import React from 'react';
import BuildStatusBadge from './BuildStatusBadge.jsx';
import BuildClearanceDiagnostics from './BuildClearanceDiagnostics.jsx';
import BuildBomTable from './BuildBomTable.jsx';
import { QUICK_NOTE_TEMPLATES } from '../../constants/buildConstants.js';
import { CloseIcon, PenLineIcon, AlertTriangleIcon, CheckIcon } from '../icons/index.js';

export const BuildWorkbenchModal = ({
  build,
  onClose,
  technicianNotes,
  onNotesChange,
  validationError,
  actionLoading,
  onAssignToMe,
  onStatusTransition,
}) => {
  if (!build) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '840px' }}
        onClick={(e) => e.stopPropagation()}
        id="build-inspection-modal"
      >
        {/* Modal Header */}
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <span className="id-badge">#{build.buildId}</span>
            <div>
              <h3 style={{ margin: 0, fontSize: '1.15rem' }}>{build.buildName}</h3>
              <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                Customer: {build.customerName || 'Alex Mercer'} ({build.customerEmail})
              </span>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <BuildStatusBadge status={build.status} />
            <button
              type="button"
              onClick={onClose}
              className="modal-close-btn"
              title="Close modal"
              aria-label="Close"
            >
              <CloseIcon size={16} />
            </button>
          </div>
        </div>

        {/* Modal Body */}
        <div className="modal-body" style={{ maxHeight: 'calc(85vh - 130px)' }}>
          {/* Customer Request Note */}
          {build.customerNotes && (
            <div
              style={{
                backgroundColor: 'var(--primary-light)',
                border: '1px solid var(--primary-border)',
                borderRadius: '8px',
                padding: '0.85rem 1.15rem',
              }}
            >
              <div style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--primary)', fontWeight: 700, marginBottom: '0.25rem' }}>
                Customer Inquiry / Special Request:
              </div>
              <div style={{ color: 'var(--text-main)', fontSize: '0.9rem', fontStyle: 'italic' }}>
                "{build.customerNotes}"
              </div>
            </div>
          )}

          {/* Automated Hardware Feasibility & Diagnostics */}
          <BuildClearanceDiagnostics build={build} />

          {/* Bill of Materials (BOM) Table */}
          <BuildBomTable components={build.components} />

          {/* Technical Clearance & Review Notes Card */}
          <div className="card" style={{ padding: '1rem', marginTop: '1rem', display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            <div style={{ display: 'flex', borderBottom: 'none', justifyContent: 'space-between', alignItems: 'center' }}>
              <h4 style={{ margin: 0, fontSize: '0.95rem', color: '#fff', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                <PenLineIcon size={16} /> Technical Clearance & Review Notes
              </h4>
            </div>

            <textarea
              rows="3"
              className={`form-control ${validationError ? 'input-error' : ''}`}
              placeholder="Record bench stress test results, BIOS flashing instructions, or explain why changes are required to the customer..."
              value={technicianNotes}
              onChange={(e) => onNotesChange(e.target.value)}
              id="technician-notes-textarea"
            />

            {validationError && (
              <span className="field-error-text">{validationError}</span>
            )}

            {/* Pre-fill Quick Notes Helpers */}
            <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
              <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Quick templates:</span>
              {QUICK_NOTE_TEMPLATES.map((tmpl) => (
                <button
                  key={tmpl.label}
                  type="button"
                  className="btn btn-outline-sm"
                  style={{ fontSize: '0.725rem', padding: '0.15rem 0.4rem' }}
                  onClick={() => onNotesChange(tmpl.text)}
                >
                  {tmpl.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Modal Footer with Review Decision Actions */}
        <div className="modal-footer">
          <button
            type="button"
            onClick={onClose}
            className="btn btn-outline"
            disabled={actionLoading}
          >
            Close
          </button>

          {build.status === 'Pending Staff Review' && (
            <button
              type="button"
              onClick={() => onStatusTransition('In Review by Staff')}
              className="btn btn-primary"
              disabled={actionLoading}
              id="start-review-btn"
            >
              {actionLoading ? 'Updating...' : 'Start Technical Review'}
            </button>
          )}

          <button
            type="button"
            onClick={() => onStatusTransition('Changes Requested')}
            className="btn btn-warning-sm"
            style={{ padding: '0.55rem 1rem', fontSize: '0.875rem', display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
            disabled={actionLoading}
            id="request-changes-btn"
          >
            {actionLoading ? (
              'Saving...'
            ) : (
              <>
                <AlertTriangleIcon size={14} /> Request Changes
              </>
            )}
          </button>

          <button
            type="button"
            onClick={() => onStatusTransition('Approved by Staff')}
            className="btn btn-success-sm"
            style={{ padding: '0.55rem 1.15rem', fontSize: '0.875rem', fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
            disabled={actionLoading}
            id="approve-build-btn"
          >
            {actionLoading ? (
              'Approving...'
            ) : (
              <>
                <CheckIcon size={14} /> Approve & Clear Build
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

export default BuildWorkbenchModal;
