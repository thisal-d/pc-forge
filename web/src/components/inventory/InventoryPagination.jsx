import React from 'react';
import { Pagination } from '../common/Pagination.jsx';

/**
 * Consolidated InventoryPagination: delegates directly to shared Pagination component.
 */
export const InventoryPagination = ({
  currentPage,
  totalPages,
  totalItems,
  itemsPerPage,
  onPageChange,
  ...rest
}) => {
  return (
    <Pagination
      currentPage={currentPage}
      totalPages={totalPages}
      totalItems={totalItems}
      pageSize={itemsPerPage}
      onPageChange={onPageChange}
      itemLabel="components"
      {...rest}
    />
  );
};

export default InventoryPagination;
