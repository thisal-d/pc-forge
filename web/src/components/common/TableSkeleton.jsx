import React from 'react';

/**
 * Reusable animated table skeleton placeholder loader.
 * Renders pulse skeleton rows matching column counts.
 */
export const TableSkeleton = ({ rows = 5, columns = 6 }) => {
  return (
    <tbody className="table-skeleton-body">
      {Array.from({ length: rows }).map((_, rIdx) => (
        <tr
          key={`skel-row-${rIdx}`}
          className="skeleton-row"
          style={{ borderBottom: '1px solid var(--border, #e2e8f0)' }}
        >
          {Array.from({ length: columns }).map((_, cIdx) => (
            <td key={`skel-col-${cIdx}`} style={{ padding: '1rem', verticalAlign: 'middle' }}>
              <div
                style={{
                  height: '0.95rem',
                  borderRadius: '4px',
                  backgroundColor: 'rgba(148, 163, 184, 0.25)',
                  animation: 'skeleton-pulse 1.4s ease-in-out infinite',
                  width:
                    cIdx === 0
                      ? '45%'
                      : cIdx === 1
                      ? '85%'
                      : cIdx === columns - 1
                      ? '50%'
                      : '65%',
                }}
              />
            </td>
          ))}
        </tr>
      ))}
    </tbody>
  );
};

export default TableSkeleton;
