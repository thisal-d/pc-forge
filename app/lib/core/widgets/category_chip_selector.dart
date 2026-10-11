import 'package:flutter/material.dart';
import '../../features/catalog/data/models/category_model.dart';
import '../theme/app_colors.dart';

class CategoryChipSelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;

  const CategoryChipSelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'cpu':
        return Icons.memory_rounded;
      case 'gpu':
        return Icons.videogame_asset_outlined;
      case 'motherboard':
        return Icons.developer_board_rounded;
      case 'ram':
        return Icons.straighten_rounded;
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // "All" Pill
          _buildChip(
            key: const Key('category_all_chip'),
            label: 'All',
            icon: _getCategoryIcon('all'),
            isSelected: selectedCategoryId == null,
            onTap: () => onCategorySelected(null),
          ),
          const SizedBox(width: 8),

          // Dynamic Category Pills
          ...categories.map((cat) {
            final isSelected = selectedCategoryId == cat.categoryId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                key: Key('category_${cat.name.toLowerCase()}_chip'),
                label: cat.name,
                icon: _getCategoryIcon(cat.name),
                isSelected: isSelected,
                onTap: () => onCategorySelected(cat.categoryId),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip({
    required Key key,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : AppColors.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.primaryDark,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
