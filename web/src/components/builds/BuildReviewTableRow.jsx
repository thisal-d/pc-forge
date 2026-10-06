import React from 'react';
import BuildStatusBadge from './BuildStatusBadge.jsx';
import { CheckIcon, AlertTriangleIcon } from '../icons/index.js';

export const BuildReviewTableRow = ({ build, onInspect }) => {
  const psu = build.components?.find((c) => c.slotType?.toLowerCase() === 'psu');
  const psuWattage = psu?.powerWattage || 0;
  const estimated = build.estimatedWattage || 0;
  const headroom = psuWattage > 0 ? psuWattage - estimated : null;
  const headroomPercent = psuWattage > 0 ? Math.round((headroom / psuWattage) * 100) : null;

  return (
    <tr id={`build-row-${build.buildId}`}>
      <td>
        <span className="id-badge">#{build.buildId}</span>
      </td>
      <td>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontWeight: 600, color: 'var(--text-main)' }}>{build.buildName}</span>
          <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
            {build.customerName || 'Customer'} • {build.customerEmail}
          </span>
          {build.customerNotes && (
            <span
              style={{
                fontSize: '0.75rem',
                color: 'var(--primary)',
                fontStyle: 'italic',
                marginTop: '0.2rem',
                maxWidth: '340px',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
              title={build.customerNotes}
            >
              Note: "{build.customerNotes}"
            </span>
          )}
        </div>
      </td>
      <td>
        <span style={{ fontWeight: 700, color: 'var(--text-main)' }}>
          LKR {Number(build.totalPrice).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </span>
        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          {build.components?.length || 0} Components
        </div>
      </td>
      <td>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
          <span style={{ fontWeight: 600, color: 'var(--text-main)' }}>
            {estimated}W <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>/ {psuWattage > 0 ? `${psuWattage}W PSU` : 'No PSU'}</span>
          </span>
          {headroom != null && (
            <span
              style={{
                fontSize: '0.75rem',
                fontWeight: 600,
                color: headroom < 0 ? '#f87171' : headroom < 100 ? '#fbbf24' : '#34d399',
              }}
            >
              {headroom >= 0 ? `+${headroom}W (${headroomPercent}%) Headroom` : `${headroom}W Deficit!`}
            </span>
          )}
        </div>
      </td>
      <td>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
          {build.clearancePassed ? (
            <span className="badge badge-success" style={{ fontSize: '0.75rem', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
              <CheckIcon size={12} /> Cleared
            </span>
          ) : (
            <span className="badge badge-error" style={{ fontSize: '0.75rem', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
              <AlertTriangleIcon size={12} /> Issue Detected
            </span>
          )}
        </div>
      </td>
      <td><BuildStatusBadge status={build.status} /></td>
      <td style={{ textAlign: 'right' }}>
        <button
          type="button"
          onClick={() => onInspect(build)}
          className="btn btn-outline-sm"
          id={`inspect-build-btn-${build.buildId}`}
          style={{ borderColor: 'var(--primary-border)', color: 'var(--primary)' }}
        >
          Inspect & Review →
        </button>
      </td>
    </tr>
  );
};

export default BuildReviewTableRow;
