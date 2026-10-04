import React from 'react';
import { Link } from 'react-router-dom';

export const AddFilterForm = ({
  selectedPoolFilterKey,
  onSelectedPoolFilterKeyChange,
  availableFiltersPool,
  assignedFilters,
  onSubmit,
}) => {
  const selectedFilter = (availableFiltersPool || []).find(
    (f) => (f.filterKey || '').toLowerCase() === (selectedPoolFilterKey || '').toLowerCase()
  );

  return (
    <div
      style={{
        background: '#ffffff',
        padding: '1.25rem',
        borderRadius: '8px',
        border: '1px solid var(--border)',
        boxShadow: '0 1px 3px rgba(0, 0, 0, 0.04)',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.85rem' }}>
        <div>
          <h4 style={{ fontSize: '0.95rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
            Assign Database Filter
          </h4>
          <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            Select an existing specification filter from the database to add to this category
          </span>
        </div>
        <Link
          to="/filters"
          style={{
            fontSize: '0.78rem',
            color: 'var(--primary)',
            fontWeight: 600,
            textDecoration: 'none',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.25rem',
          }}
        >
          Manage Master Filters →
        </Link>
      </div>

      <form onSubmit={onSubmit}>
        <div className="form-group" style={{ marginBottom: '1rem' }}>
          <label
            htmlFor="pool-filter-select"
            style={{
              display: 'block',
              fontSize: '0.825rem',
              fontWeight: 600,
              color: 'var(--text-main)',
              marginBottom: '0.4rem',
            }}
          >
            Select Filter from Database:
          </label>
          <select
            id="pool-filter-select"
            value={selectedPoolFilterKey}
            onChange={(e) => onSelectedPoolFilterKeyChange(e.target.value)}
            style={{
              background: '#ffffff',
              color: 'var(--text-main)',
              border: '1px solid var(--border)',
              borderRadius: '6px',
              padding: '0.6rem 0.85rem',
              fontSize: '0.875rem',
              width: '100%',
            }}
          >
            <option value="">-- Choose a Database Filter --</option>
            {(availableFiltersPool || []).map((f) => {
              const isAlreadyAssigned = (assignedFilters || []).some(
                (af) => (af.filterKey || '').toLowerCase() === (f.filterKey || '').toLowerCase()
              );
              return (
                <option
                  key={f.filterKey || f.filterId}
                  value={f.filterKey}
                  disabled={isAlreadyAssigned}
                >
                  {f.displayName} ({f.filterKey}) {f.unit ? `[${f.unit}]` : ''}{' '}
                  {isAlreadyAssigned ? '— (Already Assigned)' : ''}
                </option>
              );
            })}
          </select>
        </div>

        {/* Selected Filter Preview Card */}
        {selectedFilter && (
          <div
            style={{
              background: '#f8fafc',
              border: '1px solid #e2e8f0',
              borderRadius: '6px',
              padding: '0.85rem 1rem',
              marginBottom: '1rem',
              fontSize: '0.825rem',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.4rem' }}>
              <div>
                <strong>{selectedFilter.displayName}</strong>{' '}
                <code style={{ fontSize: '0.75rem', color: '#64748b' }}>({selectedFilter.filterKey})</code>
              </div>
              <span
                style={{
                  background: '#eff6ff',
                  border: '1px solid #bfdbfe',
                  color: '#1d4ed8',
                  padding: '2px 8px',
                  borderRadius: '10px',
                  fontSize: '0.72rem',
                  fontWeight: 600,
                  textTransform: 'capitalize',
                }}
              >
                {selectedFilter.filterType}
              </span>
            </div>

            {selectedFilter.unit && (
              <div style={{ color: '#475569', marginBottom: '0.4rem' }}>
                Unit of Measure: <strong>{selectedFilter.unit}</strong>
              </div>
            )}

            <div>
              <span style={{ color: '#64748b', fontSize: '0.75rem', fontWeight: 600 }}>Available Options: </span>
              {selectedFilter.options && selectedFilter.options.length > 0 ? (
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.3rem', marginTop: '0.3rem' }}>
                  {selectedFilter.options.map((opt) => (
                    <span
                      key={opt.optionId || opt.value}
                      style={{
                        background: '#ffffff',
                        border: '1px solid #cbd5e1',
                        borderRadius: '10px',
                        padding: '1px 7px',
                        fontSize: '0.72rem',
                        color: '#334155',
                      }}
                    >
                      {opt.value}
                    </span>
                  ))}
                </div>
              ) : (
                <span style={{ fontStyle: 'italic', color: '#94a3b8' }}>Options dynamically harvested from products</span>
              )}
            </div>
          </div>
        )}

        <button
          type="submit"
          className="btn btn-primary"
          disabled={!selectedPoolFilterKey}
          style={{
            width: '100%',
            padding: '0.65rem 1rem',
            fontWeight: 600,
            fontSize: '0.875rem',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '0.4rem',
            marginTop: '0.25rem',
          }}
          id="assign-filter-btn"
        >
          + Add Filter to Category
        </button>
      </form>
    </div>
  );
};

export default AddFilterForm;
