import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/image_utils.dart';

/// Rock-solid network image widget with URL normalization, gapless playback,
/// automatic connection timeout handling, and rich branded hardware category fallbacks.
class AppNetworkImage extends StatefulWidget {
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
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  Timer? _timeoutTimer;
  bool _timedOut = false;
  bool _isLoaded = false;
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _initImage();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _timeoutTimer?.cancel();
      _timedOut = false;
      _isLoaded = false;
      _initImage();
    }
  }

  void _initImage() {
    _resolvedUrl = ImageUtils.resolveImageUrl(widget.imageUrl);
    if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      // 7-second safety timeout so stalled connections gracefully display branded fallback
      _timeoutTimer = Timer(const Duration(seconds: 7), () {
        if (mounted && !_isLoaded) {
          setState(() {
            _timedOut = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (_resolvedUrl == null || _resolvedUrl!.isEmpty || _timedOut) {
      imageWidget = _buildFallback();
    } else {
      imageWidget = Image.network(
        _resolvedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        headers: ImageUtils.getHeadersForUrl(_resolvedUrl),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            if (!_isLoaded) {
              _isLoaded = true;
              _timeoutTimer?.cancel();
            }
            return child;
          }
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          _timeoutTimer?.cancel();
          return _buildFallback();
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: SizedBox(
          width: (widget.fallbackIconSize * 0.6).clamp(16.0, 24.0),
          height: (widget.fallbackIconSize * 0.6).clamp(16.0, 24.0),
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    if (widget.customFallback != null) return widget.customFallback!;

    final icon = ImageUtils.getCategoryIcon(widget.categoryName);
    final catName = (widget.categoryName ?? '').trim();

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.imageContainerBg,
        borderRadius: widget.borderRadius,
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
                size: widget.fallbackIconSize,
                color: AppColors.primaryBlue.withValues(alpha: 0.85),
              ),
            ),
            if (widget.showCategoryTag && catName.isNotEmpty && (widget.height == null || widget.height! >= 85)) ...[
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
