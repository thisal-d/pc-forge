import React from 'react';
import SupportTableRow from './SupportTableRow.jsx';
import { TicketIcon } from '../icons/index.js';

export const SupportTable = ({
  filteredTickets,
  activeTicketId,
  onSelectTicket,
}) => {
  return (
    <div className="data-table-card">
      <div className="table-header-banner">
        <h3>Support Requests ({filteredTickets.length})</h3>
        <span className="table-header-subtitle">
          Showing {filteredTickets.length} support requests
        </span>
      </div>
      <div className="table-responsive">
        <table className="data-table">
          <thead>
            <tr>
              <th style={{ width: '90px' }}>Ticket ID</th>
              <th>Customer</th>
              <th>Subject & Category</th>
              <th style={{ width: '100px' }}>Priority</th>
              <th style={{ width: '130px' }}>Status</th>
              <th style={{ width: '120px' }}>Date</th>
              <th style={{ width: '140px', textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filteredTickets.length === 0 ? (
              <tr>
                <td colSpan="7">
                  <div className="empty-state">
                    <div className="empty-state-icon">
                      <TicketIcon size={40} />
                    </div>
                    <h4>No Support Tickets Found</h4>
                    <p>Try adjusting your search query or filters.</p>
                  </div>
                </td>
              </tr>
            ) : (
              filteredTickets.map((ticket) => (
                <SupportTableRow
                  key={ticket.ticketId}
                  ticket={ticket}
                  isActive={activeTicketId === ticket.ticketId}
                  onSelect={onSelectTicket}
                />
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default SupportTable;
