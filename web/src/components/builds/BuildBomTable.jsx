import React from 'react';
import { PackageIcon } from '../icons/index.js';

const getSlotBadge = (slot) => {
  const s = (slot || 'component').toLowerCase();
  return <span className={`slot-badge slot-badge-${s}`}>{slot}</span>;
};

export const BuildBomTable = ({ components }) => {
  return (
    <div>
      <h4 style={{ margin: '0 0 0.75rem 0', fontSize: '0.95rem', color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
        <PackageIcon size={16} /> Component Bill of Materials (BOM)
      </h4>
      <div style={{ border: '1px solid var(--border)', borderRadius: '6px', overflow: 'hidden' }}>
        <table className="bom-table">
          <thead>
            <tr>
              <th style={{ width: '90px' }}>Slot</th>
              <th>Component Description</th>
              <th>Key Specs</th>
              <th style={{ textAlign: 'right' }}>Price (LKR)</th>
              <th style={{ textAlign: 'center', width: '100px' }}>Inventory</th>
            </tr>
          </thead>
          <tbody>
            {components && components.length > 0 ? (
              components.map((c, idx) => (
                <tr key={idx}>
                  <td>{getSlotBadge(c.slotType)}</td>
                  <td>
                    <div className="bom-item-name">{c.productName}</div>
                    <div className="bom-item-spec">
                      Brand: {c.brand} {c.model ? `• Model: ${c.model}` : ''}
                    </div>
                  </td>
                  <td>
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-body)' }}>
                      {c.socket && <span>Socket {c.socket} • </span>}
                      {c.memoryType && <span>{c.memoryType} • </span>}
                      {c.powerWattage && <span>{c.powerWattage}W • </span>}
                      {c.vram && <span>VRAM: {c.vram} • </span>}
                      {c.efficiencyRating && <span>{c.efficiencyRating}</span>}
                    </div>
                  </td>
                  <td style={{ textAlign: 'right', fontWeight: 600, color: 'var(--text-main)' }}>
                    LKR {Number(c.price).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </td>
                  <td style={{ textAlign: 'center' }}>
                    {c.stockQuantity > 5 ? (
                      <span className="badge badge-success" style={{ fontSize: '0.7rem' }}>
                        In Stock ({c.stockQuantity})
                      </span>
                    ) : c.stockQuantity > 0 ? (
                      <span className="badge badge-warning" style={{ fontSize: '0.7rem' }}>
                        Low ({c.stockQuantity})
                      </span>
                    ) : (
                      <span className="badge badge-error" style={{ fontSize: '0.7rem' }}>
                        Out of Stock
                      </span>
                    )}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="5" style={{ textAlign: 'center', padding: '1rem', color: 'var(--text-muted)' }}>
                  No components registered in this build.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default BuildBomTable;
