import React from 'react';
import { LockIcon } from '../icons/index.js';

export const TicketReplyForm = ({
  replyMessage,
  onReplyMessageChange,
  isInternalNote,
  onInternalNoteChange,
  submittingReply,
  onSubmit,
}) => {
  return (
    <form onSubmit={onSubmit} style={{ marginTop: '1rem' }}>
      <div style={{ marginBottom: '0.5rem' }}>
        <textarea
          id="ticket-reply-textarea"
          rows={3}
          placeholder={
            isInternalNote
              ? 'Write an internal diagnostics bench note (visible only to Technician Staff and Admin)...'
              : 'Send a diagnostic response or instruction to the customer...'
          }
          value={replyMessage}
          onChange={(e) => onReplyMessageChange(e.target.value)}
          style={{
            width: '100%',
            background: isInternalNote ? '#fffbeb' : '#ffffff',
            borderColor: isInternalNote ? 'var(--warning-border)' : 'var(--border)',
            color: 'var(--text-main)',
            borderRadius: '6px',
            padding: '0.75rem',
            fontSize: '0.85rem',
            resize: 'vertical',
          }}
        />
      </div>

      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '0.5rem',
        }}
      >
        <label
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.4rem',
            fontSize: '0.8rem',
            color: isInternalNote ? '#fbbf24' : 'var(--text-muted)',
            cursor: 'pointer',
            fontWeight: isInternalNote ? 600 : 400,
          }}
        >
          <input
            type="checkbox"
            checked={isInternalNote}
            onChange={(e) => onInternalNoteChange(e.target.checked)}
          />
          <LockIcon size={14} /> Mark as Internal Note (hidden from customer)
        </label>

        <button
          type="submit"
          disabled={submittingReply || !replyMessage.trim()}
          className={`btn ${
            isInternalNote ? 'btn-warning-sm' : 'btn-primary-sm'
          }`}
        >
          {submittingReply
            ? 'Posting...'
            : isInternalNote
            ? 'Log Bench Note'
            : 'Send Customer Update'}
        </button>
      </div>
    </form>
  );
};

export default TicketReplyForm;
