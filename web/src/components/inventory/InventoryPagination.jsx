import React from 'react';

export const InventoryPagination = ({
  currentPage,
  totalPages,
  totalItems,
  itemsPerPage,
  onPageChange,
}) => {
  const startItem = totalItems === 0 ? 0 : (currentPage - 1) * itemsPerPage + 1;
  const endItem = Math.min(currentPage * itemsPerPage, totalItems);

  return (
    <div className="table-pagination-footer">
      <div className="pagination-info">
        Showing <strong>{startItem}</strong> to <strong>{endItem}</strong> of {totalItems} components
      </div>

      <div className="pagination-controls">
        <button
          type="button"
          className="pagination-btn pagination-arrow"
          disabled={currentPage <= 1}
          onClick={() => onPageChange(Math.max(1, currentPage - 1))}
          aria-label="Previous Page"
        >
          ‹
        </button>
        {Array.from({ length: totalPages }, (_, i) => i + 1).map((pageNum) => (
          <button
            key={pageNum}
            type="button"
            className={`pagination-btn ${currentPage === pageNum ? 'pagination-active' : ''}`}
            onClick={() => onPageChange(pageNum)}
          >
            {pageNum}
          </button>
        ))}
        <button
          type="button"
          className="pagination-btn pagination-arrow"
          disabled={currentPage >= totalPages}
          onClick={() => onPageChange(Math.min(totalPages, currentPage + 1))}
          aria-label="Next Page"
        >
          ›
        </button>
      </div>
    </div>
  );
};

export default InventoryPagination;
