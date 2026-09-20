import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { productService } from '../services/productService.js';
import { categoryService } from '../services/categoryService.js';
import {
  InventoryStats,
  InventoryToolbar,
  InventoryTable,
  StockAdjustmentModal,
} from '../components/inventory';
import { AlertTriangleIcon, CheckCircleIcon } from '../components/icons';

export const Inventory = () => {
  const { role } = useAuth();
  const isAdmin = role === 'Admin';

  // Products and Categories state
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [stockFilter, setStockFilter] = useState('all'); // 'all', 'instock', 'lowstock', 'outofstock'

  // Table selection & stepper state
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [stepperQuantities, setStepperQuantities] = useState({});

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Toast notifications
  const [toast, setToast] = useState(null);
  const showToast = (type, message) => {
    setToast({ type, message });
    setTimeout(() => {
      setToast(null);
    }, 4000);
  };

  // Stock Adjustment Modal state
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [adjustMode, setAdjustMode] = useState('add'); // 'add' (Restock) or 'set' (Exact)
  const [amountInput, setAmountInput] = useState('10');
  const [reasonInput, setReasonInput] = useState('Shipment Received');
  const [notesInput, setNotesInput] = useState('');
  const [modalError, setModalError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Synchronize data from backend API on mount and on stock update events
  useEffect(() => {
    let isMounted = true;
    setLoading(true);

    Promise.all([
      productService.fetchProductsFromApi().catch(() => []),
      categoryService.fetchCategoriesFromApi().catch(() => []),
    ]).then(([list, cats]) => {
      if (isMounted) {
        if (Array.isArray(list)) setProducts(list);
        if (Array.isArray(cats)) setCategories(cats);
        setLoading(false);
      }
    });

    const handleStockUpdate = () => {
      productService.fetchProductsFromApi().then((list) => {
        if (isMounted && Array.isArray(list)) {
          setProducts(list);
        }
      });
    };
    window.addEventListener('pcforge_stock_updated', handleStockUpdate);

    return () => {
      isMounted = false;
      window.removeEventListener('pcforge_stock_updated', handleStockUpdate);
    };
  }, []);

  // Summary KPI statistics
  const stats = useMemo(() => {
    const totalItems = products.length;
    const inStock = products.filter((p) => Number(p.stockQuantity) > 5).length;
    const lowStock = products.filter((p) => Number(p.stockQuantity) > 0 && Number(p.stockQuantity) <= 5).length;
    const outOfStock = products.filter((p) => Number(p.stockQuantity) <= 0).length;

    return { totalItems, inStock, lowStock, outOfStock };
  }, [products]);

  // Filtered Products
  const filteredProducts = useMemo(() => {
    return products.filter((product) => {
      // 1. Search Query
      if (searchQuery.trim()) {
        const q = searchQuery.trim().toLowerCase();
        const nameMatch = (product.name || '').toLowerCase().includes(q);
        const brandMatch = (product.brand || '').toLowerCase().includes(q);
        const modelMatch = (product.model || '').toLowerCase().includes(q);
        const idMatch = String(product.productId || product.id).includes(q);
        if (!nameMatch && !brandMatch && !modelMatch && !idMatch) return false;
      }

      // 2. Category Filter
      if (selectedCategory !== 'all') {
        if (Number(product.categoryId) !== Number(selectedCategory)) return false;
      }

      // 3. Stock Level Filter
      const stock = Number(product.stockQuantity) || 0;
      if (stockFilter === 'instock' && stock <= 5) return false;
      if (stockFilter === 'lowstock' && (stock <= 0 || stock > 5)) return false;
      if (stockFilter === 'outofstock' && stock > 0) return false;

      return true;
    });
  }, [products, searchQuery, selectedCategory, stockFilter]);

  // Reset page when filters change
  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, selectedCategory, stockFilter]);

  // Paginated records
  const totalPages = Math.ceil(filteredProducts.length / pageSize) || 1;
  const paginatedProducts = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredProducts.slice(start, start + pageSize);
  }, [filteredProducts, currentPage, pageSize]);

  // Checkbox handlers
  const isAllSelected =
    paginatedProducts.length > 0 &&
    paginatedProducts.every((p) => selectedIds.has(p.productId || p.id));

  const handleSelectAll = (e) => {
    if (e.target.checked) {
      const allIds = new Set(paginatedProducts.map((p) => p.productId || p.id));
      setSelectedIds(allIds);
    } else {
      setSelectedIds(new Set());
    }
  };

  const handleToggleSelect = (prodId) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(prodId)) {
        next.delete(prodId);
      } else {
        next.add(prodId);
      }
      return next;
    });
  };

  // Stepper handlers
  const getStepperQty = (prodId) => stepperQuantities[prodId] || 1;
  const handleStepQtyChange = (prodId, val) => {
    setStepperQuantities((prev) => ({ ...prev, [prodId]: val }));
  };

  // Quick inline adjustment
  const handleApplyStepper = async (product, deltaMultiplier) => {
    const prodId = product.productId || product.id;
    const step = getStepperQty(prodId);
    const delta = step * deltaMultiplier;
    const currentStock = Number(product.stockQuantity) || 0;
    const newStock = Math.max(0, currentStock + delta);

    if (newStock === currentStock && delta < 0) return;

    const actionText = delta > 0 ? `+${delta}` : `${delta}`;
    const reason = `Quick inventory adjustment (${actionText} units)`;

    try {
      await productService.adjustProductStockDelta(prodId, delta, reason);
      setProducts((prev) =>
        prev.map((p) => ((p.productId || p.id) === prodId ? { ...p, stockQuantity: newStock } : p))
      );
      showToast('success', `${product.name}: stock updated to ${newStock} units (${actionText}).`);
    } catch (err) {
      showToast('error', `Failed to update stock: ${err.message}`);
    }
  };

  // Open modal for targeted stock adjustments
  const openAdjustModal = (product) => {
    setSelectedProduct(product);
    setAdjustMode('add');
    setAmountInput('10');
    setReasonInput('Shipment Received');
    setNotesInput('');
    setModalError('');
    setIsModalOpen(true);
  };

  const closeAdjustModal = () => {
    setIsModalOpen(false);
    setSelectedProduct(null);
    setModalError('');
  };

  // Calculate resulting stock for modal preview
  const previewNewStock = useMemo(() => {
    if (!selectedProduct) return 0;
    const current = Number(selectedProduct.stockQuantity) || 0;
    const amount = parseInt(amountInput, 10);
    if (isNaN(amount)) return current;

    if (adjustMode === 'add') {
      return Math.max(0, current + amount);
    } else {
      return Math.max(0, amount);
    }
  }, [selectedProduct, adjustMode, amountInput]);

  // Handle modal submit
  const handleModalSubmit = async (e) => {
    e.preventDefault();
    if (!selectedProduct) return;

    const amount = parseInt(amountInput, 10);
    if (isNaN(amount) || amount < 0) {
      setModalError('Please enter a valid non-negative integer.');
      return;
    }

    const currentStock = Number(selectedProduct.stockQuantity) || 0;
    const finalStock = adjustMode === 'add' ? currentStock + amount : amount;

    if (finalStock < 0) {
      setModalError('Resulting stock cannot be negative.');
      return;
    }

    setIsSubmitting(true);
    setModalError('');

    try {
      const fullReason = notesInput.trim()
        ? `${reasonInput}: ${notesInput.trim()}`
        : reasonInput;

      await productService.updateProductStock(
        selectedProduct.productId || selectedProduct.id,
        finalStock,
        fullReason
      );

      setProducts((prev) =>
        prev.map((p) =>
          (p.productId || p.id) === (selectedProduct.productId || selectedProduct.id)
            ? { ...p, stockQuantity: finalStock }
            : p
        )
      );
      showToast('success', `Stock for "${selectedProduct.name}" updated to ${finalStock} units.`);
      closeAdjustModal();
    } catch (err) {
      setModalError(err.message || 'Failed to update stock. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleResetFilters = () => {
    setSearchQuery('');
    setStockFilter('all');
    setSelectedCategory('all');
  };

  return (
    <div className="inventory-page-container">
      {/* Toast Notification */}
      {toast && (
        <div
          className={`saas-toast saas-toast-${toast.type}`}
          role="alert"
        >
          <div className="toast-icon">
            {toast.type === 'error' ? <AlertTriangleIcon size={18} /> : <CheckCircleIcon size={18} />}
          </div>
          <div className="toast-message">{toast.message}</div>
        </div>
      )}

      {/* Page Header */}
      <div className="inventory-header">
        <div className="header-left">
          <div className="header-icon-box">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#2563eb" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
              <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
              <line x1="12" y1="22.08" x2="12" y2="12"></line>
            </svg>
          </div>
          <div>
            <h1 className="header-title">Inventory Management</h1>
            <p className="header-subtitle">
              Track your component stock, manage inventory levels, and keep your store running smoothly.
            </p>
          </div>
        </div>

        <div className="header-right">
          {isAdmin && (
            <Link to="/products" className="btn-catalog-action" id="btn-goto-products">
              Product Catalog →
            </Link>
          )}
        </div>
      </div>

      {/* 4 Metric Summary Cards */}
      <InventoryStats
        stats={stats}
        stockFilter={stockFilter}
        onSelectFilter={setStockFilter}
      />

      {/* Filter & Search Toolbar */}
      <InventoryToolbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        onClearSearch={() => setSearchQuery('')}
        stockFilter={stockFilter}
        onStockFilterChange={setStockFilter}
        selectedCategory={selectedCategory}
        onCategoryChange={setSelectedCategory}
        categories={categories}
        filteredCount={filteredProducts.length}
        totalCount={products.length}
      />

      {/* Main Inventory Data Table Card */}
      <InventoryTable
        paginatedProducts={paginatedProducts}
        filteredTotalCount={filteredProducts.length}
        loading={loading}
        selectedIds={selectedIds}
        isAllSelected={isAllSelected}
        onSelectAll={handleSelectAll}
        onToggleSelect={handleToggleSelect}
        stepperQuantities={stepperQuantities}
        onStepQtyChange={handleStepQtyChange}
        onApplyStepper={handleApplyStepper}
        onOpenAdjustModal={openAdjustModal}
        onResetFilters={handleResetFilters}
        currentPage={currentPage}
        totalPages={totalPages}
        itemsPerPage={pageSize}
        onPageChange={setCurrentPage}
        onPageSizeChange={(newSize) => {
          setPageSize(newSize);
          setCurrentPage(1);
        }}
      />

      {/* Stock Adjustment Modal */}
      <StockAdjustmentModal
        isOpen={isModalOpen}
        product={selectedProduct}
        onClose={closeAdjustModal}
        adjustMode={adjustMode}
        onAdjustModeChange={setAdjustMode}
        amountInput={amountInput}
        onAmountInputChange={setAmountInput}
        previewNewStock={previewNewStock}
        reasonInput={reasonInput}
        onReasonInputChange={setReasonInput}
        notesInput={notesInput}
        onNotesInputChange={setNotesInput}
        modalError={modalError}
        isSubmitting={isSubmitting}
        onSubmit={handleModalSubmit}
      />
    </div>
  );
};

export default Inventory;
