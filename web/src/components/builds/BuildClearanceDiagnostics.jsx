import React from 'react';
import { ZapIcon, CheckIcon, AlertTriangleIcon, CloseIcon } from '../icons/index.js';

export const BuildClearanceDiagnostics = ({ build }) => {
  const psu = build.components?.find((c) => c.slotType?.toLowerCase() === 'psu');
  const psuWattage = psu?.powerWattage || 0;
  const est = build.estimatedWattage || 0;
  const headroom = psuWattage - est;
  const headroomPercent = psuWattage > 0 ? Math.round((headroom / psuWattage) * 100) : 0;
  const isSafe = headroom >= 100;
  const isDeficit = headroom < 0;

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
            build.clearancePassed ? 'badge-success' : 'badge-error'
          }`}
          style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
        >
          {build.clearancePassed ? (
            <>
              <CheckIcon size={12} /> SYSTEM PASS
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
        <div className={`clearance-item ${build.socketMatch !== false ? 'pass' : 'fail'}`}>
          <span className="clearance-title">CPU & Socket</span>
          <span className={`clearance-status ${build.socketMatch !== false ? 'pass' : 'fail'}`} style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
            {build.socketMatch !== false ? (
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
            {build.components?.find((c) => c.slotType === 'cpu')?.socket || 'N/A'} Socket Interface
          </span>
        </div>

        {/* RAM Check */}
        <div className={`clearance-item ${build.memoryMatch !== false ? 'pass' : 'fail'}`}>
          <span className="clearance-title">RAM & Memory Bus</span>
          <span className={`clearance-status ${build.memoryMatch !== false ? 'pass' : 'fail'}`} style={{ display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}>
            {build.memoryMatch !== false ? (
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
            {build.components?.find((c) => c.slotType === 'ram')?.memoryType || 'DDR5'} Standard
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
