import React from 'react';
import { CameraIcon } from '../icons/index.js';

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

export const SupportTableRow = ({
  ticket,
  isActive,
  onSelect,
}) => {
  return (
    <tr
      style={{
        cursor: 'pointer',
        background: isActive ? 'rgba(37, 99, 235, 0.08)' : undefined,
      }}
      onClick={() => onSelect(ticket.ticketId)}
    >
      <td>
        <span className="id-badge">#{ticket.ticketId}</span>
        {ticket.rmaNumber && (
          <span
            className="rma-badge"
            style={{ display: 'block', marginTop: '0.2rem', fontSize: '0.65rem' }}
          >
            {ticket.rmaNumber}
          </span>
        )}
      </td>

      <td>
        <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>
          {ticket.customerName}
        </div>
        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          {ticket.customerEmail}
        </div>
      </td>

      <td>
        <div
          style={{
            fontWeight: 500,
            maxWidth: '220px',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {ticket.subject}
        </div>
        <div style={{ display: 'flex', gap: '0.4rem', marginTop: '0.2rem' }}>
          <span className="cat-pill" style={{ fontSize: '0.65rem', padding: '0.1rem 0.4rem' }}>
            {ticket.issueType}
          </span>
          {ticket.attachmentUrl && (
            <span
              className="badge"
              style={{
                fontSize: '0.65rem',
                padding: '0.1rem 0.35rem',
                background: 'rgba(99, 102, 241, 0.2)',
                color: '#a5b4fc',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.25rem',
              }}
            >
              <CameraIcon size={12} /> Photo
            </span>
          )}
        </div>
      </td>

      <td>
        <span className={getPriorityBadgeClass(ticket.priority)}>
          {ticket.priority}
        </span>
      </td>

      <td>
        <span className={getStatusBadgeClass(ticket.status)}>
          {ticket.status}
        </span>
      </td>

      <td style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
        {new Date(ticket.createdAt).toLocaleDateString([], {
          month: 'short',
          day: 'numeric',
        })}
      </td>

      <td>
        <div className="action-btn-group" style={{ justifyContent: 'flex-end' }}>
          <button
            type="button"
            className="btn btn-outline-sm"
            onClick={(e) => {
              e.stopPropagation();
              onSelect(ticket.ticketId);
            }}
          >
            Inspect & Resolve →
          </button>
        </div>
      </td>
    </tr>
  );
};

export default SupportTableRow;
