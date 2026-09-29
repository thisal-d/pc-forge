import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../catalog/data/catalog_repository.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../../catalog/presentation/widgets/catalog_filter_modal.dart';
import '../../data/models/custom_build_slot.dart';

class ComponentPickerSheet extends StatefulWidget {
  final BuildSlotInfo slotInfo;
  final Function(ProductModel) onSelect;
  final CatalogRepository? repository;

  const ComponentPickerSheet({
    super.key,
    required this.slotInfo,
    required this.onSelect,
    this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required BuildSlotInfo slotInfo,
    required Function(ProductModel) onSelect,
    CatalogRepository? repository,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComponentPickerSheet(
        slotInfo: slotInfo,
        onSelect: onSelect,
        repository: repository,
      ),
    );
  }

  @override
  State<ComponentPickerSheet> createState() => _ComponentPickerSheetState();
}

class _ComponentPickerSheetState extends State<ComponentPickerSheet> {
  late final CatalogRepository _repository;
  final _searchController = TextEditingController();

  List<ProductModel> _products = [];
  bool _isLoading = true;
  late CatalogFilter _filter;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CatalogRepository();
    _filter = CatalogFilter(
      categoryId: widget.slotInfo.categoryId,
    );
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    final products = await _repository.getProducts(filter: _filter);
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  Future<void> _applyFilter(CatalogFilter newFilter) async {
    setState(() {
      _filter = newFilter;
      _isLoading = true;
    });
    final products = await _repository.getProducts(filter: _filter);
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    _applyFilter(_filter.copyWith(searchQuery: query.trim()));
  }

  void _openFilterModal() {
    CatalogFilterModal.show(
      context,
      initialFilter: _filter,
      categoryId: widget.slotInfo.categoryId,
      onApply: (applied) => _applyFilter(applied),
    );
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'price_asc':
        return 'Price: Low to High';
      case 'price_desc':
        return 'Price: High to Low';
      case 'stock_desc':
        return 'Highest Stock';
      case 'name_asc':
      default:
        return 'Name (A - Z)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _filter.hasActiveFilters;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            (MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 8
                : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.slotInfo.icon,
                        size: 22, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select ${widget.slotInfo.title}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        'Showing compatible store inventory',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.secondaryText),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.primaryDark),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.slotInfo.title.toLowerCase()}...',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.secondaryText),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 20, color: AppColors.secondaryText),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: AppColors.secondaryText),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryBlue, width: 1.5),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('component_picker_filter_btn'),
                onPressed: _openFilterModal,
                icon: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: hasActiveFilters
                      ? AppColors.primaryBlue
                      : AppColors.secondaryText,
                ),
                label: Text(
                  hasActiveFilters ? 'Active' : 'Filter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hasActiveFilters
                        ? AppColors.primaryBlue
                        : AppColors.primaryDark,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  backgroundColor: hasActiveFilters
                      ? AppColors.primaryBlue.withValues(alpha: 0.08)
                      : AppColors.surface,
                  side: BorderSide(
                    color: hasActiveFilters
                        ? AppColors.primaryBlue
                        : AppColors.border,
                    width: hasActiveFilters ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          // Active Facets Row
          ActiveFilterChipsRow(
            filter: _filter,
            onFilterChanged: _applyFilter,
            onClearAll: () {
              _searchController.clear();
              _applyFilter(
                  CatalogFilter(categoryId: widget.slotInfo.categoryId));
            },
          ),

          // Product count and sort indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_products.length} component${_products.length == 1 ? '' : 's'} found',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_filter.sortBy != 'name_asc')
                  Text(
                    'Sorted: ${_getSortLabel(_filter.sortBy)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),

          // Components List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    ),
                  )
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 40,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching components found',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try clearing filters or changing search keywords.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            if (hasActiveFilters) ...[
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilter(CatalogFilter(
                                      categoryId: widget.slotInfo.categoryId));
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Reset All Filters'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppColors.softShadow,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(widget.slotInfo.icon,
                                      color: AppColors.primaryBlue, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: AppColors.primaryDark,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          if (p.socket != null)
                                            _badge('Socket ${p.socket!}'),
                                          if (p.memoryType != null)
                                            _badge(p.memoryType!),
                                          if (p.powerWattage != null)
                                            _badge('${p.powerWattage}W'),
                                          if (p.vram != null)
                                            _badge(p.vram!),
                                          _badge(
                                            p.isInStock
                                                ? 'In Stock (${p.stockQuantity})'
                                                : 'Out of Stock',
                                            color: p.isInStock
                                                ? AppColors.stockGreen
                                                : AppColors.alertRed,
                                            bgColor: p.isInStock
                                                ? const Color(0xFFECFDF5)
                                                : const Color(0xFFFEF2F2),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'LKR ${p.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                          ElevatedButton(
                                            key: Key(
                                                'select_part_${p.productId}'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryBlue,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  AppColors.border,
                                              disabledForegroundColor:
                                                  AppColors.secondaryText,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              elevation: 0,
                                            ),
                                            onPressed: p.isInStock
                                                ? () {
                                                    widget.onSelect(p);
                                                    Navigator.pop(context);
                                                  }
                                                : null,
                                            child: const Text(
                                              'Choose',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, {Color? color, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.specPillBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color != null
              ? color.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.specText,
        ),
      ),
    );
  }
}
