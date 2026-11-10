import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/services/api_service.dart';
import 'package:pc_forge_mobile/features/catalog/data/models/product_model.dart';
import 'package:pc_forge_mobile/features/catalog/data/models/category_model.dart';

void main() {
  group('ApiService & Dynamic Model Mapping Tests', () {
    test('ProductModel parses JSON from live backend with nested specifications', () {
      final backendJson = {
        'productId': 7,
        'categoryId': 3,
        'categoryName': 'Motherboard',
        'name': 'MSI MAG B650 Tomahawk WiFi',
        'brand': 'MSI',
        'model': 'B650 Tomahawk',
        'price': 219.0,
        'stockQuantity': 8,
        'imageUrl': null,
        'description': null,
        'specifications': {
          'socket': 'AM5',
          'chipset': 'B650',
          'formFactor': 'ATX',
          'memorySlots': 4,
        },
        'socket': 'AM5',
        'memoryType': 'DDR5',
        'powerWattage': null,
        'formFactor': 'ATX',
      };

      final product = ProductModel.fromJson(backendJson);
      expect(product.productId, 7);
      expect(product.name, 'MSI MAG B650 Tomahawk WiFi');
      expect(product.chipset, 'B650');
      expect(product.socket, 'AM5');
      expect(product.memoryType, 'DDR5');
      expect(product.isInStock, isTrue);
    });

    test('CategoryModel parses backend CategoryDto JSON correctly', () {
      final categoryJson = {
        'categoryId': 4,
        'name': 'RAM',
        'description': 'Memory Modules',
      };

      final category = CategoryModel.fromJson(categoryJson);
      expect(category.categoryId, 4);
      expect(category.name, 'RAM');
      expect(category.description, 'Memory Modules');
    });

    test('ApiService defaultBaseUrl resolves properly for platform', () {
      final service = ApiService();
      expect(service.baseUrl, contains(':5000/api'));
    });
  });
}
