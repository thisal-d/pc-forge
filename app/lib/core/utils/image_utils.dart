import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Centralized utility for resolving image URLs, supplying HTTP headers,
/// and providing contextual hardware category icons.
class ImageUtils {
  /// Standard mobile browser headers to bypass CDN / Cloudflare anti-bot blocks on mobile.
  static const Map<String, String> standardHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  };

  /// Context-aware headers based on destination host (e.g. Unsplash, Cloudinary).
  static Map<String, String> getHeadersForUrl(String? url) {
    if (url == null || url.isEmpty) return standardHeaders;
    final headers = Map<String, String>.from(standardHeaders);
    if (url.contains('unsplash.com')) {
      headers['Referer'] = 'https://unsplash.com/';
    }
    return headers;
  }

  /// Normalizes and resolves relative image URLs, data URIs, and local dev hostnames.
  static String? resolveImageUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    // Protocol-relative URLs (e.g. //images.unsplash.com/...)
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    // Data URIs or full external URLs
    if (trimmed.startsWith('data:image/')) {
      return trimmed;
    }

    // Absolute HTTP / HTTPS URLs
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final defaultBase = ApiService.defaultBaseUrl;
      try {
        final baseUri = Uri.parse(defaultBase);
        final imgUri = Uri.parse(trimmed);

        // If image URL is bound to localhost / 127.0.0.1 / 10.0.2.2 and defaultBase has a specific host,
        // rewrite the host to ensure mobile device connectivity.
        final isLocalHost = imgUri.host == 'localhost' ||
            imgUri.host == '127.0.0.1' ||
            imgUri.host == '10.0.2.2';

        final baseIsRemote = baseUri.host != 'localhost' &&
            baseUri.host != '127.0.0.1' &&
            baseUri.host != '10.0.2.2';

        if (isLocalHost && baseIsRemote) {
          return imgUri
              .replace(
                scheme: baseUri.scheme,
                host: baseUri.host,
                port: baseUri.hasPort ? baseUri.port : null,
              )
              .toString();
        }
      } catch (_) {}

      return trimmed;
    }

    // Relative URLs (e.g. /uploads/products/image.png or uploads/...)
    try {
      final baseUri = Uri.parse(ApiService.defaultBaseUrl);
      final origin =
          '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      if (trimmed.startsWith('/')) {
        return '$origin$trimmed';
      }
      return '$origin/$trimmed';
    } catch (_) {
      return trimmed;
    }
  }

  /// Returns an appropriate hardware component icon for a given category name.
  static IconData getCategoryIcon(String? categoryName) {
    switch ((categoryName ?? '').trim().toLowerCase()) {
      case 'gpu':
      case 'graphics card':
      case 'video card':
        return Icons.videogame_asset_outlined;
      case 'cpu':
      case 'processor':
        return Icons.memory_rounded;
      case 'motherboard':
      case 'mainboard':
        return Icons.developer_board_rounded;
      case 'ram':
      case 'memory':
        return Icons.straighten_rounded;
      case 'psu':
      case 'power supply':
        return Icons.power_rounded;
      case 'storage':
      case 'ssd':
      case 'hdd':
        return Icons.storage_rounded;
      case 'cooling':
      case 'cooler':
        return Icons.ac_unit_rounded;
      case 'case':
      case 'chassis':
        return Icons.computer_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}
