import React from 'react';

export const ProductDynamicSpecs = ({
  categoryId,
  filters,
  filterValues,
  loading,
  onChange,
  containerId = 'dynamic-category-filters-container',
  titleColor = '#a78bfa',
}) => {
  const renderInput = (filter) => {
    const currentVal = filterValues[filter.filterId]?.rawValue || filterValues[filter.filterKey]?.rawValue || '';
    const hasOptions = Array.isArray(filter.options) && filter.options.length > 0;

    // 1. Select Dropdown if options exist
    if (hasOptions) {
      return (
        <div className="form-group" key={filter.filterId}>
          <label htmlFor={`filter-${filter.filterId}`}>
            {filter.displayName}
            {filter.unit && <span className="filter-unit-badge">({filter.unit})</span>}
          </label>
          <select
            id={`filter-${filter.filterId}`}
            value={currentVal}
            onChange={(e) => {
              const selOpt = filter.options.find((o) => o.optionValue === e.target.value);
              onChange(filter, e.target.value, selOpt?.filterOptionId || null);
            }}
          >
            <option value="">-- Select {filter.displayName} --</option>
            {filter.options.map((opt) => (
              <option key={opt.filterOptionId || opt.id} value={opt.optionValue}>
                {opt.optionValue}
              </option>
            ))}
          </select>
        </div>
      );
    }

    // 2. Boolean
    if (filter.dataType === 'Boolean') {
      return (
        <div className="form-group" key={filter.filterId}>
          <label htmlFor={`filter-${filter.filterId}`}>{filter.displayName}</label>
          <select
            id={`filter-${filter.filterId}`}
            value={String(currentVal)}
            onChange={(e) => onChange(filter, e.target.value)}
          >
            <option value="">-- Select --</option>
            <option value="true">Yes / Supported</option>
            <option value="false">No / Unsupported</option>
          </select>
        </div>
      );
    }

    // 3. Number
    if (filter.dataType === 'Number') {
      return (
        <div className="form-group" key={filter.filterId}>
          <label htmlFor={`filter-${filter.filterId}`}>
            {filter.displayName}
            {filter.unit && <span className="filter-unit-badge">({filter.unit})</span>}
          </label>
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
            <input
              id={`filter-${filter.filterId}`}
              type="number"
              step="any"
              placeholder={`Enter ${filter.displayName}...`}
              value={currentVal}
              onChange={(e) => onChange(filter, e.target.value)}
              style={{ width: '100%', paddingRight: filter.unit ? '3rem' : '0.85rem' }}
            />
            {filter.unit && (
              <span
                style={{
                  position: 'absolute',
                  right: '0.75rem',
                  color: 'var(--text-muted)',
                  fontSize: '0.85rem',
                  pointerEvents: 'none',
                }}
              >
                {filter.unit}
              </span>
            )}
          </div>
        </div>
      );
    }

    // 4. Default: Text Input
    return (
      <div className="form-group" key={filter.filterId}>
        <label htmlFor={`filter-${filter.filterId}`}>
          {filter.displayName}
          {filter.unit && <span className="filter-unit-badge">({filter.unit})</span>}
        </label>
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
          <input
            id={`filter-${filter.filterId}`}
            type="text"
            placeholder={`Enter ${filter.displayName}...`}
            value={currentVal}
            onChange={(e) => onChange(filter, e.target.value)}
            style={{ width: '100%', paddingRight: filter.unit ? '3rem' : '0.85rem' }}
          />
          {filter.unit && (
            <span
              style={{
                position: 'absolute',
                right: '0.75rem',
                color: 'var(--text-muted)',
                fontSize: '0.85rem',
                pointerEvents: 'none',
              }}
            >
              {filter.unit}
            </span>
          )}
        </div>
      </div>
    );
  };

  return (
    <>
      <h4 style={{ color: titleColor, fontSize: '0.95rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.4rem', marginTop: '0.75rem' }}>
        2. Category-Specific Dynamic Filters & Specifications
      </h4>

      {!categoryId ? (
        <div style={{ padding: '1rem', background: 'rgba(255, 255, 255, 0.02)', borderRadius: '6px', border: '1px dashed var(--border)', textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
          Select a Category above to dynamically load its configured technical specifications.
        </div>
      ) : loading ? (
        <div style={{ padding: '1rem', textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
          Loading dynamic category filters...
        </div>
      ) : filters.length === 0 ? (
        <div style={{ padding: '1rem', background: 'rgba(255, 255, 255, 0.02)', borderRadius: '6px', border: '1px dashed var(--border)', textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.875rem' }}>
          No dynamic filters currently configured for this category in Category Management.
        </div>
      ) : (
        <div className="grid grid-2" style={{ gap: '1rem' }} id={containerId}>
          {filters.map((filter) => renderInput(filter))}
        </div>
      )}
    </>
  );
};

export default ProductDynamicSpecs;
