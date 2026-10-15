import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/image_utils.dart';

/// Rock-solid network image widget with URL normalization, anti-bot mobile headers,
/// immediate loading placeholder (no blank frames), and rich branded hardware fallbacks.
class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final String? categoryName;
  final String? productName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double fallbackIconSize;
  final bool showCategoryTag;
  final Widget? customFallback;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.categoryName,
    this.productName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIconSize = 36,
    this.showCategoryTag = true,
    this.customFallback,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ImageUtils.resolveImageUrl(imageUrl);

    Widget imageWidget;
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      imageWidget = _buildFallback();
    } else {
      imageWidget = Image.network(
        resolvedUrl,
        width: width,
        height: height,
        fit: fit,
        headers: ImageUtils.getHeadersForUrl(resolvedUrl),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback();
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: SizedBox(
          width: (fallbackIconSize * 0.6).clamp(16.0, 24.0),
          height: (fallbackIconSize * 0.6).clamp(16.0, 24.0),
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    if (customFallback != null) return customFallback!;

    final icon = ImageUtils.getCategoryIcon(categoryName);
    final catName = (categoryName ?? '').trim();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.imageContainerBg,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: fallbackIconSize,
                color: AppColors.primaryBlue.withValues(alpha: 0.85),
              ),
            ),
            if (showCategoryTag && catName.isNotEmpty && (height == null || height! >= 85)) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.7),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  catName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
