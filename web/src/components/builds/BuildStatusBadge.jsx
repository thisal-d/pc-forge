import React from 'react';
import { HourglassIcon, WrenchIcon, CheckIcon, AlertTriangleIcon } from '../icons/index.js';

export const BuildStatusBadge = ({ status }) => {
  switch (status) {
    case 'Pending Staff Review':
      return (
        <span className="badge badge-build-pending" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
          <HourglassIcon size={12} /> Pending Review
        </span>
      );
    case 'In Review by Staff':
      return (
        <span className="badge badge-build-reviewing" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
          <WrenchIcon size={12} /> In Review
        </span>
      );
    case 'Approved by Staff':
      return (
        <span className="badge badge-build-approved" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
          <CheckIcon size={12} /> Approved
        </span>
      );
    case 'Changes Requested':
      return (
        <span className="badge badge-build-rejected" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
          <AlertTriangleIcon size={12} /> Changes Req.
        </span>
      );
    default:
      return <span className="badge">{status}</span>;
  }
};

export default BuildStatusBadge;
