import React from 'react';
import { CloseIcon } from '../icons/index.js';

export const AssignedFiltersList = ({
  filters,
  loading,
  onReorder,
  onToggleActive,
  onRemove,
}) => {
  return (
    <div style={{ marginBottom: '1.5rem' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.35rem' }}>
        <h4 style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-main)', margin: 0 }}>
          Assigned Filters
        </h4>
        <span
          style={{
            fontSize: '0.75rem',
            fontWeight: 600,
            padding: '0.2rem 0.6rem',
            borderRadius: '9999px',
            backgroundColor: '#eff6ff',
            color: 'var(--primary)',
            border: '1px solid #bfdbfe',
          }}
        >
          {filters.length} {filters.length === 1 ? 'Filter' : 'Filters'}
        </span>
      </div>
      <p style={{ fontSize: '0.825rem', color: 'var(--text-muted)', marginBottom: '0.85rem', lineHeight: 1.4 }}>
        Configure the order in which specifications appear on product forms and sidebar search filters.
      </p>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '1.5rem', color: 'var(--text-muted)', background: '#f8fafc', borderRadius: '8px', border: '1px dashed var(--border)' }}>
          Loading filters...
        </div>
      ) : filters.length === 0 ? (
        <div
          style={{
            padding: '1.25rem',
            background: '#f8fafc',
            borderRadius: '8px',
            border: '1px dashed #cbd5e1',
            textAlign: 'center',
            color: 'var(--text-muted)',
            fontSize: '0.85rem',
          }}
        >
          No dynamic filters assigned yet. Use the form below to assign your first specification filter.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
          {filters.map((filter, index) => {
            const isFirst = index === 0;
            const isLast = index === filters.length - 1;

            return (
              <div
                key={filter.filterId}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '0.75rem 1rem',
                  background: '#f8fafc',
                  border: '1px solid var(--border)',
                  borderRadius: '8px',
                  gap: '0.75rem',
                  boxShadow: '0 1px 2px rgba(0, 0, 0, 0.03)',
                }}
              >
                {/* Order and Filter Info */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                    <button
                      type="button"
                      disabled={isFirst}
                      onClick={() => onReorder(filter.filterId, 'up')}
                      style={{
                        background: isFirst ? 'transparent' : '#ffffff',
                        border: '1px solid ' + (isFirst ? 'transparent' : '#cbd5e1'),
                        borderRadius: '4px',
                        color: isFirst ? '#cbd5e1' : 'var(--primary)',
                        cursor: isFirst ? 'default' : 'pointer',
                        padding: '2px 5px',
                        fontSize: '0.7rem',
                        lineHeight: 1,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        boxShadow: isFirst ? 'none' : '0 1px 2px rgba(0,0,0,0.05)',
                      }}
                      title="Move filter up"
                    >
                      ▲
                    </button>
                    <button
                      type="button"
                      disabled={isLast}
                      onClick={() => onReorder(filter.filterId, 'down')}
                      style={{
                        background: isLast ? 'transparent' : '#ffffff',
                        border: '1px solid ' + (isLast ? 'transparent' : '#cbd5e1'),
                        borderRadius: '4px',
                        color: isLast ? '#cbd5e1' : 'var(--primary)',
                        cursor: isLast ? 'default' : 'pointer',
                        padding: '2px 5px',
                        fontSize: '0.7rem',
                        lineHeight: 1,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        boxShadow: isLast ? 'none' : '0 1px 2px rgba(0,0,0,0.05)',
                      }}
                      title="Move filter down"
                    >
                      ▼
                    </button>
                  </div>

                  <div style={{ minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.45rem', flexWrap: 'wrap' }}>
                      <strong style={{ fontSize: '0.9rem', color: 'var(--text-main)', fontWeight: 600 }}>
                        {filter.displayName}
                      </strong>
                      <span
                        style={{
                          fontSize: '0.7rem',
                          fontFamily: 'monospace',
                          background: '#e2e8f0',
                          color: '#334155',
                          padding: '0.15rem 0.45rem',
                          borderRadius: '4px',
                          fontWeight: 500,
                        }}
                      >
                        {filter.filterKey}
                      </span>
                      <span
                        style={{
                          fontSize: '0.7rem',
                          background: '#eff6ff',
                          color: '#2563eb',
                          border: '1px solid #bfdbfe',
                          padding: '0.15rem 0.45rem',
                          borderRadius: '4px',
                          fontWeight: 600,
                          textTransform: 'capitalize',
                        }}
                      >
                        {filter.filterType}
                      </span>
                      {filter.unit && (
                        <span
                          style={{
                            fontSize: '0.7rem',
                            background: '#f3e8ff',
                            color: '#7e22ce',
                            border: '1px solid #e9d5ff',
                            padding: '0.15rem 0.45rem',
                            borderRadius: '4px',
                            fontWeight: 500,
                          }}
                        >
                          Unit: {filter.unit}
                        </span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Filterable Toggle & Remove */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem', flexShrink: 0 }}>
                  <label
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.4rem',
                      fontSize: '0.8rem',
                      cursor: 'pointer',
                      fontWeight: 600,
                      color: filter.isFilterable ? '#16a34a' : 'var(--text-muted)',
                      userSelect: 'none',
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={!!filter.isFilterable}
                      onChange={() => onToggleActive(filter.filterId)}
                      style={{ cursor: 'pointer', accentColor: 'var(--primary)', width: '15px', height: '15px' }}
                    />
                    {filter.isFilterable ? 'Filterable' : 'Disabled'}
                  </label>

                  <button
                    type="button"
                    onClick={() => onRemove(filter.filterId, filter.displayName)}
                    className="btn-danger-sm"
                    style={{
                      padding: '0.25rem 0.6rem',
                      fontSize: '0.75rem',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.25rem',
                      borderRadius: '6px',
                    }}
                    title="Remove filter from this category"
                  >
                    <CloseIcon size={12} /> Remove
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default AssignedFiltersList;
