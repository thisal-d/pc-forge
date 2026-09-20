import api from '../api/axiosInstance.js';

// Helper to map backend ProductDto into frontend product model
const mapApiProduct = (apiProduct) => {
  if (!apiProduct) return null;
  const id = apiProduct.productId || apiProduct.id;
  let specs = {};
  if (typeof apiProduct.specifications === 'string') {
    try {
      specs = JSON.parse(apiProduct.specifications);
    } catch {
      specs = {};
    }
  } else if (apiProduct.specifications && typeof apiProduct.specifications === 'object') {
    specs = apiProduct.specifications;
  }

  return {
    productId: id,
    id: id,
    categoryId: apiProduct.categoryId,
    categoryName: apiProduct.categoryName || 'General',
    name: apiProduct.name,
    brand: apiProduct.brand,
    model: apiProduct.model || null,
    price: Number(apiProduct.price) || 0,
    stockQuantity: Number(apiProduct.stockQuantity) || 0,
    imageUrl: apiProduct.imageUrl || null,
    description: apiProduct.description || '',
    status: apiProduct.status || (Number(apiProduct.stockQuantity) > 0 ? 'Active' : 'Inactive'),
    specifications: specs,
    socket: apiProduct.socket || specs.socket || null,
    memoryType: apiProduct.memoryType || specs.memory_type || specs.ddr_type || null,
    powerWattage: apiProduct.powerWattage || (specs.wattage ? parseInt(specs.wattage, 10) : null),
    formFactor: apiProduct.formFactor || specs.form_factor || null,
    createdAt: apiProduct.createdAt || new Date().toISOString(),
    createdDate: apiProduct.createdAt ? apiProduct.createdAt.split('T')[0] : new Date().toISOString().split('T')[0],
  };
};

export const productService = {
  // Legacy synchronous getter returns empty array — components must fetch asynchronously
  getAllProducts() {
    return [];
  },

  // Fetch all products from backend API (GET /api/products)
  async getProducts() {
    try {
      const response = await api.get('/products');
      if (Array.isArray(response.data)) {
        return response.data.map(mapApiProduct);
      }
      return [];
    } catch (err) {
      console.error('Failed to fetch products from backend API:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Synchronize products with backend API (GET /api/products)
  async fetchProductsFromApi() {
    return this.getProducts();
  },

  // Retrieve single product by ID with its filter values directly from backend API
  async getProductById(productId) {
    const id = Number(productId);
    if (!id || isNaN(id)) return null;

    try {
      const response = await api.get(`/products/${id}`);
      if (!response.data) return null;
      const product = mapApiProduct(response.data);
      const filterValues = this.getProductFilterValues(id, product.specifications);
      return {
        ...product,
        filterValues,
      };
    } catch (err) {
      console.error(`Failed to fetch product #${id}:`, err?.response?.data || err.message);
      return null;
    }
  },

  // Transform specs object to filter value array for form pre-filling
  getProductFilterValues(productId, specifications = {}) {
    const id = Number(productId);
    return Object.entries(specifications || {}).map(([filterKey, rawValue], idx) => ({
      productFilterValueId: idx + 1,
      productId: id,
      filterKey,
      rawValue: String(rawValue),
    }));
  },

  // Multi-criteria filtering (Pure utility function)
  filterProducts(productList, { search = '', categoryId = 'all', status = 'all' } = {}) {
    if (!Array.isArray(productList)) return [];

    return productList.filter((product) => {
      // 1. Search Query: Product Name, Brand, Model, Description, or ID
      if (search.trim()) {
        const q = search.trim().toLowerCase();
        const nameMatches = (product.name || '').toLowerCase().includes(q);
        const brandMatches = (product.brand || '').toLowerCase().includes(q);
        const modelMatches = (product.model || '').toLowerCase().includes(q);
        const descMatches = (product.description || '').toLowerCase().includes(q);
        const idMatches = String(product.productId || product.id).includes(q);

        if (!nameMatches && !brandMatches && !modelMatches && !descMatches && !idMatches) {
          return false;
        }
      }

      // 2. Category Filter
      if (categoryId !== 'all') {
        const catIdNum = Number(categoryId);
        if (Number(product.categoryId) !== catIdNum) {
          return false;
        }
      }

      // 3. Status Filter ('all', 'Active', 'Inactive', 'instock', 'lowstock', 'outofstock')
      if (status !== 'all') {
        const sLower = status.toLowerCase();
        if (sLower === 'active') {
          if ((product.status || 'Active').toLowerCase() !== 'active') return false;
        } else if (sLower === 'inactive') {
          if ((product.status || 'Active').toLowerCase() !== 'inactive') return false;
        } else if (sLower === 'instock') {
          if (product.stockQuantity <= 0) return false;
        } else if (sLower === 'lowstock') {
          if (product.stockQuantity <= 0 || product.stockQuantity > 5) return false;
        } else if (sLower === 'outofstock') {
          if (product.stockQuantity > 0) return false;
        }
      }

      return true;
    });
  },

  // Calculate summary KPI stats (Pure utility function)
  calculateStats(products) {
    if (!Array.isArray(products)) {
      return { total: 0, active: 0, lowStock: 0, outOfStock: 0, totalInventoryValue: 0 };
    }
    const total = products.length;
    const active = products.filter((p) => (p.status || 'Active').toLowerCase() === 'active').length;
    const lowStock = products.filter((p) => p.stockQuantity > 0 && p.stockQuantity <= 5).length;
    const outOfStock = products.filter((p) => p.stockQuantity <= 0).length;
    const totalInventoryValue = products.reduce((sum, p) => sum + (Number(p.price) || 0) * (Number(p.stockQuantity) || 0), 0);

    return {
      total,
      active,
      lowStock,
      outOfStock,
      totalInventoryValue,
    };
  },

  // Add a new Product directly to the backend database (POST /api/products)
  async addProduct(productData, filterValues = []) {
    const cleanName = (productData.name || '').trim();
    const cleanBrand = (productData.brand || '').trim();
    const categoryId = Number(productData.categoryId);
    const price = Number(productData.price);
    const stockQuantity = Number(productData.stockQuantity);

    if (!cleanName) throw new Error('Product name is required.');
    if (!categoryId || categoryId <= 0) throw new Error('Valid category is required.');
    if (!cleanBrand) throw new Error('Product brand is required.');
    if (isNaN(price) || price <= 0) throw new Error('Price must be a valid positive number.');
    if (isNaN(stockQuantity) || stockQuantity < 0) throw new Error('Stock quantity must be zero or a positive integer.');

    if (productData.imageUrl && typeof productData.imageUrl === 'string') {
      const img = productData.imageUrl.trim();
      if (img.startsWith('blob:') || img.startsWith('data:')) {
        throw new Error('Temporary blob or data image URLs cannot be saved. Product images must be uploaded to Cloudinary.');
      }
    }

    // Build specifications dictionary from filter values
    const specifications = {};
    filterValues.forEach((fv) => {
      if (fv.filterKey && fv.rawValue) {
        specifications[fv.filterKey] = fv.rawValue;
      }
    });

    try {
      const response = await api.post('/products', {
        categoryId,
        name: cleanName,
        brand: cleanBrand,
        model: (productData.model || '').trim() || null,
        price,
        stockQuantity,
        imageUrl: (productData.imageUrl || '').trim() || null,
        description: (productData.description || '').trim() || null,
        specifications: JSON.stringify(specifications),
      });

      return mapApiProduct(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Admin or Staff account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Admin and Staff accounts can add products.'
          : err.message || 'Failed to save product to backend database.');
      throw new Error(backendMessage);
    }
  },

  // Update existing Product on backend (PUT /api/products/{id})
  async updateProduct(productId, productData, filterValues = []) {
    const id = Number(productId);
    if (!id || isNaN(id)) throw new Error('Invalid product ID for update.');

    const cleanName = (productData.name || '').trim();
    const cleanBrand = (productData.brand || '').trim();
    const categoryId = Number(productData.categoryId);
    const price = Number(productData.price);
    const stockQuantity = Number(productData.stockQuantity);

    if (!cleanName) throw new Error('Product name is required.');
    if (!categoryId || categoryId <= 0) throw new Error('Valid category is required.');
    if (!cleanBrand) throw new Error('Product brand is required.');
    if (isNaN(price) || price <= 0) throw new Error('Price must be a valid positive number.');
    if (isNaN(stockQuantity) || stockQuantity < 0) throw new Error('Stock quantity must be zero or a positive integer.');

    if (productData.imageUrl && typeof productData.imageUrl === 'string') {
      const img = productData.imageUrl.trim();
      if (img.startsWith('blob:') || img.startsWith('data:')) {
        throw new Error('Temporary blob or data image URLs cannot be saved. Product images must be uploaded to Cloudinary.');
      }
    }

    const specifications = {};
    filterValues.forEach((fv) => {
      if (fv.filterKey && fv.rawValue) {
        specifications[fv.filterKey] = fv.rawValue;
      }
    });

    try {
      const response = await api.put(`/products/${id}`, {
        categoryId,
        name: cleanName,
        brand: cleanBrand,
        model: (productData.model || '').trim() || null,
        price,
        stockQuantity,
        imageUrl: (productData.imageUrl || '').trim() || null,
        description: (productData.description || '').trim() || null,
        specifications: JSON.stringify(specifications),
      });

      return mapApiProduct(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Admin or Staff account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Admin and Staff accounts can update products.'
          : err.message || 'Failed to update product on backend database.');
      throw new Error(backendMessage);
    }
  },

  // Update Product Stock directly (PATCH /api/products/{id}/stock)
  async updateProductStock(productId, newStockQuantity, reason = '') {
    const id = Number(productId);
    const parsedStock = Number(newStockQuantity);
    if (isNaN(parsedStock) || parsedStock < 0) {
      throw new Error('Stock quantity must be zero or a positive integer.');
    }

    try {
      const response = await api.patch(`/products/${id}/stock`, {
        stockQuantity: parsedStock,
        reason: reason || undefined,
      });

      if (typeof window !== 'undefined') {
        window.dispatchEvent(
          new CustomEvent('pcforge_stock_updated', {
            detail: { productId: id, stockQuantity: parsedStock, reason },
          })
        );
      }

      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Admin or Staff account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Admin and Staff accounts can adjust stock.'
          : err.message || 'Failed to update stock on backend database.');
      throw new Error(backendMessage);
    }
  },

  // Adjust Product Stock by relative delta (e.g. +1, -1, +10)
  async adjustProductStockDelta(productId, delta, reason = '') {
    const id = Number(productId);
    const parsedDelta = Number(delta);
    if (isNaN(parsedDelta)) {
      throw new Error('Delta must be a valid number.');
    }

    try {
      const response = await api.patch(`/products/${id}/stock`, {
        delta: parsedDelta,
        reason: reason || undefined,
      });

      if (typeof window !== 'undefined') {
        window.dispatchEvent(
          new CustomEvent('pcforge_stock_updated', {
            detail: { productId: id, delta: parsedDelta, reason },
          })
        );
      }

      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Admin or Staff account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Admin and Staff accounts can adjust stock.'
          : err.message || 'Failed to adjust stock on backend database.');
      throw new Error(backendMessage);
    }
  },

  // Delete product safely from database (DELETE /api/products/{id})
  async deleteProduct(productId) {
    const id = Number(productId);
    if (!id || isNaN(id)) throw new Error('Invalid product ID for deletion.');

    try {
      const response = await api.delete(`/products/${id}`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Admin or Staff account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Admin and Staff accounts can delete products.'
          : err.message || 'Failed to delete product on backend database.');
      throw new Error(backendMessage);
    }
  },
};

export default productService;
