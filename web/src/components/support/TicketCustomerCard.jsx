import React from 'react';
import { UserIcon } from '../icons/index.js';

export const TicketCustomerCard = ({ ticket }) => {
  return (
    <div className="card" style={{ background: '#131d2e', padding: '1rem' }}>
      <h4 style={{ fontSize: '0.9rem', marginBottom: '0.75rem', color: '#60a5fa', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
        <UserIcon size={16} /> Customer Information
      </h4>
      <div className="details-grid">
        <div className="detail-item">
          <span className="detail-item-label">Customer Name</span>
          <span className="detail-item-value">{ticket.customerName}</span>
        </div>
        <div className="detail-item">
          <span className="detail-item-label">Email</span>
          <span className="detail-item-value" style={{ wordBreak: 'break-all' }}>
            {ticket.customerEmail}
          </span>
        </div>
        <div className="detail-item">
          <span className="detail-item-label">Phone</span>
          <span className="detail-item-value">{ticket.customerPhone || '—'}</span>
        </div>
        <div className="detail-item">
          <span className="detail-item-label">Customer ID</span>
          <span className="detail-item-value">User #{ticket.userId}</span>
        </div>
      </div>
    </div>
  );
};

export default TicketCustomerCard;
