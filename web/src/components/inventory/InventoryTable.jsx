import React from 'react';
import InventoryTableRow from './InventoryTableRow.jsx';
import { Pagination } from '../common/Pagination.jsx';
import { TableSkeleton } from '../common/TableSkeleton.jsx';
import { SearchIcon } from '../icons/index.js';

export const InventoryTable = ({
  paginatedProducts = [],
  filteredTotalCount = 0,
  loading = false,
  selectedIds,
  isAllSelected,
  onSelectAll,
  onToggleSelect,
  stepperQuantities,
  onStepQtyChange,
  onApplyStepper,
  onOpenAdjustModal,
  onResetFilters,
  currentPage = 1,
  totalPages = 1,
  itemsPerPage = 10,
  onPageChange,
  onPageSizeChange,
}) => {
  return (
    <div className="data-table-card saas-table-card">
      <div className="table-header-banner">
        <h3>Inventory Stocklist ({filteredTotalCount})</h3>
        <span className="table-header-subtitle">
          Showing {paginatedProducts.length} of {filteredTotalCount} tracked items
        </span>
      </div>
      <div className="table-responsive">
        <table className="data-table saas-inventory-table">
          <thead>
            <tr>
              <th className="th-checkbox">
                <input
                  type="checkbox"
                  className="saas-checkbox"
                  checked={isAllSelected}
                  onChange={onSelectAll}
                  aria-label="Select all products"
                />
              </th>
              <th className="th-id">ID</th>
              <th className="th-product">Product</th>
              <th className="th-category">Category</th>
              <th className="th-msrp">MSRP</th>
              <th className="th-stock">Current Stock</th>
              <th className="th-status">Stock Status</th>
              <th className="th-actions">Actions</th>
            </tr>
          </thead>
          {loading ? (
            <TableSkeleton rows={itemsPerPage} columns={8} />
          ) : paginatedProducts.length === 0 ? (
            <tbody>
              <tr>
                <td colSpan="8" style={{ padding: 0 }}>
                  <div className="empty-state">
                    <div className="empty-state-icon">
                      <SearchIcon size={36} />
                    </div>
                    <h4>No components found</h4>
                    <p>Try modifying your search keywords or resetting filters.</p>
                    <button
                      type="button"
                      className="btn btn-outline-sm"
                      onClick={onResetFilters}
                    >
                      Clear Filters
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          ) : (
            <tbody>
              {paginatedProducts.map((p) => {
                const prodId = p.productId || p.id;
                const isSelected = selectedIds.has(prodId);
                const stepQty = stepperQuantities[prodId] || 1;

                return (
                  <InventoryTableRow
                    key={prodId}
                    product={p}
                    isSelected={isSelected}
                    onToggleSelect={onToggleSelect}
                    stepQty={stepQty}
                    onStepQtyChange={onStepQtyChange}
                    onApplyStepper={onApplyStepper}
                    onOpenAdjustModal={onOpenAdjustModal}
                  />
                );
              })}
            </tbody>
          )}
        </table>
      </div>

      <Pagination
        currentPage={currentPage}
        totalPages={totalPages}
        totalItems={filteredTotalCount}
        pageSize={itemsPerPage}
        onPageChange={onPageChange}
        onPageSizeChange={onPageSizeChange}
        itemLabel="components"
      />
    </div>
  );
};

export default InventoryTable;
