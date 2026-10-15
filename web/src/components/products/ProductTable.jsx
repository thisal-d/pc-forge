import React from 'react';
import ProductTableRow from './ProductTableRow.jsx';
import { PackageIcon } from '../icons/index.js';
import { Pagination } from '../common/Pagination.jsx';
import { TableSkeleton } from '../common/TableSkeleton.jsx';

export const ProductTable = ({
  filteredProducts = [],
  paginatedProducts = [],
  totalCount = 0,
  loading = false,
  currentPage = 1,
  totalPages = 1,
  pageSize = 10,
  onPageChange,
  onPageSizeChange,
  onResetFilters,
  onOpenAddModal,
  onViewProduct,
  onEditProduct,
  onToggleStatus,
  onDeleteProduct,
  onShowQr,
}) => {
  // If paginatedProducts wasn't passed, fall back to filteredProducts
  const displayedItems = paginatedProducts.length > 0 || filteredProducts.length === 0
    ? paginatedProducts
    : filteredProducts.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  return (
    <div className="data-table-card">
      <div className="table-header-banner">
        <h3>Hardware Catalog ({filteredProducts.length})</h3>
        <span className="table-header-subtitle">
          Showing {displayedItems.length} of {totalCount} registered products
        </span>
      </div>

      <div className="table-responsive">
        <table className="data-table" id="products-table">
          <thead>
            <tr>
              <th style={{ width: '85px', whiteSpace: 'nowrap' }}>Product ID</th>
              <th style={{ minWidth: '180px' }}>Product Name</th>
              <th style={{ width: '100px', whiteSpace: 'nowrap' }}>Category</th>
              <th style={{ width: '90px', whiteSpace: 'nowrap' }}>Brand</th>
              <th style={{ width: '115px', whiteSpace: 'nowrap' }}>Price</th>
              <th style={{ width: '95px', whiteSpace: 'nowrap' }}>Stock</th>
              <th style={{ width: '80px', whiteSpace: 'nowrap' }}>Status</th>
              <th style={{ width: '105px', whiteSpace: 'nowrap' }}>Created Date</th>
              <th style={{ textAlign: 'right', width: '320px', minWidth: '320px', whiteSpace: 'nowrap', paddingRight: '1.25rem' }}>Actions</th>
            </tr>
          </thead>
          {loading ? (
            <TableSkeleton rows={pageSize} columns={9} />
          ) : displayedItems.length === 0 ? (
            <tbody>
              <tr>
                <td colSpan="9" style={{ padding: 0 }}>
                  <div className="empty-state">
                    <div className="empty-state-icon">
                      <PackageIcon size={36} />
                    </div>
                    <h4>No products found</h4>
                    <p>No hardware components match your search query or filter criteria.</p>
                    <div style={{ display: 'flex', justifyContent: 'center', gap: '0.75rem', marginTop: '0.5rem' }}>
                      <button
                        onClick={onResetFilters}
                        className="btn btn-outline-sm"
                      >
                        Clear Filters
                      </button>
                      <button onClick={onOpenAddModal} className="btn btn-primary-sm">
                        + Add Product
                      </button>
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          ) : (
            <tbody>
              {displayedItems.map((product) => (
                <ProductTableRow
                  key={product.productId || product.id}
                  product={product}
                  onView={onViewProduct}
                  onEdit={onEditProduct}
                  onToggleStatus={onToggleStatus}
                  onDelete={onDeleteProduct}
                  onShowQr={onShowQr}
                />
              ))}
            </tbody>
          )}
        </table>
      </div>

      {!loading && filteredProducts.length > 0 && (
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={filteredProducts.length}
          pageSize={pageSize}
          pageSizeOptions={[10, 25, 50]}
          onPageChange={onPageChange}
          onPageSizeChange={onPageSizeChange}
          itemLabel="products"
        />
      )}
    </div>
  );
};

export default ProductTable;

