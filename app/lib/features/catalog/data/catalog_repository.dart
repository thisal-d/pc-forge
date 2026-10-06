import 'models/category_model.dart';
import 'models/category_filter_model.dart';
import 'models/product_model.dart';
import '../../../services/api_service.dart';

class CatalogFilter {
  final int? categoryId;
  final String? categoryName;
  final String? brand;
  final String? searchQuery;
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final String sortBy; // 'name_asc', 'price_asc', 'price_desc', 'stock_desc'

  // Dynamic Facets Map: filterKey -> selectedValue
  final Map<String, String> dynamicFilters;

  // Dynamic Facets (legacy convenience getters & compatibility)
  final String? socket;           // Motherboard, CPU
  final String? chipset;          // Motherboard
  final String? formFactor;       // Motherboard, PSU
  final String? memoryType;       // Motherboard, RAM
  final String? speed;            // RAM
  final String? capacity;         // RAM
  final String? vram;             // GPU
  final String? efficiencyRating; // PSU

  const CatalogFilter({
    this.categoryId,
    this.categoryName,
    this.brand,
    this.searchQuery,
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.sortBy = 'name_asc',
    this.dynamicFilters = const {},
    this.socket,
    this.chipset,
    this.formFactor,
    this.memoryType,
    this.speed,
    this.capacity,
    this.vram,
    this.efficiencyRating,
  });

  bool get hasActiveFilters =>
      brand != null ||
      minPrice != null ||
      maxPrice != null ||
      inStockOnly ||
      socket != null ||
      chipset != null ||
      formFactor != null ||
      memoryType != null ||
      speed != null ||
      capacity != null ||
      vram != null ||
      efficiencyRating != null ||
      dynamicFilters.isNotEmpty;

  CatalogFilter copyWith({
    int? categoryId,
    bool clearCategory = false,
    String? categoryName,
    bool clearCategoryName = false,
    String? brand,
    bool clearBrand = false,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    bool? inStockOnly,
    String? sortBy,
    String? socket,
    bool clearSocket = false,
    String? chipset,
    bool clearChipset = false,
    String? formFactor,
    bool clearFormFactor = false,
    String? memoryType,
    bool clearMemoryType = false,
    String? speed,
    bool clearSpeed = false,
    String? capacity,
    bool clearCapacity = false,
    String? vram,
    bool clearVram = false,
    String? efficiencyRating,
    bool clearEfficiencyRating = false,
    Map<String, String>? dynamicFilters,
    bool clearDynamicFilters = false,
  }) {
    return CatalogFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategoryName ? null : (categoryName ?? this.categoryName),
      brand: clearBrand ? null : (brand ?? this.brand),
      searchQuery: searchQuery ?? this.searchQuery,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      sortBy: sortBy ?? this.sortBy,
      dynamicFilters: clearDynamicFilters
          ? const {}
          : (dynamicFilters ?? this.dynamicFilters),
      socket: clearSocket ? null : (socket ?? this.socket),
      chipset: clearChipset ? null : (chipset ?? this.chipset),
      formFactor: clearFormFactor ? null : (formFactor ?? this.formFactor),
      memoryType: clearMemoryType ? null : (memoryType ?? this.memoryType),
      speed: clearSpeed ? null : (speed ?? this.speed),
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      vram: clearVram ? null : (vram ?? this.vram),
      efficiencyRating: clearEfficiencyRating ? null : (efficiencyRating ?? this.efficiencyRating),
    );
  }
}

class CatalogRepository {
  final ApiService _apiService;

  CatalogRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<List<CategoryModel>> getCategories() async {
    try {
      final apiCats = await _apiService.fetchCategories();
      if (apiCats.isNotEmpty) {
        return apiCats.map((c) => CategoryModel.fromJson(c)).toList();
      }
    } catch (e) {
      // Network error or empty list
    }
    return [];
  }

  Future<List<CategoryFilterModel>> getCategoryFilters(int categoryId) async {
    try {
      final filters = await _apiService.fetchCategoryFilters(categoryId);
      return filters.map((f) => CategoryFilterModel.fromJson(f)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ProductModel>> getProducts({CatalogFilter? filter}) async {
    try {
      final apiProds = await _apiService.fetchProducts(
        categoryId: filter?.categoryId,
        brand: filter?.brand,
        searchQuery: filter?.searchQuery,
        minPrice: filter?.minPrice,
        maxPrice: filter?.maxPrice,
        inStockOnly: filter?.inStockOnly ?? false,
        sortBy: filter?.sortBy ?? 'name_asc',
        socket: filter?.socket,
        chipset: filter?.chipset,
        memoryType: filter?.memoryType,
        speed: filter?.speed,
        capacity: filter?.capacity,
        vram: filter?.vram,
        efficiency: filter?.efficiencyRating,
        dynamicFilters: filter?.dynamicFilters,
      );
      return apiProds
          .map((p) => ProductModel.fromJson(p))
          .where((p) => p.isActive)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ProductModel?> getProductById(int id) async {
    try {
      final res = await _apiService.fetchProductById(id);
      return ProductModel.fromJson(res);
    } catch (e) {
      return null;
    }
  }
}
