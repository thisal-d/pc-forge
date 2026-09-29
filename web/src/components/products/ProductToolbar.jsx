import React from 'react';
import { SearchIcon, CloseIcon } from '../icons/index.js';

export const ProductToolbar = ({
  searchQuery,
  onSearchChange,
  onClearSearch,
  categoryFilter,
  onCategoryFilterChange,
  statusFilter,
  onStatusFilterChange,
  sortBy = 'name_asc',
  onSortByChange,
  categories,
  onResetFilters,
}) => {
  const isFiltered = searchQuery || categoryFilter !== 'all' || statusFilter !== 'all' || sortBy !== 'name_asc';

  return (
    <div className="toolbar-card">
      <div className="search-filter-row">
        {/* Search Box */}
        <div className="search-input-wrapper">
          <span className="search-icon">
            <SearchIcon size={16} />
          </span>
          <input
            type="text"
            placeholder="Search products by name, brand, or model..."
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            id="product-search-input"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={onClearSearch}
              className="clear-search-btn"
              title="Clear search"
            >
              <CloseIcon size={14} />
            </button>
          )}
        </div>

        {/* Category Dropdown Filter */}
        <div className="filter-dropdowns">
          <div className="filter-item">
            <label htmlFor="category-filter">Category:</label>
            <select
              id="category-filter"
              value={categoryFilter}
              onChange={(e) => onCategoryFilterChange(e.target.value)}
            >
              <option value="all">All Categories</option>
              {categories.map((cat) => (
                <option key={cat.categoryId || cat.id} value={cat.categoryId || cat.id}>
                  {cat.name}
                </option>
              ))}
            </select>
          </div>

          {/* Status Dropdown Filter */}
          <div className="filter-item">
            <label htmlFor="product-status-filter">Status:</label>
            <select
              id="product-status-filter"
              value={statusFilter}
              onChange={(e) => onStatusFilterChange(e.target.value)}
            >
              <option value="all">All Statuses</option>
              <option value="Active">Active</option>
              <option value="Inactive">Inactive</option>
              <option value="instock">In Stock</option>
              <option value="lowstock">Low Stock (≤ 5)</option>
              <option value="outofstock">Out of Stock</option>
            </select>
          </div>

          {/* Sort By Dropdown */}
          <div className="filter-item">
            <label htmlFor="product-sort-by">Sort:</label>
            <select
              id="product-sort-by"
              value={sortBy || 'name_asc'}
              onChange={(e) => onSortByChange && onSortByChange(e.target.value)}
            >
              <option value="name_asc">Name (A → Z)</option>
              <option value="name_desc">Name (Z → A)</option>
              <option value="price_asc">Price: Low to High</option>
              <option value="price_desc">Price: High to Low</option>
              <option value="stock_desc">Highest Stock</option>
              <option value="newest">Newest First</option>
            </select>
          </div>

          {isFiltered && (
            <button
              type="button"
              onClick={onResetFilters}
              className="btn btn-outline-sm"
              title="Reset all search filters"
            >
              Reset Filters
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default ProductToolbar;
