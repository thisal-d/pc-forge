import React, { useState, useMemo, useEffect } from 'react';
import { productService } from '../services/productService.js';
import { categoryService } from '../services/categoryService.js';
import { uploadService } from '../services/uploadService.js';
import {
  ProductStats,
  ProductToolbar,
  ProductTable,
  AddProductModal,
  EditProductModal,
  ViewProductModal,
  DeleteProductModal,
} from '../components/products/index.js';
import { CloseIcon } from '../components/icons/index.js';

export const ProductManagement = () => {
  // Master products list from backend API
  const [rawProducts, setRawProducts] = useState([]);
  // Master categories list for dropdowns
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('name_asc');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Flash notification toast state
  const [notification, setNotification] = useState(null);

  const showNotification = (type, message) => {
    setNotification({ type, message });
    setTimeout(() => {
      setNotification(null);
    }, 4500);
  };

  // Synchronize products and categories from backend APIs on mount
  useEffect(() => {
    let isMounted = true;
    setLoading(true);

    Promise.all([
      productService.fetchProductsFromApi().catch(() => []),
      categoryService.fetchCategoriesFromApi().catch(() => []),
    ]).then(([list, cats]) => {
      if (isMounted) {
        if (Array.isArray(list)) setRawProducts(list);
        if (Array.isArray(cats)) setCategories(cats);
        setLoading(false);
      }
    });

    const handleStockUpdate = () => {
      productService.fetchProductsFromApi().then((list) => {
        if (isMounted && Array.isArray(list)) {
          setRawProducts(list);
        }
      });
    };
    window.addEventListener('pcforge_stock_updated', handleStockUpdate);

    return () => {
      isMounted = false;
      window.removeEventListener('pcforge_stock_updated', handleStockUpdate);
    };
  }, []);

  // Reset pagination on filter or search changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, categoryFilter, statusFilter, sortBy]);

  // Filtered & Sorted Products
  const sortedAndFilteredProducts = useMemo(() => {
    const list = productService.filterProducts(rawProducts, {
      search: searchQuery,
      categoryId: categoryFilter,
      status: statusFilter,
    });

    return [...list].sort((a, b) => {
      switch (sortBy) {
        case 'name_desc':
          return (b.name || '').localeCompare(a.name || '');
        case 'price_asc':
          return (a.price || 0) - (b.price || 0);
        case 'price_desc':
          return (b.price || 0) - (a.price || 0);
        case 'stock_desc':
          return (b.stockQuantity || 0) - (a.stockQuantity || 0);
        case 'newest':
          return new Date(b.createdAt || 0) - new Date(a.createdAt || 0);
        case 'name_asc':
        default:
          return (a.name || '').localeCompare(b.name || '');
      }
    });
  }, [rawProducts, searchQuery, categoryFilter, statusFilter, sortBy]);

  const totalPages = Math.max(1, Math.ceil(sortedAndFilteredProducts.length / pageSize));
  const paginatedProducts = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return sortedAndFilteredProducts.slice(start, start + pageSize);
  }, [sortedAndFilteredProducts, currentPage, pageSize]);

  // Derived KPI statistics
  const stats = useMemo(() => {
    return productService.calculateStats(rawProducts);
  }, [rawProducts]);

  // ==========================================
  // ADD PRODUCT MODAL STATE
  // ==========================================
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [addFormData, setAddFormData] = useState({
    name: '',
    categoryId: '',
    brand: '',
    model: '',
    price: '',
    stockQuantity: '',
    imageUrl: '',
    description: '',
    status: 'Active',
  });
  const [addCategoryFilters, setAddCategoryFilters] = useState([]);
  const [addFiltersLoading, setAddFiltersLoading] = useState(false);
  const [addFilterValues, setAddFilterValues] = useState({});
  const [addErrors, setAddErrors] = useState({});
  const [addSubmitting, setAddSubmitting] = useState(false);
  const [isUploadingAddImage, setIsUploadingAddImage] = useState(false);
  const [isUploadingEditImage, setIsUploadingEditImage] = useState(false);
  const [addBlobPreview, setAddBlobPreview] = useState('');
  const [editBlobPreview, setEditBlobPreview] = useState('');
  const [cloudinaryStatus, setCloudinaryStatus] = useState({ isConfigured: false, cloudName: null, message: '' });

  // Fetch Cloudinary connection status & live categories from backend on mount and whenever modals open
  useEffect(() => {
    uploadService.getCloudinaryStatus().then((status) => {
      setCloudinaryStatus(status);
    });
    categoryService.fetchCategoriesFromApi().then((cats) => {
      if (Array.isArray(cats) && cats.length > 0) {
        setCategories(cats);
      }
    });
  }, [isAddModalOpen, isEditModalOpen]);

  // Load category filters dynamically when categoryId changes in Add modal
  useEffect(() => {
    if (!isAddModalOpen || !addFormData.categoryId) {
      setAddCategoryFilters([]);
      setAddFilterValues({});
      return;
    }

    let isMounted = true;
    const catId = Number(addFormData.categoryId);
    setAddFiltersLoading(true);

    categoryService.fetchFiltersForCategoryFromApi(catId).then((filters) => {
      if (isMounted) {
        setAddCategoryFilters(filters || []);
        setAddFilterValues({});
        setAddFiltersLoading(false);
      }
    }).catch(() => {
      if (isMounted) {
        setAddCategoryFilters(categoryService.getFiltersForCategory(catId) || []);
        setAddFilterValues({});
        setAddFiltersLoading(false);
      }
    });

    return () => {
      isMounted = false;
    };
  }, [addFormData.categoryId, isAddModalOpen]);

  // ==========================================
  // EDIT PRODUCT MODAL STATE
  // ==========================================
  const [currentEditingProduct, setCurrentEditingProduct] = useState(null);
  const [editFormData, setEditFormData] = useState({
    name: '',
    categoryId: '',
    brand: '',
    model: '',
    price: '',
    stockQuantity: '',
    imageUrl: '',
    description: '',
    status: 'Active',
  });
  const [editCategoryFilters, setEditCategoryFilters] = useState([]);
  const [editFiltersLoading, setEditFiltersLoading] = useState(false);
  const [editFilterValues, setEditFilterValues] = useState({});
  const [editErrors, setEditErrors] = useState({});
  const [editSubmitting, setEditSubmitting] = useState(false);

  // Handle dynamic category change inside Edit modal
  useEffect(() => {
    if (!isEditModalOpen || !editFormData.categoryId) {
      setEditCategoryFilters([]);
      return;
    }

    let isMounted = true;
    const catId = Number(editFormData.categoryId);
    const prevCatId = currentEditingProduct ? Number(currentEditingProduct.categoryId) : null;
    const isSameCategory = prevCatId === catId;

    setEditFiltersLoading(true);

    categoryService.fetchFiltersForCategoryFromApi(catId).then((filters) => {
      if (isMounted) {
        setEditCategoryFilters(filters || []);
        if (!isSameCategory) {
          setEditFilterValues({});
        }
        setEditFiltersLoading(false);
      }
    }).catch(() => {
      if (isMounted) {
        setEditCategoryFilters(categoryService.getFiltersForCategory(catId) || []);
        if (!isSameCategory) {
          setEditFilterValues({});
        }
        setEditFiltersLoading(false);
      }
    });

    return () => {
      isMounted = false;
    };
  }, [editFormData.categoryId, isEditModalOpen, currentEditingProduct]);

  // ==========================================
  // VIEW PRODUCT MODAL STATE
  // ==========================================
  const [viewingProduct, setViewingProduct] = useState(null);
  const [viewingFilters, setViewingFilters] = useState([]);
  const [viewingFilterValues, setViewingFilterValues] = useState([]);

  // ==========================================
  // DELETE PRODUCT CONFIRMATION MODAL STATE
  // ==========================================
  const [deleteCandidate, setDeleteCandidate] = useState(null);
  const [deleteSubmitting, setDeleteSubmitting] = useState(false);

  // ==========================================
  // HANDLERS: ADD PRODUCT
  // ==========================================
  const handleOpenAddModal = () => {
    setAddFormData({
      name: '',
      categoryId: '',
      brand: '',
      model: '',
      price: '',
      stockQuantity: '',
      imageUrl: '',
      description: '',
      status: 'Active',
    });
    setAddCategoryFilters([]);
    setAddFilterValues({});
    setAddErrors({});
    setIsAddModalOpen(true);
  };

  const handleCloseAddModal = () => {
    setIsAddModalOpen(false);
    setAddErrors({});
    if (addBlobPreview) {
      uploadService.revokeBlobPreview(addBlobPreview);
      setAddBlobPreview('');
    }
  };

  const handleAddFormChange = (e) => {
    const { name, value } = e.target;
    setAddFormData((prev) => ({ ...prev, [name]: value }));
    if (addErrors[name]) {
      setAddErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const handleDynamicFilterChange = (filter, value, optionId = null) => {
    setAddFilterValues((prev) => ({
      ...prev,
      [filter.filterId]: {
        filterId: filter.filterId,
        filterKey: filter.filterKey,
        displayName: filter.displayName,
        optionId: optionId,
        rawValue: value,
      },
    }));
    if (addErrors[`filter_${filter.filterId}`]) {
      setAddErrors((prev) => ({ ...prev, [`filter_${filter.filterId}`]: '' }));
    }
  };

  const handleAddImageFile = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const blobPreview = uploadService.createBlobPreview(file);
    setAddBlobPreview(blobPreview);

    try {
      setIsUploadingAddImage(true);
      const result = await uploadService.uploadImage(file);
      setAddFormData((prev) => ({ ...prev, imageUrl: result.url }));
      setCloudinaryStatus((prev) => ({
        ...prev,
        isConfigured: true,
        cloudName: prev.cloudName || 'dsqbfupga',
      }));
      showNotification('success', 'Product image successfully uploaded to Cloudinary!');
    } catch (err) {
      showNotification('error', err.message || 'Failed to upload image to Cloudinary.');
      uploadService.revokeBlobPreview(blobPreview);
      setAddBlobPreview('');
    } finally {
      setIsUploadingAddImage(false);
      e.target.value = '';
    }
  };

  const handleAddSubmit = async (e) => {
    e.preventDefault();
    const errors = {};

    if (isUploadingAddImage) {
      setAddErrors({ general: 'Please wait for the image upload to Cloudinary to finish.' });
      return;
    }

    if (addFormData.imageUrl && addFormData.imageUrl.startsWith('blob:')) {
      setAddErrors({ general: 'Temporary blob image URLs cannot be saved. Product images must be uploaded to Cloudinary.' });
      return;
    }

    if (!addFormData.name.trim()) errors.name = 'Product name is required.';
    if (!addFormData.categoryId) errors.categoryId = 'Please select a category.';
    if (!addFormData.brand.trim()) errors.brand = 'Brand is required.';

    const priceNum = parseFloat(addFormData.price);
    if (isNaN(priceNum) || priceNum <= 0) {
      errors.price = 'Price must be a valid number greater than 0.';
    }

    const stockNum = parseInt(addFormData.stockQuantity, 10);
    if (isNaN(stockNum) || stockNum < 0) {
      errors.stockQuantity = 'Stock must be a non-negative integer.';
    }

    if (Object.keys(errors).length > 0) {
      setAddErrors(errors);
      return;
    }

    setAddSubmitting(true);
    try {
      const selectedCategory = categories.find((c) => (c.categoryId || c.id) === Number(addFormData.categoryId));
      const categoryName = selectedCategory?.name || 'General';

      const filterValuesArray = Object.values(addFilterValues).filter(
        (fv) => fv.rawValue !== undefined && fv.rawValue !== null && String(fv.rawValue).trim() !== ''
      );

      const createdProduct = await productService.addProduct(
        {
          ...addFormData,
          categoryName,
        },
        filterValuesArray
      );

      setRawProducts((prev) => [createdProduct, ...prev]);
      if (addBlobPreview) {
        uploadService.revokeBlobPreview(addBlobPreview);
        setAddBlobPreview('');
      }
      setIsAddModalOpen(false);
      showNotification('success', `Product "${createdProduct.name}" created successfully.`);
    } catch (err) {
      setAddErrors({ general: err.message || 'Failed to create product.' });
    } finally {
      setAddSubmitting(false);
    }
  };

  // ==========================================
  // HANDLERS: EDIT PRODUCT
  // ==========================================
  const handleOpenEditModal = (product) => {
    setCurrentEditingProduct(product);
    setEditFormData({
      name: product.name,
      categoryId: String(product.categoryId),
      brand: product.brand,
      model: product.model || '',
      price: String(product.price),
      stockQuantity: String(product.stockQuantity),
      imageUrl: product.imageUrl || '',
      description: product.description || '',
      status: product.status || 'Active',
    });

    const existingValues = productService.getProductFilterValues(product.productId || product.id, product.specifications);
    const valuesMap = {};
    existingValues.forEach((fv) => {
      valuesMap[fv.filterKey] = {
        filterKey: fv.filterKey,
        rawValue: fv.rawValue,
      };
    });
    setEditFilterValues(valuesMap);
    setEditErrors({});
    setIsEditModalOpen(true);
  };

  const handleCloseEditModal = () => {
    setIsEditModalOpen(false);
    setCurrentEditingProduct(null);
    setEditErrors({});
    if (editBlobPreview) {
      uploadService.revokeBlobPreview(editBlobPreview);
      setEditBlobPreview('');
    }
  };

  const handleEditFormChange = (e) => {
    const { name, value } = e.target;
    setEditFormData((prev) => ({ ...prev, [name]: value }));
    if (editErrors[name]) {
      setEditErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const handleEditDynamicFilterChange = (filter, value, optionId = null) => {
    setEditFilterValues((prev) => ({
      ...prev,
      [filter.filterId]: {
        filterId: filter.filterId,
        filterKey: filter.filterKey,
        displayName: filter.displayName,
        optionId: optionId,
        rawValue: value,
      },
    }));
    if (editErrors[`filter_${filter.filterId}`]) {
      setEditErrors((prev) => ({ ...prev, [`filter_${filter.filterId}`]: '' }));
    }
  };

  const handleEditImageFile = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const blobPreview = uploadService.createBlobPreview(file);
    setEditBlobPreview(blobPreview);

    try {
      setIsUploadingEditImage(true);
      const result = await uploadService.uploadImage(file);
      setEditFormData((prev) => ({ ...prev, imageUrl: result.url }));
      setCloudinaryStatus((prev) => ({
        ...prev,
        isConfigured: true,
        cloudName: prev.cloudName || 'dsqbfupga',
      }));
      showNotification('success', 'Product image successfully uploaded to Cloudinary!');
    } catch (err) {
      showNotification('error', err.message || 'Failed to upload image to Cloudinary.');
      uploadService.revokeBlobPreview(blobPreview);
      setEditBlobPreview('');
    } finally {
      setIsUploadingEditImage(false);
      e.target.value = '';
    }
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!currentEditingProduct) return;

    const errors = {};

    if (isUploadingEditImage) {
      setEditErrors({ general: 'Please wait for the image upload to Cloudinary to finish.' });
      return;
    }

    if (editFormData.imageUrl && editFormData.imageUrl.startsWith('blob:')) {
      setEditErrors({ general: 'Temporary blob image URLs cannot be saved. Product images must be uploaded to Cloudinary.' });
      return;
    }

    if (!editFormData.name.trim()) errors.name = 'Product name is required.';
    if (!editFormData.categoryId) errors.categoryId = 'Please select a category.';
    if (!editFormData.brand.trim()) errors.brand = 'Brand is required.';

    const priceNum = parseFloat(editFormData.price);
    if (isNaN(priceNum) || priceNum <= 0) {
      errors.price = 'Price must be a valid number greater than 0.';
    }

    const stockNum = parseInt(editFormData.stockQuantity, 10);
    if (isNaN(stockNum) || stockNum < 0) {
      errors.stockQuantity = 'Stock must be a non-negative integer.';
    }

    if (Object.keys(errors).length > 0) {
      setEditErrors(errors);
      return;
    }

    setEditSubmitting(true);
    try {
      const prodId = currentEditingProduct.productId || currentEditingProduct.id;
      const selectedCategory = categories.find((c) => (c.categoryId || c.id) === Number(editFormData.categoryId));
      const categoryName = selectedCategory?.name || currentEditingProduct.categoryName;

      const filterValuesArray = Object.values(editFilterValues).filter(
        (fv) => fv.rawValue !== undefined && fv.rawValue !== null && String(fv.rawValue).trim() !== ''
      );

      const updatedProduct = await productService.updateProduct(
        prodId,
        {
          ...editFormData,
          categoryName,
        },
        filterValuesArray
      );

      setRawProducts((prev) =>
        prev.map((p) => ((p.productId || p.id) === prodId ? { ...p, ...updatedProduct } : p))
      );
      if (editBlobPreview) {
        uploadService.revokeBlobPreview(editBlobPreview);
        setEditBlobPreview('');
      }
      setIsEditModalOpen(false);
      showNotification('success', `Product "${updatedProduct.name}" updated successfully.`);
    } catch (err) {
      setEditErrors({ general: err.message || 'Failed to update product.' });
    } finally {
      setEditSubmitting(false);
    }
  };

  // ==========================================
  // HANDLERS: VIEW PRODUCT DETAILS
  // ==========================================
  const handleOpenViewModal = async (product) => {
    const prodId = product.productId || product.id;
    const details = (await productService.getProductById(prodId)) || product;
    setViewingProduct(details);

    const filterVals = productService.getProductFilterValues(prodId, details.specifications);
    setViewingFilterValues(filterVals);

    const filters = await categoryService.fetchFiltersForCategoryFromApi(details.categoryId);
    setViewingFilters(filters || []);
  };

  const handleCloseViewModal = () => {
    setViewingProduct(null);
    setViewingFilters([]);
    setViewingFilterValues([]);
  };

  // ==========================================
  // HANDLERS: STATUS TOGGLE
  // ==========================================
  const handleToggleStatus = async (product) => {
    const prodId = product.productId || product.id;
    try {
      const updated = await productService.toggleProductStatus(prodId);
      setRawProducts((prev) =>
        prev.map((p) => ((p.productId || p.id) === prodId ? { ...p, status: updated.status } : p))
      );
      showNotification(
        'success',
        `Product "${product.name}" marked as ${updated.status}.`
      );
    } catch (err) {
      showNotification('error', err.message || 'Failed to toggle status.');
    }
  };

  // ==========================================
  // HANDLERS: DELETE PRODUCT
  // ==========================================
  const handleOpenDeleteModal = (product) => {
    setDeleteCandidate(product);
  };

  const handleCloseDeleteModal = () => {
    setDeleteCandidate(null);
  };

  const handleConfirmDelete = async () => {
    if (!deleteCandidate) return;
    const prodId = deleteCandidate.productId || deleteCandidate.id;
    setDeleteSubmitting(true);
    try {
      await productService.deleteProduct(prodId);
      setRawProducts((prev) => prev.filter((p) => (p.productId || p.id) !== prodId));
      showNotification('success', `Product "${deleteCandidate.name}" deleted successfully.`);
      setDeleteCandidate(null);
    } catch (err) {
      showNotification('error', err.message || 'Failed to delete product.');
    } finally {
      setDeleteSubmitting(false);
    }
  };

  const handleResetFilters = () => {
    setSearchQuery('');
    setCategoryFilter('all');
    setStatusFilter('all');
    setSortBy('name_asc');
    setCurrentPage(1);
  };

  return (
    <div className="page-container">
      {/* Header */}
      <div className="dashboard-header">
        <div>
          <h1>Product Management</h1>
          <p className="subtitle">Manage PC components and their specifications.</p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <button
            onClick={handleOpenAddModal}
            className="btn btn-primary"
            id="add-product-btn"
          >
            + Add Product
          </button>
        </div>
      </div>

      {/* Notification Toast */}
      {notification && (
        <div className={`notification-banner alert alert-${notification.type === 'error' ? 'error' : 'success'}`}>
          <span>{notification.message}</span>
          <button
            type="button"
            onClick={() => setNotification(null)}
            className="clear-search-btn"
            style={{ position: 'static', marginLeft: '1rem' }}
          >
            <CloseIcon size={14} />
          </button>
        </div>
      )}

      {/* KPI Stats Cards */}
      <ProductStats stats={stats} />

      {/* Search & Filter Toolbar */}
      <ProductToolbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        onClearSearch={() => setSearchQuery('')}
        categoryFilter={categoryFilter}
        onCategoryFilterChange={setCategoryFilter}
        statusFilter={statusFilter}
        onStatusFilterChange={setStatusFilter}
        sortBy={sortBy}
        onSortByChange={setSortBy}
        categories={categories}
        onResetFilters={handleResetFilters}
      />

      {/* Product Table Card */}
      <ProductTable
        filteredProducts={sortedAndFilteredProducts}
        paginatedProducts={paginatedProducts}
        totalCount={stats.total}
        loading={loading}
        currentPage={currentPage}
        totalPages={totalPages}
        pageSize={pageSize}
        onPageChange={setCurrentPage}
        onPageSizeChange={(newSize) => {
          setPageSize(newSize);
          setCurrentPage(1);
        }}
        onResetFilters={handleResetFilters}
        onOpenAddModal={handleOpenAddModal}
        onViewProduct={handleOpenViewModal}
        onEditProduct={handleOpenEditModal}
        onToggleStatus={handleToggleStatus}
        onDeleteProduct={handleOpenDeleteModal}
      />

      {/* ADD PRODUCT MODAL */}
      <AddProductModal
        isOpen={isAddModalOpen}
        onClose={handleCloseAddModal}
        categories={categories}
        formData={addFormData}
        onFormChange={handleAddFormChange}
        errors={addErrors}
        submitting={addSubmitting}
        onSubmit={handleAddSubmit}
        cloudinaryStatus={cloudinaryStatus}
        blobPreview={addBlobPreview}
        isUploadingImage={isUploadingAddImage}
        onImageFileChange={handleAddImageFile}
        onImageUrlChange={(val) => setAddFormData((prev) => ({ ...prev, imageUrl: val }))}
        onRemoveImage={() => {
          if (addBlobPreview) uploadService.revokeBlobPreview(addBlobPreview);
          setAddBlobPreview('');
          setAddFormData((prev) => ({ ...prev, imageUrl: '' }));
        }}
        categoryFilters={addCategoryFilters}
        filterValues={addFilterValues}
        filtersLoading={addFiltersLoading}
        onDynamicFilterChange={handleDynamicFilterChange}
      />

      {/* EDIT PRODUCT MODAL */}
      <EditProductModal
        isOpen={isEditModalOpen}
        onClose={handleCloseEditModal}
        product={currentEditingProduct}
        categories={categories}
        formData={editFormData}
        onFormChange={handleEditFormChange}
        errors={editErrors}
        submitting={editSubmitting}
        onSubmit={handleEditSubmit}
        cloudinaryStatus={cloudinaryStatus}
        blobPreview={editBlobPreview}
        isUploadingImage={isUploadingEditImage}
        onImageFileChange={handleEditImageFile}
        onImageUrlChange={(val) => setEditFormData((prev) => ({ ...prev, imageUrl: val }))}
        onRemoveImage={() => {
          if (editBlobPreview) uploadService.revokeBlobPreview(editBlobPreview);
          setEditBlobPreview('');
          setEditFormData((prev) => ({ ...prev, imageUrl: '' }));
        }}
        categoryFilters={editCategoryFilters}
        filterValues={editFilterValues}
        filtersLoading={editFiltersLoading}
        onDynamicFilterChange={handleEditDynamicFilterChange}
      />

      {/* VIEW PRODUCT MODAL */}
      <ViewProductModal
        product={viewingProduct}
        onClose={handleCloseViewModal}
        onEdit={(prod) => handleOpenEditModal(prod)}
        viewingFilters={viewingFilters}
        viewingFilterValues={viewingFilterValues}
      />

      {/* DELETE CONFIRMATION MODAL */}
      <DeleteProductModal
        product={deleteCandidate}
        onClose={handleCloseDeleteModal}
        onConfirm={handleConfirmDelete}
        submitting={deleteSubmitting}
      />
    </div>
  );
};

export default ProductManagement;
