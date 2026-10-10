import React from 'react';

/**
 * Reusable, responsive table pagination component with page size selector.
 *
 * @param {Object} props
 * @param {number} props.currentPage - Current active page (1-based)
 * @param {number} props.totalPages - Total calculated pages
 * @param {number} props.totalItems - Total filtered records
 * @param {number} props.pageSize - Current page size (e.g. 10, 25, 50)
 * @param {number[]} [props.pageSizeOptions=[10, 25, 50]] - Available page sizes
 * @param {function} props.onPageChange - Callback when user navigates page
 * @param {function} [props.onPageSizeChange] - Callback when user changes page size
 * @param {string} [props.itemLabel="records"] - Plural noun for records
 */
export const Pagination = ({
  currentPage = 1,
  totalPages = 1,
  totalItems = 0,
  pageSize = 10,
  pageSizeOptions = [10, 25, 50],
  onPageChange,
  onPageSizeChange,
  itemLabel = 'records',
}) => {
  if (totalItems <= 0) return null;

  const startItem = totalItems === 0 ? 0 : (currentPage - 1) * pageSize + 1;
  const endItem = Math.min(currentPage * pageSize, totalItems);

  // Helper to compute smart page numbers with ellipsis
  const getPageNumbers = () => {
    if (totalPages <= 7) {
      return Array.from({ length: totalPages }, (_, i) => i + 1);
    }
    if (currentPage <= 4) {
      return [1, 2, 3, 4, 5, '...', totalPages];
    }
    if (currentPage >= totalPages - 3) {
      return [1, '...', totalPages - 4, totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
    }
    return [1, '...', currentPage - 1, currentPage, currentPage + 1, '...', totalPages];
  };

  const pages = getPageNumbers();

  return (
    <div className="table-pagination-footer" id="table-pagination">
      <div
        className="pagination-info"
        style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}
      >
        <span>
          Showing <strong>{startItem}</strong> to <strong>{endItem}</strong> of{' '}
          <strong>{totalItems}</strong> {itemLabel}
        </span>

        {onPageSizeChange && (
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.35rem',
              marginLeft: '0.5rem',
            }}
          >
            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Per page:</span>
            <select
              className="pagination-pagesize-select"
              value={pageSize}
              onChange={(e) => onPageSizeChange(Number(e.target.value))}
              aria-label="Items per page"
              style={{
                fontSize: '0.8rem',
                padding: '0.2rem 0.4rem',
                borderRadius: 'var(--radius-sm, 4px)',
                border: '1px solid var(--border)',
                backgroundColor: '#ffffff',
                color: 'var(--text-main)',
                cursor: 'pointer',
              }}
            >
              {pageSizeOptions.map((opt) => (
                <option key={opt} value={opt}>
                  {opt}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>

      <div className="pagination-controls">
        <button
          type="button"
          className="pagination-btn pagination-arrow"
          disabled={currentPage <= 1}
          onClick={() => onPageChange(Math.max(1, currentPage - 1))}
          aria-label="Previous Page"
          title="Previous Page"
        >
          ‹
        </button>

        {pages.map((p, idx) => {
          if (p === '...') {
            return (
              <span
                key={`ellipsis-${idx}`}
                style={{ padding: '0 0.25rem', color: 'var(--text-muted)', fontSize: '0.85rem' }}
              >
                …
              </span>
            );
          }
          return (
            <button
              key={p}
              type="button"
              className={`pagination-btn ${currentPage === p ? 'pagination-active' : ''}`}
              onClick={() => onPageChange(p)}
              aria-label={`Page ${p}`}
            >
              {p}
            </button>
          );
        })}

        <button
          type="button"
          className="pagination-btn pagination-arrow"
          disabled={currentPage >= totalPages}
          onClick={() => onPageChange(Math.min(totalPages, currentPage + 1))}
          aria-label="Next Page"
          title="Next Page"
        >
          ›
        </button>
      </div>
    </div>
  );
};

export default Pagination;
