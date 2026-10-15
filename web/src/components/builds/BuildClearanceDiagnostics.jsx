import React from 'react';
import { ZapIcon, CheckIcon, AlertTriangleIcon, CloseIcon } from '../icons/index.js';

export const BuildClearanceDiagnostics = ({ build }) => {
  const psu = build.components?.find((c) => c.slotType?.toLowerCase() === 'psu');
  const cpu = build.components?.find((c) => c.slotType?.toLowerCase() === 'cpu');
  const mobo = build.components?.find((c) => c.slotType?.toLowerCase() === 'motherboard');
  const ram = build.components?.find((c) => c.slotType?.toLowerCase() === 'ram');

  const psuWattage = psu?.powerWattage || 0;
  const est = build.estimatedWattage || 0;
  const headroom = psuWattage - est;
  const headroomPercent = psuWattage > 0 ? Math.round((headroom / psuWattage) * 100) : 0;
  const isSafe = headroom >= 100;
  const isDeficit = headroom < 0;

  const socketMatch = build.isSocketCompatible ?? (
    cpu?.socket && mobo?.socket
      ? cpu.socket.trim().toLowerCase() === mobo.socket.trim().toLowerCase()
      : (build.socketMatch !== false)
  );

  const memoryMatch = build.isMemoryCompatible ?? (
    mobo?.memoryType && ram?.memoryType
      ? mobo.memoryType.trim().toLowerCase() === ram.memoryType.trim().toLowerCase()
      : (build.memoryMatch !== false)
  );

  const isChangesRequested = build.status === 'Changes Requested' || (build.status || '').toLowerCase().includes('change');
  const clearancePassed = build.clearancePassed !== undefined
    ? build.clearancePassed
    : (!isChangesRequested && socketMatch && memoryMatch && !isDeficit);

  return (
    <div className="clearance-panel">
      <div className="clearance-header">
        <div>
          <h4 style={{ margin: 0, fontSize: '0.95rem', color: '#fff', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
            <ZapIcon size={16} /> Automated Hardware Clearance Diagnostics
          </h4>
          <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            Pre-assembly socket, memory bus, and thermal headroom verification
          </span>
        </div>
        <span
          className={`badge ${
            clearancePassed ? 'badge-success' : 'badge-error'
          }`}
          style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
        >
          {clearancePassed ? (
            <>
              <CheckIcon size={12} /> SYSTEM PASS
            </>
          ) : isChangesRequested ? (
            <>
              <AlertTriangleIcon size={12} /> CHANGES REQUESTED
            </>
          ) : (
            <>
              <AlertTriangleIcon size={12} /> CLEARANCE WARNING
            </>
          )}
        </span>
      </div>

      <div className="clearance-grid">
        {/* Socket Check */}
        <div className={`clearance-item ${socketMatch ? 'pass' : 'fail'}`}>
          <span className="clearance-title">CPU & Socket</span>
          <span className={`clearance-status ${socketMatch ? 'pass' : 'fail'}`} style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
            {socketMatch ? (
              <>
                <CheckIcon size={12} /> Socket Match
              </>
            ) : (
              <>
                <CloseIcon size={12} /> Mismatched
              </>
            )}
          </span>
          <span className="clearance-sub">
            {cpu?.socket || 'N/A'} Socket Interface
          </span>
        </div>

        {/* RAM Check */}
        <div className={`clearance-item ${memoryMatch ? 'pass' : 'fail'}`}>
          <span className="clearance-title">RAM & Memory Bus</span>
          <span className={`clearance-status ${memoryMatch ? 'pass' : 'fail'}`} style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
            {memoryMatch ? (
              <>
                <CheckIcon size={12} /> Bus Match
              </>
            ) : (
              <>
                <CloseIcon size={12} /> Incompatible
              </>
            )}
          </span>
          <span className="clearance-sub">
            {ram?.memoryType || 'DDR5'} Standard
          </span>
        </div>

        {/* PSU Headroom Check */}
        <div className={`clearance-item ${!isDeficit ? 'pass' : 'fail'}`}>
          <span className="clearance-title">PSU Transient Headroom</span>
          <span className={`clearance-status ${!isDeficit ? 'pass' : 'fail'}`}>
            {!isDeficit ? `+${headroom}W Headroom` : `${headroom}W Deficit!`}
          </span>
          <span className="clearance-sub">
            {est}W Peak Load / {psuWattage}W Rating ({headroomPercent}%)
          </span>

          <div className="power-meter-container">
            <div className="power-meter-bar">
              <div
                className={`power-meter-fill ${
                  isDeficit
                    ? 'power-fill-danger'
                    : isSafe
                    ? 'power-fill-safe'
                    : 'power-fill-warn'
                }`}
                style={{ width: `${Math.min(100, Math.max(10, (est / (psuWattage || 1)) * 100))}%` }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default BuildClearanceDiagnostics;
