import 'package:flutter/material.dart';
import '../../data/catalog_repository.dart';
import '../../data/models/category_filter_model.dart';
import '../../../../core/theme/app_colors.dart';

/// Reusable dynamic filter modal for Catalog & Component Picker (Dynamic Facets)
class CatalogFilterModal extends StatefulWidget {
  final CatalogFilter initialFilter;
  final int? categoryId;
  final String? categoryName;
  final CatalogRepository? repository;
  final Function(CatalogFilter) onApply;

  const CatalogFilterModal({
    super.key,
    required this.initialFilter,
    this.categoryId,
    this.categoryName,
    this.repository,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required CatalogFilter initialFilter,
    int? categoryId,
    String? categoryName,
    CatalogRepository? repository,
    required Function(CatalogFilter) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CatalogFilterModal(
        initialFilter: initialFilter,
        categoryId: categoryId,
        categoryName: categoryName,
        repository: repository,
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
        return ['NVIDIA', 'AMD', 'ASUS', 'MSI', 'Gigabyte', 'Zotac'];
      case 3: // Motherboard
        return ['ASUS', 'MSI', 'Gigabyte', 'ASRock'];
      case 4: // RAM
        return ['G.Skill', 'Corsair', 'Kingston', 'TeamGroup'];
      case 5: // PSU
        return ['Corsair', 'Seasonic', 'Cooler Master', 'Thermaltake'];
      default:
        return ['ASUS', 'MSI', 'NVIDIA', 'AMD', 'Intel', 'Corsair', 'G.Skill', 'Gigabyte', 'Zotac'];
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

  // Dynamic Facets Map: filterKey -> selectedValue
  late Map<String, String> _dynamicFilters;

  // Controllers for text/custom filter inputs
  final Map<String, TextEditingController> _textControllers = {};

  List<CategoryFilterModel> _filters = [];
  List<String> _brands = [];
  bool _loading = true;
  String? _categoryTitle;
  int? _resolvedCatId;

  @override
  void initState() {
    super.initState();
    _resolvedCatId = widget.categoryId ?? widget.initialFilter.categoryId;
    _categoryTitle = widget.categoryName ?? widget.initialFilter.categoryName;
    _selectedBrand = widget.initialFilter.brand;
    _minPrice = widget.initialFilter.minPrice ?? 0;
    _maxPrice = widget.initialFilter.maxPrice ?? 500000;
    _inStockOnly = widget.initialFilter.inStockOnly;
    _sortBy = widget.initialFilter.sortBy;

    _dynamicFilters = Map<String, String>.from(widget.initialFilter.dynamicFilters);

    // Map legacy fields into dynamicFilters if not already present
    if (widget.initialFilter.socket != null) {
      _dynamicFilters.putIfAbsent('socket', () => widget.initialFilter.socket!);
    }
    if (widget.initialFilter.chipset != null) {
      _dynamicFilters.putIfAbsent('chipset', () => widget.initialFilter.chipset!);
    }
    if (widget.initialFilter.formFactor != null) {
      _dynamicFilters.putIfAbsent('form_factor', () => widget.initialFilter.formFactor!);
    }
    if (widget.initialFilter.memoryType != null) {
      _dynamicFilters.putIfAbsent('memory_type', () => widget.initialFilter.memoryType!);
    }
    if (widget.initialFilter.speed != null) {
      _dynamicFilters.putIfAbsent('speed', () => widget.initialFilter.speed!);
    }
    if (widget.initialFilter.capacity != null) {
      _dynamicFilters.putIfAbsent('capacity', () => widget.initialFilter.capacity!);
    }
    if (widget.initialFilter.vram != null) {
      _dynamicFilters.putIfAbsent('vram', () => widget.initialFilter.vram!);
    }
    if (widget.initialFilter.efficiencyRating != null) {
      _dynamicFilters.putIfAbsent('efficiency', () => widget.initialFilter.efficiencyRating!);
    }

    // Populate default brands synchronously so UI is never blank
    _brands = CatalogFilterModal.getBrandsForCategory(_resolvedCatId);

    _loadCategoryFiltersAndBrands();
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String key, String initialValue) {
    if (!_textControllers.containsKey(key)) {
      _textControllers[key] = TextEditingController(text: initialValue);
    }
    return _textControllers[key]!;
  }

  Future<void> _loadCategoryFiltersAndBrands() async {
    final catId = _resolvedCatId;
    List<CategoryFilterModel> loadedFilters = [];
    List<String> loadedBrands = [];

    if (catId != null && catId > 0) {
      try {
        final repo = widget.repository ?? CatalogRepository();
        final rawFilters = await repo.getCategoryFilters(catId);
        loadedFilters = rawFilters
            .where((f) => f.isFilterable)
            .toList();

        if (loadedFilters.isNotEmpty && (_categoryTitle == null || _categoryTitle!.isEmpty)) {
          _categoryTitle = loadedFilters.first.categoryName;
        }

        // Also fetch category products to discover actual brands present in this category
        final prods = await repo.getProducts(filter: CatalogFilter(categoryId: catId));
        final brandSet = <String>{};
        for (final p in prods) {
          final b = p.brand;
          if (b != null && b.trim().isNotEmpty) {
            brandSet.add(b.trim());
          }
        }
        if (brandSet.isNotEmpty) {
          loadedBrands = brandSet.toList()..sort();
        }
      } catch (_) {
        // Fallback gracefully on network error
      }
    }

    if (loadedBrands.isEmpty) {
      loadedBrands = CatalogFilterModal.getBrandsForCategory(catId);
    }

    if (mounted) {
      setState(() {
        if (loadedFilters.isNotEmpty) {
          _filters = loadedFilters;
        }
        _brands = loadedBrands;
        _loading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedBrand = null;
      _minPrice = 0;
      _maxPrice = 500000;
      _inStockOnly = false;
      _sortBy = 'name_asc';
      _dynamicFilters.clear();
      for (final c in _textControllers.values) {
        c.clear();
      }
    });
  }

  List<Widget> _buildLegacyFallbackFilters(int? catId) {
    final isMotherboard = catId == 3;
    final isRam = catId == 4;
    final isGpu = catId == 2;
    final isCpu = catId == 1;
    final isPsu = catId == 5;

    final widgets = <Widget>[];

    if (isMotherboard || isCpu) {
      widgets.add(const Text('Socket Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Wrap(
        spacing: 8,
        children: ['AM5', 'LGA1700'].map((socket) {
          final isSelected = _dynamicFilters['socket'] == socket;
          return ChoiceChip(
            label: Text(socket),
            selected: isSelected,
            onSelected: (sel) => setState(() {
              if (sel) {
                _dynamicFilters['socket'] = socket;
              } else {
                _dynamicFilters.remove('socket');
              }
            }),
          );
        }).toList(),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    if (isMotherboard) {
      widgets.add(const Text('Chipset', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Wrap(
        spacing: 8,
        children: ['X670E', 'B650', 'Z790', 'B760'].map((chipset) {
          final isSelected = _dynamicFilters['chipset'] == chipset;
          return ChoiceChip(
            label: Text(chipset),
            selected: isSelected,
            onSelected: (sel) => setState(() {
              if (sel) {
                _dynamicFilters['chipset'] = chipset;
              } else {
                _dynamicFilters.remove('chipset');
              }
            }),
          );
        }).toList(),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    if (isRam) {
      widgets.add(const Text('DDR Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Wrap(
        spacing: 8,
        children: ['DDR5', 'DDR4'].map((type) {
          final isSelected = _dynamicFilters['memory_type'] == type;
          return ChoiceChip(
            label: Text(type),
            selected: isSelected,
            onSelected: (sel) => setState(() {
              if (sel) {
                _dynamicFilters['memory_type'] = type;
              } else {
                _dynamicFilters.remove('memory_type');
              }
            }),
          );
        }).toList(),
      ));
      widgets.add(const SizedBox(height: 16));

      widgets.add(const Text('Capacity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Wrap(
        spacing: 8,
        children: ['16GB', '32GB', '64GB'].map((cap) {
          final isSelected = _dynamicFilters['capacity'] == cap;
          return ChoiceChip(
            label: Text(cap),
            selected: isSelected,
            onSelected: (sel) => setState(() {
              if (sel) {
                _dynamicFilters['capacity'] = cap;
              } else {
                _dynamicFilters.remove('capacity');
              }
            }),
          );
        }).toList(),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    if (isGpu) {
      widgets.add(const Text('VRAM Capacity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Wrap(
        spacing: 8,
        children: ['8GB', '12GB', '16GB', '24GB'].map((vram) {
          final isSelected = _dynamicFilters['vram'] == vram;
          return ChoiceChip(
            label: Text(vram),
            selected: isSelected,
            onSelected: (sel) => setState(() {
              if (sel) {
                _dynamicFilters['vram'] = vram;
              } else {
                _dynamicFilters.remove('vram');
              }
            }),
          );
        }).toList(),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    if (isPsu) {
      widgets.add(const Text('Efficiency Rating', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Wrap(
        spacing: 8,
        children: ['80+ Gold', '80+ Bronze', '80+ Platinum'].map((eff) {
          final isSelected = _dynamicFilters['efficiency'] == eff;
          return ChoiceChip(
            label: Text(eff),
            selected: isSelected,
            onSelected: (sel) => setState(() {
              if (sel) {
                _dynamicFilters['efficiency'] = eff;
              } else {
                _dynamicFilters.remove('efficiency');
              }
            }),
          );
        }).toList(),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final title = (_resolvedCatId != null && _resolvedCatId! >= 1 && _resolvedCatId! <= 5)
        ? CatalogFilterModal.getCategoryFilterTitle(_resolvedCatId)
        : (_categoryTitle != null && _categoryTitle!.isNotEmpty
            ? 'Filter $_categoryTitle'
            : CatalogFilterModal.getCategoryFilterTitle(_resolvedCatId));

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                (MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 8
                    : 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const Divider(),

              // Scrollable filters
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Brand Filter
                      if (_brands.isNotEmpty) ...[
                        const Text('Brand', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _brands.map((brand) {
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
                      ],

                      // 2. Dynamic Hardware Category Filters
                      if (_loading && _filters.isEmpty && (_resolvedCatId == null || _resolvedCatId! > 5)) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                                ),
                                SizedBox(height: 8),
                                Text('Loading specifications...', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                              ],
                            ),
                          ),
                        ),
                      ] else if (_filters.isNotEmpty) ...[
                        ..._filters.where((f) => f.filterKey.toLowerCase() != 'brand').map((filter) {
                final filterKey = filter.filterKey;
                final selectedVal = _dynamicFilters[filterKey];
                final unitStr = filter.unit != null && filter.unit!.trim().isNotEmpty
                    ? ' (${filter.unit!.trim()})'
                    : '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filter.displayName}$unitStr',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (selectedVal != null && selectedVal.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _dynamicFilters.remove(filterKey);
                                _textControllers[filterKey]?.clear();
                              });
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (filter.options.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filter.options.map((opt) {
                          final isSelected = selectedVal?.toLowerCase() == opt.value.toLowerCase();
                          return ChoiceChip(
                            label: Text(opt.value),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _dynamicFilters[filterKey] = opt.value;
                                } else {
                                  _dynamicFilters.remove(filterKey);
                                }
                              });
                            },
                          );
                        }).toList(),
                      )
                    else ...[
                      // Input field for free-text or numeric range filters
                      TextFormField(
                        controller: _getController(filterKey, selectedVal ?? ''),
                        decoration: InputDecoration(
                          hintText: filter.filterType == 'range'
                              ? 'e.g. 3072, 4352...'
                              : 'Enter ${filter.displayName}...',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          suffixIcon: selectedVal != null && selectedVal.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _dynamicFilters.remove(filterKey);
                                      _textControllers[filterKey]?.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        keyboardType: filter.filterType == 'range'
                            ? TextInputType.number
                            : TextInputType.text,
                        onChanged: (val) {
                          setState(() {
                            if (val.trim().isEmpty) {
                              _dynamicFilters.remove(filterKey);
                            } else {
                              _dynamicFilters[filterKey] = val.trim();
                            }
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              }),
            ] else ...[
              // Fallback for standard categories when offline
              ..._buildLegacyFallbackFilters(_resolvedCatId),
            ],

            // 3. Price Range
            const Text('Price Range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'LKR ${_minPrice.toInt()} - LKR ${_maxPrice.toInt()}',
              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
            ),
            RangeSlider(
              values: RangeValues(_minPrice, _maxPrice),
              min: 0,
              max: 500000,
              divisions: 50,
              activeColor: AppColors.primaryBlue,
              labels: RangeLabels('LKR ${_minPrice.toInt()}', 'LKR ${_maxPrice.toInt()}'),
              onChanged: (values) {
                setState(() {
                  _minPrice = values.start;
                  _maxPrice = values.end;
                });
              },
            ),

            // 4. In Stock Toggle
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('In Stock Only', style: TextStyle(fontSize: 14)),
              value: _inStockOnly,
              activeColor: AppColors.primaryBlue,
              onChanged: (val) => setState(() => _inStockOnly = val ?? false),
            ),

            // 5. Sort By
            const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),

    ElevatedButton(
      key: const Key('apply_filters_btn'),
      onPressed: () {
        Navigator.pop(context);
        widget.onApply(
          widget.initialFilter.copyWith(
            categoryId: _resolvedCatId,
            categoryName: _categoryTitle,
            brand: _selectedBrand,
            clearBrand: _selectedBrand == null,
            minPrice: _minPrice > 0 ? _minPrice : null,
            maxPrice: _maxPrice < 500000 ? _maxPrice : null,
            inStockOnly: _inStockOnly,
            sortBy: _sortBy,
            dynamicFilters: _dynamicFilters,
            socket: _dynamicFilters['socket'],
            clearSocket: !_dynamicFilters.containsKey('socket'),
            chipset: _dynamicFilters['chipset'],
            clearChipset: !_dynamicFilters.containsKey('chipset'),
            memoryType: _dynamicFilters['memory_type'] ?? _dynamicFilters['ddr_type'],
            clearMemoryType: !_dynamicFilters.containsKey('memory_type') &&
                !_dynamicFilters.containsKey('ddr_type'),
            speed: _dynamicFilters['speed'],
            clearSpeed: !_dynamicFilters.containsKey('speed'),
            capacity: _dynamicFilters['capacity'],
            clearCapacity: !_dynamicFilters.containsKey('capacity'),
            vram: _dynamicFilters['vram'],
            clearVram: !_dynamicFilters.containsKey('vram'),
            efficiencyRating: _dynamicFilters['efficiency'],
            clearEfficiencyRating: !_dynamicFilters.containsKey('efficiency'),
            formFactor: _dynamicFilters['form_factor'],
            clearFormFactor: !_dynamicFilters.containsKey('form_factor'),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  ],
),
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

  String _formatFilterKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
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
            // Dynamic Facet chips
            ...filter.dynamicFilters.entries.map((entry) {
              final formattedKey = _formatFilterKey(entry.key);
              return _chip(context, '$formattedKey: ${entry.value}', () {
                final newDynamic = Map<String, String>.from(filter.dynamicFilters)
                  ..remove(entry.key);
                onFilterChanged(filter.copyWith(
                  dynamicFilters: newDynamic,
                  clearSocket: entry.key == 'socket',
                  clearChipset: entry.key == 'chipset',
                  clearMemoryType: entry.key == 'memory_type' || entry.key == 'ddr_type',
                  clearSpeed: entry.key == 'speed',
                  clearCapacity: entry.key == 'capacity',
                  clearVram: entry.key == 'vram',
                  clearEfficiencyRating: entry.key == 'efficiency',
                  clearFormFactor: entry.key == 'form_factor',
                ));
              });
            }),
            // Legacy chips if not already covered in dynamicFilters
            if (filter.socket != null && !filter.dynamicFilters.containsKey('socket'))
              _chip(context, 'Socket: ${filter.socket!}', () {
                onFilterChanged(filter.copyWith(clearSocket: true));
              }),
            if (filter.chipset != null && !filter.dynamicFilters.containsKey('chipset'))
              _chip(context, 'Chipset: ${filter.chipset!}', () {
                onFilterChanged(filter.copyWith(clearChipset: true));
              }),
            if (filter.memoryType != null &&
                !filter.dynamicFilters.containsKey('memory_type') &&
                !filter.dynamicFilters.containsKey('ddr_type'))
              _chip(context, 'Type: ${filter.memoryType!}', () {
                onFilterChanged(filter.copyWith(clearMemoryType: true));
              }),
            if (filter.speed != null && !filter.dynamicFilters.containsKey('speed'))
              _chip(context, 'Speed: ${filter.speed!}', () {
                onFilterChanged(filter.copyWith(clearSpeed: true));
              }),
            if (filter.capacity != null && !filter.dynamicFilters.containsKey('capacity'))
              _chip(context, 'Capacity: ${filter.capacity!}', () {
                onFilterChanged(filter.copyWith(clearCapacity: true));
              }),
            if (filter.vram != null && !filter.dynamicFilters.containsKey('vram'))
              _chip(context, 'VRAM: ${filter.vram!}', () {
                onFilterChanged(filter.copyWith(clearVram: true));
              }),
            if (filter.efficiencyRating != null && !filter.dynamicFilters.containsKey('efficiency'))
              _chip(context, 'Eff: ${filter.efficiencyRating!}', () {
                onFilterChanged(filter.copyWith(clearEfficiencyRating: true));
              }),
            if (filter.minPrice != null || filter.maxPrice != null)
              _chip(
                context,
                'LKR ${(filter.minPrice ?? 0).toInt()}-LKR ${(filter.maxPrice ?? 500000).toInt()}',
                () {
                  onFilterChanged(filter.copyWith(
                    minPrice: null,
                    maxPrice: null,
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
                      categoryName: filter.categoryName,
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
