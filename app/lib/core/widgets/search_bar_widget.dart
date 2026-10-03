import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterPressed;
  final VoidCallback? onScannerPressed;
  final bool hasActiveFilters;
  final String hintText;

  const SearchBarWidget({
    super.key,
    required this.controller,
    this.onChanged,
    this.onFilterPressed,
    this.onScannerPressed,
    this.hasActiveFilters = false,
    this.hintText = 'Search parts (e.g. 3060, Ryzen, SSD...)',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Expanded Search Input
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: AppColors.softShadow,
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 14, color: AppColors.primaryDark),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.secondaryText),
                          onPressed: () {
                            controller.clear();
                            if (onChanged != null) onChanged!('');
                          },
                        )
                      : (onScannerPressed != null
                          ? IconButton(
                              key: const Key('catalog_scanner_btn'),
                              icon: const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.secondaryText),
                              tooltip: 'Scan Barcode',
                              onPressed: onScannerPressed,
                            )
                          : null),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Square Filter Button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: hasActiveFilters ? AppColors.primaryBlue : AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: hasActiveFilters ? AppColors.primaryBlue : AppColors.border,
                width: 1,
              ),
              boxShadow: AppColors.softShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('filter_btn'),
                borderRadius: BorderRadius.circular(13),
                onTap: onFilterPressed,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: hasActiveFilters ? Colors.white : AppColors.primaryDark,
                        size: 22,
                      ),
                      if (hasActiveFilters)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.alertRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
