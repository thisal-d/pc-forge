import React from 'react';

export const AddFilterForm = ({
  filterMode,
  onFilterModeChange,
  selectedPoolFilterKey,
  onSelectedPoolFilterKeyChange,
  availableFiltersPool,
  assignedFilters,
  customFilterData,
  onCustomFilterDataChange,
  onSubmit,
}) => {
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
        <h4 style={{ fontSize: '0.95rem', fontWeight: 700, margin: 0, color: 'var(--text-main)' }}>
          Assign a Dynamic Filter
        </h4>
        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          Add hardware attributes to this category
        </span>
      </div>

      {/* Segmented Mode Switcher */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          background: '#f1f5f9',
          padding: '3px',
          borderRadius: '8px',
          marginBottom: '1rem',
          border: '1px solid #e2e8f0',
        }}
      >
        <button
          type="button"
          onClick={() => onFilterModeChange('select')}
          style={{
            padding: '0.5rem 0.75rem',
            fontSize: '0.825rem',
            fontWeight: 600,
            borderRadius: '6px',
            border: 'none',
            cursor: 'pointer',
            transition: 'all 0.15s ease',
            background: filterMode === 'select' ? '#ffffff' : 'transparent',
            color: filterMode === 'select' ? 'var(--primary)' : 'var(--text-muted)',
            boxShadow: filterMode === 'select' ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
          }}
        >
          Choose Predefined Hardware Spec
        </button>
        <button
          type="button"
          onClick={() => onFilterModeChange('custom')}
          style={{
            padding: '0.5rem 0.75rem',
            fontSize: '0.825rem',
            fontWeight: 600,
            borderRadius: '6px',
            border: 'none',
            cursor: 'pointer',
            transition: 'all 0.15s ease',
            background: filterMode === 'custom' ? '#ffffff' : 'transparent',
            color: filterMode === 'custom' ? 'var(--primary)' : 'var(--text-muted)',
            boxShadow: filterMode === 'custom' ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
          }}
        >
          + Create Custom Specification
        </button>
      </div>

      <form onSubmit={onSubmit}>
        {filterMode === 'select' ? (
          <div>
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
                Hardware Specification Attribute:
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
                <option value="">-- Choose from Predefined Specs Pool --</option>
                {availableFiltersPool.map((f) => {
                  const isAlreadyAssigned = assignedFilters.some(
                    (af) => af.filterKey.toLowerCase() === f.filterKey.toLowerCase()
                  );
                  return (
                    <option
                      key={f.filterKey}
                      value={f.filterKey}
                      disabled={isAlreadyAssigned}
                    >
                      {f.displayName} ({f.filterKey}) {f.unit ? `[${f.unit}]` : ''}{' '}
                      {isAlreadyAssigned ? '— Already Assigned' : ''}
                    </option>
                  );
                })}
              </select>
            </div>
          </div>
        ) : (
          <div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem', marginBottom: '0.75rem' }}>
              <div className="form-group">
                <label
                  htmlFor="custom-display-name"
                  style={{
                    display: 'block',
                    fontSize: '0.825rem',
                    fontWeight: 600,
                    color: 'var(--text-main)',
                    marginBottom: '0.4rem',
                  }}
                >
                  Display Label <span style={{ color: '#ef4444' }}>*</span>
                </label>
                <input
                  id="custom-display-name"
                  type="text"
                  placeholder="e.g. RGB Lighting, Fan Count"
                  value={customFilterData.displayName}
                  onChange={(e) =>
                    onCustomFilterDataChange({ ...customFilterData, displayName: e.target.value })
                  }
                  style={{
                    background: '#ffffff',
                    color: 'var(--text-main)',
                    border: '1px solid var(--border)',
                    borderRadius: '6px',
                    padding: '0.55rem 0.85rem',
                    fontSize: '0.875rem',
                    width: '100%',
                  }}
                />
              </div>

              <div className="form-group">
                <label
                  htmlFor="custom-filter-key"
                  style={{
                    display: 'block',
                    fontSize: '0.825rem',
                    fontWeight: 600,
                    color: 'var(--text-main)',
                    marginBottom: '0.4rem',
                  }}
                >
                  System Key <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)' }}>(Optional)</span>
                </label>
                <input
                  id="custom-filter-key"
                  type="text"
                  placeholder="e.g. rgb_lighting (auto-generated)"
                  value={customFilterData.filterKey}
                  onChange={(e) =>
                    onCustomFilterDataChange({ ...customFilterData, filterKey: e.target.value })
                  }
                  style={{
                    background: '#ffffff',
                    color: 'var(--text-main)',
                    border: '1px solid var(--border)',
                    borderRadius: '6px',
                    padding: '0.55rem 0.85rem',
                    fontSize: '0.875rem',
                    width: '100%',
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem', marginBottom: '1rem' }}>
              <div className="form-group">
                <label
                  htmlFor="custom-filter-type"
                  style={{
                    display: 'block',
                    fontSize: '0.825rem',
                    fontWeight: 600,
                    color: 'var(--text-main)',
                    marginBottom: '0.4rem',
                  }}
                >
                  UI Filter Type
                </label>
                <select
                  id="custom-filter-type"
                  value={customFilterData.filterType}
                  onChange={(e) =>
                    onCustomFilterDataChange({ ...customFilterData, filterType: e.target.value })
                  }
                  style={{
                    background: '#ffffff',
                    color: 'var(--text-main)',
                    border: '1px solid var(--border)',
                    borderRadius: '6px',
                    padding: '0.55rem 0.85rem',
                    fontSize: '0.875rem',
                    width: '100%',
                  }}
                >
                  <option value="multiselect">Multi-select Checkboxes (List)</option>
                  <option value="range">Numeric Range (Slider / Min-Max)</option>
                  <option value="boolean">Boolean Switch (Yes / No)</option>
                </select>
              </div>

              <div className="form-group">
                <label
                  htmlFor="custom-filter-unit"
                  style={{
                    display: 'block',
                    fontSize: '0.825rem',
                    fontWeight: 600,
                    color: 'var(--text-main)',
                    marginBottom: '0.4rem',
                  }}
                >
                  Unit of Measure <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)' }}>(Optional)</span>
                </label>
                <input
                  id="custom-filter-unit"
                  type="text"
                  placeholder="e.g. MHz, GB, Watts, mm"
                  value={customFilterData.unit}
                  onChange={(e) =>
                    onCustomFilterDataChange({ ...customFilterData, unit: e.target.value })
                  }
                  style={{
                    background: '#ffffff',
                    color: 'var(--text-main)',
                    border: '1px solid var(--border)',
                    borderRadius: '6px',
                    padding: '0.55rem 0.85rem',
                    fontSize: '0.875rem',
                    width: '100%',
                  }}
                />
              </div>
            </div>
          </div>
        )}

        <button
          type="submit"
          className="btn btn-primary"
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
