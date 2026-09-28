import React from 'react';
import TicketWarrantyCard from './TicketWarrantyCard.jsx';
import { PackageIcon } from '../icons/index.js';

export const TicketHardwareCard = ({ ticket }) => {
  return (
    <div className="card" style={{ background: '#131d2e', padding: '1rem' }}>
      <h4 style={{ fontSize: '0.9rem', marginBottom: '0.75rem', color: '#60a5fa', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
        <PackageIcon size={16} /> Order & Hardware Specifications
      </h4>
      <div className="details-grid">
        <div className="detail-item">
          <span className="detail-item-label">Order ID</span>
          <span className="detail-item-value">
            {ticket.orderId ? (
              <span style={{ color: '#93c5fd', fontWeight: 600 }}>
                Order #{ticket.orderId}
              </span>
            ) : (
              'Direct Inquiry'
            )}
          </span>
        </div>
        <div className="detail-item">
          <span className="detail-item-label">Order Date</span>
          <span className="detail-item-value">{ticket.orderDate || '—'}</span>
        </div>
        <div className="detail-item" style={{ gridColumn: 'span 2' }}>
          <span className="detail-item-label">Reported Component</span>
          <span className="detail-item-value" style={{ color: '#fff' }}>
            {ticket.productName || 'General System Issue'}
          </span>
        </div>
      </div>

      {/* Warranty Verification Card */}
      <TicketWarrantyCard ticket={ticket} />
    </div>
  );
};

export default TicketHardwareCard;
