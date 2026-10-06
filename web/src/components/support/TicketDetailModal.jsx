import React from 'react';
import { PRIORITY_OPTIONS } from '../../constants/ticketConstants.js';
import TicketCustomerCard from './TicketCustomerCard.jsx';
import TicketHardwareCard from './TicketHardwareCard.jsx';
import TicketTimeline from './TicketTimeline.jsx';
import TicketReplyForm from './TicketReplyForm.jsx';
import {
  TagIcon,
  CloseIcon,
  SearchIcon,
  ZapIcon,
  CheckIcon,
  LockIcon,
  UnlockIcon,
  CameraIcon,
  WrenchIcon,
} from '../icons/index.js';

const getPriorityBadgeClass = (priority) => {
  switch (priority) {
    case 'Urgent':
      return 'badge badge-priority-urgent';
    case 'High':
      return 'badge badge-priority-high';
    case 'Normal':
      return 'badge badge-priority-normal';
    case 'Low':
      return 'badge badge-priority-low';
    default:
      return 'badge';
  }
};

const getStatusBadgeClass = (status) => {
  switch (status) {
    case 'Open':
      return 'badge badge-status-open';
    case 'In Review':
      return 'badge badge-status-in-review';
    case 'RMA Approved':
      return 'badge badge-status-rma-approved';
    case 'Resolved':
      return 'badge badge-status-resolved';
    case 'Closed':
      return 'badge badge-status-closed';
    default:
      return 'badge';
  }
};

export const TicketDetailModal = ({
  ticket,
  onClose,
  onUpdateStatus,
  onOpenRmaModal,
  onUpdatePriority,
  technicians,
  onAssignTechnician,
  onZoomPhoto,
  replyMessage,
  onReplyMessageChange,
  isInternalNote,
  onInternalNoteChange,
  submittingReply,
  onSendReply,
}) => {
  if (!ticket) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-dialog"
        style={{ maxWidth: '860px' }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div className="modal-header">
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <span className="id-badge" style={{ fontSize: '0.9rem' }}>
                #{ticket.ticketId}
              </span>
              <span className={getStatusBadgeClass(ticket.status)}>
                {ticket.status}
              </span>
              <span className={getPriorityBadgeClass(ticket.priority)}>
                {ticket.priority} Priority
              </span>
              {ticket.rmaNumber && (
                <span className="rma-badge" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
                  <TagIcon size={12} /> {ticket.rmaNumber}
                </span>
              )}
            </div>
            <h3 style={{ marginTop: '0.35rem', color: '#fff' }}>
              {ticket.subject}
            </h3>
          </div>

          <button
            type="button"
            onClick={onClose}
            className="modal-close-btn"
            title="Close"
            aria-label="Close"
          >
            <CloseIcon size={16} />
          </button>
        </div>

        {/* Modal Body */}
        <div className="modal-body" style={{ maxHeight: 'calc(90vh - 140px)', gap: '1.25rem' }}>
          {/* Technician Operational Action Bar */}
          <div className="ticket-actions-bar">
            <span
              style={{
                fontSize: '0.775rem',
                fontWeight: 700,
                textTransform: 'uppercase',
                color: 'var(--text-muted)',
                marginRight: '0.25rem',
              }}
            >
              Quick Actions:
            </span>

            {ticket.status === 'Open' && (
              <button
                type="button"
                className="btn-warning-sm"
                onClick={() => onUpdateStatus(ticket.ticketId, 'In Review')}
                style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
              >
                <SearchIcon size={14} /> Mark In Review
              </button>
            )}

            {ticket.status !== 'RMA Approved' &&
              ticket.status !== 'Resolved' &&
              ticket.status !== 'Closed' && (
                <button
                  type="button"
                  className="btn btn-primary-sm"
                  style={{ background: '#d97706', borderColor: '#f59e0b', display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
                  onClick={onOpenRmaModal}
                >
                  <ZapIcon size={14} /> Authorize RMA & Return Label
                </button>
              )}

            {ticket.status !== 'Resolved' && ticket.status !== 'Closed' && (
              <button
                type="button"
                className="btn-success-sm"
                onClick={() => onUpdateStatus(ticket.ticketId, 'Resolved')}
                style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
              >
                <CheckIcon size={14} /> Resolve Ticket
              </button>
            )}

            {ticket.status === 'Resolved' && (
              <button
                type="button"
                className="btn btn-outline-sm"
                onClick={() => onUpdateStatus(ticket.ticketId, 'Closed')}
                style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
              >
                <LockIcon size={14} /> Close Ticket
              </button>
            )}

            {ticket.status === 'Closed' && (
              <button
                type="button"
                className="btn btn-outline-sm"
                onClick={() => onUpdateStatus(ticket.ticketId, 'Open')}
                style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
              >
                <UnlockIcon size={14} /> Re-Open Ticket
              </button>
            )}

            {/* Priority Selector */}
            <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <label htmlFor="change-priority-select" style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                Priority:
              </label>
              <select
                id="change-priority-select"
                value={ticket.priority}
                onChange={(e) => onUpdatePriority(ticket.ticketId, e.target.value)}
                style={{
                  background: '#ffffff',
                  color: 'var(--text-main)',
                  border: '1px solid var(--border)',
                  borderRadius: '4px',
                  padding: '0.2rem 0.5rem',
                  fontSize: '0.8rem',
                }}
              >
                {PRIORITY_OPTIONS.map((p) => (
                  <option key={p} value={p}>
                    {p}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Grid: Left Column | Right Column */}
          <div className="grid grid-2" style={{ gap: '1.25rem', alignItems: 'start' }}>
            {/* Left Column */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <TicketCustomerCard ticket={ticket} />
              <TicketHardwareCard ticket={ticket} />

              {/* Photo Proof / Error Screen Inspector */}
              {ticket.attachmentUrl && (
                <div className="card" style={{ background: '#131d2e', padding: '1rem' }}>
                  <h4 style={{ fontSize: '0.9rem', marginBottom: '0.6rem', color: '#60a5fa', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                    <CameraIcon size={16} /> Customer Uploaded Error Proof
                  </h4>
                  <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '0.75rem' }}>
                    Photo uploaded from Customer Mobile App for Scenario 3 diagnostics:
                  </p>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                    <div
                      className="attachment-preview-box"
                      onClick={() => onZoomPhoto(ticket.attachmentUrl)}
                      title="Click to zoom inspect"
                    >
                      <img src={ticket.attachmentUrl} alt="Error screenshot" />
                      <div className="attachment-zoom-overlay" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.35rem' }}>
                        <SearchIcon size={14} /> Zoom View
                      </div>
                    </div>
                    <div style={{ fontSize: '0.8rem', color: '#cbd5e1' }}>
                      <div><strong>Proof Type:</strong> Thermal / Crash Screenshot</div>
                      <button
                        type="button"
                        onClick={() => onZoomPhoto(ticket.attachmentUrl)}
                        className="btn btn-outline-sm"
                        style={{ marginTop: '0.4rem' }}
                      >
                        Inspect Full Size
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Right Column: Conversation, Timeline, & Internal Bench Notes */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div className="card" style={{ background: '#131d2e', padding: '1rem' }}>
                <TicketTimeline
                  timeline={ticket.timeline}
                  onZoomPhoto={onZoomPhoto}
                />

                <TicketReplyForm
                  replyMessage={replyMessage}
                  onReplyMessageChange={onReplyMessageChange}
                  isInternalNote={isInternalNote}
                  onInternalNoteChange={onInternalNoteChange}
                  submittingReply={submittingReply}
                  onSubmit={onSendReply}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="modal-footer" style={{ justifyContent: 'space-between' }}>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
            Opened on {new Date(ticket.createdAt).toLocaleString()}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="btn btn-primary-sm"
          >
            Close Ticket View
          </button>
        </div>
      </div>
    </div>
  );
};

export default TicketDetailModal;
