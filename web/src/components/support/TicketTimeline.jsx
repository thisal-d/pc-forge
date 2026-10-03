import React from 'react';
import { MessageSquareIcon, UserIcon, ToolsIcon, SettingsIcon, LockIcon } from '../icons/index.js';

export const TicketTimeline = ({ timeline, onZoomPhoto }) => {
  return (
    <>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '0.75rem',
        }}
      >
        <h4 style={{ fontSize: '0.9rem', color: '#60a5fa', margin: 0, display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
          <MessageSquareIcon size={16} /> Investigation Timeline & Customer Updates
        </h4>
        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          {timeline?.length || 0} entries
        </span>
      </div>

      <div className="timeline-list">
        {timeline && timeline.length > 0 ? (
          timeline.map((item) => {
            const isCustomer = item.sender === 'Customer';
            const isTech = item.sender === 'Technician';

            return (
              <div
                key={item.id}
                className={`timeline-entry ${
                  item.isInternal
                    ? 'timeline-entry-internal'
                    : isCustomer
                    ? 'timeline-entry-customer'
                    : isTech
                    ? 'timeline-entry-technician'
                    : 'timeline-entry-system'
                }`}
              >
                <div className="timeline-header">
                  <span className="timeline-author" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
                    {isCustomer ? <UserIcon size={14} /> : isTech ? <ToolsIcon size={14} /> : <SettingsIcon size={14} />} {item.senderName}
                    {item.isInternal && (
                      <span className="internal-note-tag" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
                        <LockIcon size={12} /> Internal Bench Note
                      </span>
                    )}
                  </span>
                  <span className="timeline-time">
                    {new Date(item.timestamp).toLocaleTimeString([], {
                      hour: '2-digit',
                      minute: '2-digit',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </span>
                </div>

                <div className="timeline-body">{item.message}</div>

                {item.attachmentUrl && (
                  <div style={{ marginTop: '0.5rem' }}>
                    <button
                      type="button"
                      onClick={() => onZoomPhoto(item.attachmentUrl)}
                      style={{
                        background: 'none',
                        border: 'none',
                        color: '#60a5fa',
                        fontSize: '0.775rem',
                        cursor: 'pointer',
                        padding: 0,
                        textDecoration: 'underline',
                      }}
                    >
                      View attached photo proof
                    </button>
                  </div>
                )}
              </div>
            );
          })
        ) : (
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            No messages yet.
          </p>
        )}
      </div>
    </>
  );
};

export default TicketTimeline;
