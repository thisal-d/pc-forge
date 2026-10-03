import 'package:flutter/material.dart';
import '../../data/catalog_repository.dart';

/// Reusable dynamic filter modal for Catalog & Component Picker (Nanotek-style)
class CatalogFilterModal extends StatefulWidget {
  final CatalogFilter initialFilter;
  final int? categoryId;
  final Function(CatalogFilter) onApply;

  const CatalogFilterModal({
    super.key,
    required this.initialFilter,
    this.categoryId,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required CatalogFilter initialFilter,
    int? categoryId,
    required Function(CatalogFilter) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CatalogFilterModal(
        initialFilter: initialFilter,
        categoryId: categoryId,
        onApply: onApply,
      ),
    );
  }

  static String getCategoryFilterTitle(int? categoryId) {
    switch (categoryId) {
      case 1:
        return 'Filter Processors (CPU)';
      case 2:
        return 'Filter Graphics Cards (GPU)';
      case 3:
        return 'Filter Motherboards';
      case 4:
        return 'Filter RAM / Memory';
      case 5:
        return 'Filter Power Supplies (PSU)';
      default:
        return 'Filter Components';
    }
  }

  static List<String> getBrandsForCategory(int? categoryId) {
    switch (categoryId) {
      case 1: // CPU
        return ['AMD', 'Intel'];
      case 2: // GPU
        return ['NVIDIA', 'AMD'];
      case 3: // Motherboard
        return ['ASUS', 'MSI', 'Gigabyte'];
      case 4: // RAM
        return ['G.Skill', 'Corsair', 'Kingston'];
      case 5: // PSU
        return ['Corsair', 'Seasonic', 'Cooler Master'];
      default:
        return ['ASUS', 'MSI', 'NVIDIA', 'AMD', 'Intel', 'Corsair', 'G.Skill'];
    }
  }

  @override
  State<CatalogFilterModal> createState() => _CatalogFilterModalState();
}

class _CatalogFilterModalState extends State<CatalogFilterModal> {
  late String? _selectedBrand;
  late double _minPrice;
  late double _maxPrice;
  late bool _inStockOnly;
  late String _sortBy;

  // Dynamic Facets
  late String? _selectedSocket;
  late String? _selectedChipset;
  late String? _selectedMemoryType;
  late String? _selectedSpeed;
  late String? _selectedCapacity;
  late String? _selectedVram;
  late String? _selectedEfficiency;

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.initialFilter.brand;
    _minPrice = widget.initialFilter.minPrice ?? 0;
    _maxPrice = widget.initialFilter.maxPrice ?? 500000;
    _inStockOnly = widget.initialFilter.inStockOnly;
    _sortBy = widget.initialFilter.sortBy;

    _selectedSocket = widget.initialFilter.socket;
    _selectedChipset = widget.initialFilter.chipset;
    _selectedMemoryType = widget.initialFilter.memoryType;
    _selectedSpeed = widget.initialFilter.speed;
    _selectedCapacity = widget.initialFilter.capacity;
    _selectedVram = widget.initialFilter.vram;
    _selectedEfficiency = widget.initialFilter.efficiencyRating;
  }

  void _reset() {
    setState(() {
      _selectedBrand = null;
      _minPrice = 0;
      _maxPrice = 500000;
      _inStockOnly = false;
      _sortBy = 'name_asc';
      _selectedSocket = null;
      _selectedChipset = null;
      _selectedMemoryType = null;
      _selectedSpeed = null;
      _selectedCapacity = null;
      _selectedVram = null;
      _selectedEfficiency = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catId = widget.categoryId ?? widget.initialFilter.categoryId;
    final isMotherboard = catId == 3;
    final isRam = catId == 4;
    final isGpu = catId == 2;
    final isCpu = catId == 1;
    final isPsu = catId == 5;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            (MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 12
                : 20),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CatalogFilterModal.getCategoryFilterTitle(catId),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const Divider(),

            // 1. Brand Filter
            const Text('Brand', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: CatalogFilterModal.getBrandsForCategory(catId).map((brand) {
                final isSelected = _selectedBrand?.toLowerCase() == brand.toLowerCase();
                return ChoiceChip(
                  label: Text(brand),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedBrand = selected ? brand : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 2. MOTHERBOARD SPECIFIC FILTERS
            if (isMotherboard) ...[
              const Text('Socket Type', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['AM5', 'LGA1700'].map((socket) {
                  final isSelected = _selectedSocket == socket;
                  return ChoiceChip(
                    label: Text(socket),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedSocket = sel ? socket : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text('Chipset', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['X670E', 'B650', 'Z790', 'B760'].map((chipset) {
                  final isSelected = _selectedChipset == chipset;
                  return ChoiceChip(
                    label: Text(chipset),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedChipset = sel ? chipset : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 3. RAM SPECIFIC FILTERS
            if (isRam) ...[
              const Text('DDR Type', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['DDR5', 'DDR4'].map((type) {
                  final isSelected = _selectedMemoryType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedMemoryType = sel ? type : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text('Memory Speed / Bus', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['3200 MHz', '5600 MHz', '6000 MHz'].map((speed) {
                  final isSelected = _selectedSpeed == speed;
                  return ChoiceChip(
                    label: Text(speed),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedSpeed = sel ? speed : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text('Capacity', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['16GB', '32GB'].map((cap) {
                  final isSelected = _selectedCapacity == cap;
                  return ChoiceChip(
                    label: Text(cap),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedCapacity = sel ? cap : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 4. GPU SPECIFIC FILTERS
            if (isGpu) ...[
              const Text('VRAM Capacity', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['8GB', '12GB', '24GB'].map((vram) {
                  final isSelected = _selectedVram == vram;
                  return ChoiceChip(
                    label: Text(vram),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedVram = sel ? vram : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 5. CPU SPECIFIC FILTERS
            if (isCpu) ...[
              const Text('Socket Type', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['AM5', 'LGA1700'].map((socket) {
                  final isSelected = _selectedSocket == socket;
                  return ChoiceChip(
                    label: Text(socket),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedSocket = sel ? socket : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 6. PSU SPECIFIC FILTERS
            if (isPsu) ...[
              const Text('Efficiency Rating', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['80+ Gold', '80+ Bronze'].map((eff) {
                  final isSelected = _selectedEfficiency == eff;
                  return ChoiceChip(
                    label: Text(eff),
                    selected: isSelected,
                    onSelected: (sel) => setState(() => _selectedEfficiency = sel ? eff : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Price Range
            const Text('Price Range', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'LKR ${_minPrice.toInt()} - LKR ${_maxPrice.toInt()}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            RangeSlider(
              values: RangeValues(_minPrice, _maxPrice),
              min: 0,
              max: 500000,
              divisions: 50,
              labels: RangeLabels('LKR ${_minPrice.toInt()}', 'LKR ${_maxPrice.toInt()}'),
              onChanged: (values) {
                setState(() {
                  _minPrice = values.start;
                  _maxPrice = values.end;
                });
              },
            ),

            // In Stock Toggle
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('In Stock Only'),
              value: _inStockOnly,
              onChanged: (val) => setState(() => _inStockOnly = val ?? false),
            ),

            // Sort By
            const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'name_asc', child: Text('Name (A - Z)')),
                DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
                DropdownMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
                DropdownMenuItem(value: 'stock_desc', child: Text('Highest Stock')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _sortBy = val);
              },
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              key: const Key('apply_filters_btn'),
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(
                  widget.initialFilter.copyWith(
                    categoryId: catId,
                    brand: _selectedBrand,
                    clearBrand: _selectedBrand == null,
                    minPrice: _minPrice > 0 ? _minPrice : null,
                    maxPrice: _maxPrice < 500000 ? _maxPrice : null,
                    inStockOnly: _inStockOnly,
                    sortBy: _sortBy,
                    socket: _selectedSocket,
                    clearSocket: _selectedSocket == null,
                    chipset: _selectedChipset,
                    clearChipset: _selectedChipset == null,
                    memoryType: _selectedMemoryType,
                    clearMemoryType: _selectedMemoryType == null,
                    speed: _selectedSpeed,
                    clearSpeed: _selectedSpeed == null,
                    capacity: _selectedCapacity,
                    clearCapacity: _selectedCapacity == null,
                    vram: _selectedVram,
                    clearVram: _selectedVram == null,
                    efficiencyRating: _selectedEfficiency,
                    clearEfficiencyRating: _selectedEfficiency == null,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic active facet chips row (matching store catalog)
class ActiveFilterChipsRow extends StatelessWidget {
  final CatalogFilter filter;
  final Function(CatalogFilter) onFilterChanged;
  final VoidCallback? onClearAll;

  const ActiveFilterChipsRow({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.onClearAll,
  });

  Widget _chip(BuildContext context, String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDeleted,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!filter.hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Active: ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (filter.brand != null)
              _chip(context, 'Brand: ${filter.brand!}', () {
                onFilterChanged(filter.copyWith(clearBrand: true));
              }),
            if (filter.socket != null)
              _chip(context, 'Socket: ${filter.socket!}', () {
                onFilterChanged(filter.copyWith(clearSocket: true));
              }),
            if (filter.chipset != null)
              _chip(context, 'Chipset: ${filter.chipset!}', () {
                onFilterChanged(filter.copyWith(clearChipset: true));
              }),
            if (filter.memoryType != null)
              _chip(context, 'Type: ${filter.memoryType!}', () {
                onFilterChanged(filter.copyWith(clearMemoryType: true));
              }),
            if (filter.speed != null)
              _chip(context, 'Speed: ${filter.speed!}', () {
                onFilterChanged(filter.copyWith(clearSpeed: true));
              }),
            if (filter.capacity != null)
              _chip(context, 'Capacity: ${filter.capacity!}', () {
                onFilterChanged(filter.copyWith(clearCapacity: true));
              }),
            if (filter.vram != null)
              _chip(context, 'VRAM: ${filter.vram!}', () {
                onFilterChanged(filter.copyWith(clearVram: true));
              }),
            if (filter.efficiencyRating != null)
              _chip(context, 'Eff: ${filter.efficiencyRating!}', () {
                onFilterChanged(filter.copyWith(clearEfficiencyRating: true));
              }),
            if (filter.minPrice != null || filter.maxPrice != null)
              _chip(
                context,
                'LKR ${(filter.minPrice ?? 0).toInt()}-LKR ${(filter.maxPrice ?? 500000).toInt()}',
                () {
                  onFilterChanged(CatalogFilter(
                    categoryId: filter.categoryId,
                    searchQuery: filter.searchQuery,
                    brand: filter.brand,
                    inStockOnly: filter.inStockOnly,
                    sortBy: filter.sortBy,
                    socket: filter.socket,
                    chipset: filter.chipset,
                    formFactor: filter.formFactor,
                    memoryType: filter.memoryType,
                    speed: filter.speed,
                    capacity: filter.capacity,
                    vram: filter.vram,
                    efficiencyRating: filter.efficiencyRating,
                  ));
                },
              ),
            if (filter.inStockOnly)
              _chip(context, 'In Stock', () {
                onFilterChanged(filter.copyWith(inStockOnly: false));
              }),
            TextButton(
              onPressed: onClearAll ??
                  () {
                    onFilterChanged(CatalogFilter(
                      categoryId: filter.categoryId,
                      searchQuery: filter.searchQuery,
                    ));
                  },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear all', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
