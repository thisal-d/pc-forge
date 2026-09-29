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
              <th>Product ID</th>
              <th>Product Name</th>
              <th>Category</th>
              <th>Brand</th>
              <th>Price</th>
              <th>Stock</th>
              <th>Status</th>
              <th>Created Date</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
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

