import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/category_chip_selector.dart';
import '../../../../core/widgets/pc_forge_app_bar.dart';
import '../../../../core/widgets/product_card.dart';
import '../../../../core/widgets/promo_banner.dart';
import '../../../../core/widgets/search_bar_widget.dart';
import '../../../cart/data/cart_service.dart';
import '../../data/catalog_repository.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../widgets/catalog_filter_modal.dart';

class CatalogScreen extends StatefulWidget {
  final bool isHomeTab;
  final CatalogRepository? repository;

  const CatalogScreen({
    super.key,
    this.isHomeTab = false,
    this.repository,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogRepository _repository;
  final CartService _cartService = CartService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  bool _isLoading = true;
  int _displayedCount = 10;
  bool _isLoadingMore = false;

  CatalogFilter _filter = const CatalogFilter();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CatalogRepository();
    _scrollController.addListener(_onScroll);
    _loadCatalog();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _displayedCount >= _products.length) return;
    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _displayedCount = (_displayedCount + 10).clamp(0, _products.length);
      _isLoadingMore = false;
    });
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _displayedCount = 10;
      _isLoadingMore = false;
    });
    final categories = await _repository.getCategories();
    final products = await _repository.getProducts(filter: _filter);

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _products = products;
      _isLoading = false;
    });
  }

  Future<void> _applyFilter(CatalogFilter newFilter) async {
    setState(() {
      _filter = newFilter;
      _isLoading = true;
      _displayedCount = 10;
      _isLoadingMore = false;
    });
    final products = await _repository.getProducts(filter: _filter);
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _onCategorySelected(int? categoryId) {
    _applyFilter(CatalogFilter(
      categoryId: categoryId,
      searchQuery: _filter.searchQuery,
      sortBy: _filter.sortBy,
      inStockOnly: _filter.inStockOnly,
    ));
  }

  void _onSearchChanged(String query) {
    _applyFilter(_filter.copyWith(searchQuery: query));
  }

  void _handleAddToCart(ProductModel product) {
    final error = _cartService.addItem(product, quantity: 1);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.alertRed,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.name} to Cart'),
          backgroundColor: AppColors.stockGreen,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
          ),
        ),
      );
    }
  }

  void _showFilterModal() {
    CatalogFilterModal.show(
      context,
      initialFilter: _filter,
      categoryId: _filter.categoryId,
      onApply: _applyFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PCForgeAppBar(),
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: _loadCatalog,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Promo Hero Banner
            SliverToBoxAdapter(
              child: PromoBanner(
                onTap: () => Navigator.pushNamed(context, AppRoutes.buildPc),
              ),
            ),

            // Custom PC Builder Quick Access Strip
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom PC Builder',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            'Assemble your rig with live compatibility checks',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('catalog_build_pc_banner_btn'),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.buildPc),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Build Rig', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

            // Search & Filter Row
            SliverToBoxAdapter(
              child: SearchBarWidget(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onFilterPressed: _showFilterModal,
                onScannerPressed: () => Navigator.pushNamed(context, AppRoutes.scanner),
                hasActiveFilters: _filter.hasActiveFilters,
              ),
            ),

            // Category Horizontal Pill Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CategoryChipSelector(
                  categories: _categories,
                  selectedCategoryId: _filter.categoryId,
                  onCategorySelected: _onCategorySelected,
                ),
              ),
            ),

            // Dynamic Active Facets Row
            SliverToBoxAdapter(
              child: ActiveFilterChipsRow(
                filter: _filter,
                onFilterChanged: _applyFilter,
                onClearAll: () => _applyFilter(CatalogFilter(
                  categoryId: _filter.categoryId,
                  searchQuery: _filter.searchQuery,
                  sortBy: _filter.sortBy,
                  inStockOnly: _filter.inStockOnly,
                )),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),

            // Products Feed Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _filter.categoryId == null
                          ? 'Featured Hardware'
                          : '${_categories.firstWhere((c) => c.categoryId == _filter.categoryId, orElse: () => const CategoryModel(categoryId: 0, name: 'Component')).name} Components',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      '${_products.length} parts found',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),

            // Product List Items
            _isLoading
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primaryBlue),
                    ),
                  )
                : _products.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 52, color: AppColors.secondaryText),
                                const SizedBox(height: 12),
                                const Text(
                                  'No products match these filters.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilter(CatalogFilter(categoryId: _filter.categoryId));
                                  },
                                  child: const Text('Reset Category Filters'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final product = _products[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ProductCard(
                                  product: product,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.productDetail,
                                      arguments: product,
                                    );
                                  },
                                  onAddToCart: () => _handleAddToCart(product),
                                ),
                              );
                            },
                            childCount: _products.length < _displayedCount
                                ? _products.length
                                : _displayedCount,
                          ),
                        ),
                      ),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
              )
            else if (_products.isNotEmpty &&
                _products.length > 10 &&
                _displayedCount >= _products.length)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  child: Center(
                    child: Text(
                      'Showing all ${_products.length} products',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
          ],
        ),
      ),
    );
  }
}
