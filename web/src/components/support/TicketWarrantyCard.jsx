import React from 'react';
import { ShieldCheckIcon, AlertTriangleIcon } from '../icons/index.js';

export const TicketWarrantyCard = ({ ticket }) => {
  const isActive = ticket.warrantyStatus === 'Active';

  return (
    <div style={{ marginTop: '0.85rem' }}>
      <div className={`warranty-card ${isActive ? '' : 'warranty-card-expired'}`}>
        <div>
          <div style={{ fontWeight: 600, fontSize: '0.85rem', color: '#fff', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
            {isActive ? (
              <>
                <ShieldCheckIcon size={16} /> Warranty Valid & Active
              </>
            ) : (
              <>
                <AlertTriangleIcon size={16} /> Warranty Status: Inactive
              </>
            )}
          </div>
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            {isActive
              ? `Coverage guaranteed until ${ticket.warrantyExpiresDate} (Manufacturer 3-Year Protection)`
              : 'Standard 30-day return policy expired.'}
          </div>
        </div>
        <span className={`badge ${isActive ? 'badge-success' : 'badge-error'}`}>
          {ticket.warrantyStatus}
        </span>
      </div>
    </div>
  );
};

export default TicketWarrantyCard;
