import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/core/utils/image_utils.dart';
import 'package:pc_forge_mobile/core/widgets/app_network_image.dart';
import 'package:pc_forge_mobile/features/catalog/data/models/product_model.dart';

void main() {
  group('ImageUtils URL Resolution & Category Mapping Tests', () {
    test('resolveImageUrl correctly handles null, empty, and whitespace', () {
      expect(ImageUtils.resolveImageUrl(null), isNull);
      expect(ImageUtils.resolveImageUrl(''), isNull);
      expect(ImageUtils.resolveImageUrl('   '), isNull);
    });

    test('resolveImageUrl normalizes protocol-relative URLs', () {
      const url = '//images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea';
      expect(ImageUtils.resolveImageUrl(url),
          'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea');
    });

    test('resolveImageUrl keeps absolute HTTPS URLs intact', () {
      const url = 'https://images.unsplash.com/photo-test?w=600';
      expect(ImageUtils.resolveImageUrl(url), url);
    });

    test('resolveImageUrl prepends API host origin to relative paths', () {
      const relative1 = '/uploads/products/rtx4070.png';
      final resolved = ImageUtils.resolveImageUrl(relative1);
      expect(resolved, isNotNull);
      expect(resolved, contains('/uploads/products/rtx4070.png'));
      expect(resolved!.startsWith('http'), isTrue);

      const relative2 = 'uploads/products/ryzen5600.png';
      final resolved2 = ImageUtils.resolveImageUrl(relative2);
      expect(resolved2, isNotNull);
      expect(resolved2, contains('uploads/products/ryzen5600.png'));
    });

    test('getHeadersForUrl returns browser headers and Unsplash Referer', () {
      final headers = ImageUtils.getHeadersForUrl('https://images.unsplash.com/photo-123');
      expect(headers['User-Agent'], contains('Mozilla/5.0'));
      expect(headers['Referer'], 'https://unsplash.com/');
    });

    test('getCategoryIcon returns appropriate icon for each hardware component', () {
      expect(ImageUtils.getCategoryIcon('CPU'), Icons.memory_rounded);
      expect(ImageUtils.getCategoryIcon('Processor'), Icons.memory_rounded);
      expect(ImageUtils.getCategoryIcon('GPU'), Icons.videogame_asset_outlined);
      expect(ImageUtils.getCategoryIcon('Graphics Card'), Icons.videogame_asset_outlined);
      expect(ImageUtils.getCategoryIcon('Motherboard'), Icons.developer_board_rounded);
      expect(ImageUtils.getCategoryIcon('RAM'), Icons.straighten_rounded);
      expect(ImageUtils.getCategoryIcon('PSU'), Icons.power_rounded);
      expect(ImageUtils.getCategoryIcon('Storage'), Icons.storage_rounded);
      expect(ImageUtils.getCategoryIcon('Cooling'), Icons.ac_unit_rounded);
      expect(ImageUtils.getCategoryIcon('Case'), Icons.computer_rounded);
      expect(ImageUtils.getCategoryIcon('Unknown'), Icons.devices_rounded);
      expect(ImageUtils.getCategoryIcon(null), Icons.devices_rounded);
    });
  });

  group('ProductModel Image Resolution Tests', () {
    test('ProductModel.fromJson parses and resolves image URLs automatically', () {
      final json = {
        'productId': 27,
        'name': 'AMD Ryzen 5 5600',
        'categoryName': 'CPU',
        'price': 38000.0,
        'imageUrl': '//images.unsplash.com/photo-1591799264318',
        'images': [
          'https://images.unsplash.com/photo-1',
          '/uploads/products/extra.jpg',
        ],
      };

      final product = ProductModel.fromJson(json);
      expect(product.imageUrl, 'https://images.unsplash.com/photo-1591799264318');
      expect(product.allImages.length, 3);
      expect(product.allImages[0], 'https://images.unsplash.com/photo-1591799264318');
      expect(product.allImages[1], 'https://images.unsplash.com/photo-1');
      expect(product.allImages[2], contains('/uploads/products/extra.jpg'));
    });
  });

  group('AppNetworkImage Widget Tests', () {
    testWidgets('Renders contextual hardware fallback when imageUrl is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: null,
              categoryName: 'CPU',
              width: 104,
              height: 108,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.memory_rounded), findsOneWidget);
      expect(find.text('CPU'), findsOneWidget);
    });

    testWidgets('Renders contextual hardware fallback when imageUrl is empty string', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: '   ',
              categoryName: 'GPU',
              width: 104,
              height: 108,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.videogame_asset_outlined), findsOneWidget);
      expect(find.text('GPU'), findsOneWidget);
    });

    testWidgets('Renders customFallback if provided and imageUrl is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: null,
              customFallback: Text('Custom Fallback Graphic'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Fallback Graphic'), findsOneWidget);
    });
  });
}
