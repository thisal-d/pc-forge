import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pc_forge_app_bar.dart';
import '../../../../core/widgets/product_card.dart';
import '../../../cart/data/cart_service.dart';
import '../../data/catalog_repository.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../widgets/catalog_filter_modal.dart';

class CategoriesScreen extends StatefulWidget {
  final int? initialCategoryId;

  const CategoriesScreen({super.key, this.initialCategoryId});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  final CatalogRepository _repository = CatalogRepository();
  final CartService _cartService = CartService.instance;

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  int? _selectedCategoryId;
  CatalogFilter _filter = const CatalogFilter();
  bool _isLoading = true;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _selectedCategoryId = widget.initialCategoryId;
    if (_selectedCategoryId != null) {
      _filter = CatalogFilter(categoryId: _selectedCategoryId);
    }
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await _repository.getCategories();
    final products = await _repository.getProducts(filter: _filter);

    if (mounted) {
      setState(() {
        _categories = categories;
        _products = products;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    }
  }

  Future<void> _selectCategory(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _filter = CatalogFilter(categoryId: categoryId);
      _isLoading = true;
    });
    final products = await _repository.getProducts(filter: _filter);
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
      _animController.forward(from: 0);
    }
  }

  Future<void> _applyFilter(CatalogFilter newFilter) async {
    setState(() {
      _filter = newFilter;
      _isLoading = true;
    });
    final products = await _repository.getProducts(filter: _filter);
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  void _handleAddToCart(ProductModel product) {
    final error = _cartService.addItem(product, quantity: 1);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.alertRed),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.name} to Cart'),
          backgroundColor: AppColors.stockGreen,
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
      categoryId: _selectedCategoryId,
      onApply: _applyFilter,
    );
  }

  // Category accent colors for visual variety
  static const List<List<Color>> _categoryGradients = [
    [Color(0xFF6366F1), Color(0xFF818CF8)], // Indigo - CPU
    [Color(0xFF0EA5E9), Color(0xFF38BDF8)], // Sky - GPU
    [Color(0xFF10B981), Color(0xFF34D399)], // Emerald - Motherboard
    [Color(0xFFF59E0B), Color(0xFFFBBF24)], // Amber - RAM
    [Color(0xFFEF4444), Color(0xFFF87171)], // Red - PSU
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)], // Violet - Storage
    [Color(0xFF06B6D4), Color(0xFF22D3EE)], // Cyan - Cooling
    [Color(0xFF64748B), Color(0xFF94A3B8)], // Slate - Case
  ];

  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'cpu':
        return Icons.memory_rounded;
      case 'gpu':
        return Icons.videogame_asset_rounded;
      case 'motherboard':
        return Icons.developer_board_rounded;
      case 'ram':
        return Icons.view_column_rounded;
      case 'psu':
        return Icons.power_rounded;
      case 'storage':
        return Icons.storage_rounded;
      case 'cooling':
        return Icons.ac_unit_rounded;
      case 'case':
        return Icons.computer_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  String _getCategoryTagline(String name) {
    switch (name.toLowerCase()) {
      case 'cpu':
        return 'Processors & APUs';
      case 'gpu':
        return 'Graphics Cards';
      case 'motherboard':
        return 'Main Circuit Boards';
      case 'ram':
        return 'Memory Modules';
      case 'psu':
        return 'Power Supplies';
      case 'storage':
        return 'NVMe & SATA SSDs';
      case 'cooling':
        return 'Air & Liquid Coolers';
      case 'case':
        return 'PC Chassis & Cases';
      default:
        return 'View Components';
    }
  }

  List<Color> _getGradientForCategory(int index) {
    return _categoryGradients[index % _categoryGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectedCategoryId != null
          ? _buildProductAppBar()
          : const PCForgeAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _selectedCategoryId == null
              ? _buildCategoryBrowse()
              : _buildFilteredProductsView(),
    );
  }

  // App bar for the product list view (when a category is selected)
  PreferredSizeWidget _buildProductAppBar() {
    final catName = _categories
        .firstWhere(
          (c) => c.categoryId == _selectedCategoryId,
          orElse: () => const CategoryModel(categoryId: 0, name: 'Products'),
        )
        .name;

    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.primaryDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.specPillBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: AppColors.primaryDark),
        ),
        onPressed: () => _selectCategory(null),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            catName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          Text(
            '${_products.length} components',
            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('category_screen_filter_btn'),
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _filter.hasActiveFilters
                  ? AppColors.primaryBlue.withValues(alpha: 0.1)
                  : AppColors.specPillBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _filter.hasActiveFilters
                    ? AppColors.primaryBlue
                    : AppColors.border,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: _filter.hasActiveFilters
                  ? AppColors.primaryBlue
                  : AppColors.primaryDark,
            ),
          ),
          onPressed: _showFilterModal,
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  Widget _buildCategoryBrowse() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Hero Banner
        SliverToBoxAdapter(child: _buildCategoryHero()),

        // Section Header
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hardware Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap a category to explore compatible parts',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Category Grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = _categories[index];
                final gradient = _getGradientForCategory(index);
                return _buildCategoryCard(cat, gradient, index);
              },
              childCount: _categories.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryHero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 110,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3BB6), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066FF).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Browse By Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_categories.length} hardware categories',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _heroPill(Icons.verified_rounded, 'Compatible Parts'),
                          const SizedBox(width: 8),
                          _heroPill(Icons.bolt_rounded, 'In Stock'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel cat, List<Color> gradient, int index) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final delay = (index * 0.08).clamp(0.0, 0.7);
        final start = delay;
        final end = (delay + 0.4).clamp(0.0, 1.0);
        final curvedAnim = CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: curvedAnim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(curvedAnim),
            child: child,
          ),
        );
      },
      child: _CategoryCard(
        category: cat,
        gradient: gradient,
        icon: _getCategoryIcon(cat.name),
        tagline: _getCategoryTagline(cat.name),
        onTap: () => _selectCategory(cat.categoryId),
      ),
    );
  }

  Widget _buildFilteredProductsView() {
    final selectedCat = _categories.firstWhere(
      (c) => c.categoryId == _selectedCategoryId,
      orElse: () => const CategoryModel(categoryId: 0, name: 'Products'),
    );

    return Column(
      children: [
        // Active Facets Row
        if (_filter.hasActiveFilters)
          ActiveFilterChipsRow(
            filter: _filter,
            onFilterChanged: _applyFilter,
            onClearAll: () =>
                _applyFilter(CatalogFilter(categoryId: _selectedCategoryId)),
          ),

        // Products List
        Expanded(
          child: _products.isEmpty
              ? _buildEmptyState(selectedCat.name)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return ProductCard(
                      product: product,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.productDetail,
                        arguments: product,
                      ),
                      onAddToCart: () => _handleAddToCart(product),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String catName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.specPillBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 36, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            const Text(
              'No components found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No $catName parts match your active filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  _applyFilter(CatalogFilter(categoryId: _selectedCategoryId)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium category card with gradient icon container and animated press
class _CategoryCard extends StatefulWidget {
  final CategoryModel category;
  final List<Color> gradient;
  final IconData icon;
  final String tagline;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.gradient,
    required this.icon,
    required this.tagline,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.04,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppColors.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: gradient icon + arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gradient icon container
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: widget.gradient[0].withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                    // Arrow indicator
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.specPillBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Category name
                Text(
                  widget.category.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),

                // Tagline / description
                Text(
                  widget.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 10),

                // Bottom: gradient accent bar
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: widget.gradient),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
