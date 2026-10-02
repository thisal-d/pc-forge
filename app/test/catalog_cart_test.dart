import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/core/app_routes.dart';
import 'package:pc_forge_mobile/core/widgets/pc_forge_app_bar.dart';
import 'package:pc_forge_mobile/features/cart/data/cart_service.dart';
import 'package:pc_forge_mobile/features/cart/presentation/screens/cart_screen.dart';
import 'package:pc_forge_mobile/features/catalog/data/catalog_repository.dart';
import 'package:pc_forge_mobile/features/catalog/data/models/product_model.dart';
import 'package:pc_forge_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:pc_forge_mobile/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:pc_forge_mobile/services/api_service.dart';

class MockCatalogApiService extends ApiService {
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    return [
      {'categoryId': 1, 'name': 'CPU'},
      {'categoryId': 2, 'name': 'GPU'},
      {'categoryId': 3, 'name': 'Motherboard'},
      {'categoryId': 4, 'name': 'RAM'},
      {'categoryId': 5, 'name': 'Power Supply'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? brand,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    bool inStockOnly = false,
    String sortBy = 'name_asc',
    String? socket,
    String? chipset,
    String? memoryType,
    String? speed,
    String? capacity,
    String? vram,
    String? efficiency,
  }) async {
    final all = <Map<String, dynamic>>[
      {
        'productId': 1,
        'name': 'GeForce RTX 4070 Ti 12GB',
        'brand': 'NVIDIA',
        'categoryId': 2,
        'price': 749.00,
        'stockQuantity': 5,
        'powerWattage': 240,
        'specifications': '{"vram":"12GB"}'
      },
      {
        'productId': 2,
        'name': 'Ryzen 9 7950X',
        'brand': 'AMD',
        'categoryId': 1,
        'price': 699.00,
        'stockQuantity': 10,
        'socket': 'AM5',
      },
      {
        'productId': 3,
        'name': 'TUF Gaming B650-Plus WiFi',
        'brand': 'ASUS',
        'categoryId': 3,
        'price': 229.00,
        'stockQuantity': 8,
        'socket': 'AM5',
        'specifications': '{"chipset":"B650"}'
      },
      {
        'productId': 4,
        'name': 'Vengeance LPX 16GB (2x8GB) DDR4-3200',
        'brand': 'Corsair',
        'categoryId': 4,
        'price': 49.00,
        'stockQuantity': 15,
        'memoryType': 'DDR4',
        'specifications': '{"speed":"3200 MHz"}'
      },
      {
        'productId': 5,
        'name': 'Ripjaws V 32GB (2x16GB) DDR4-3200',
        'brand': 'G.Skill',
        'categoryId': 4,
        'price': 79.00,
        'stockQuantity': 12,
        'memoryType': 'DDR4',
        'specifications': '{"speed":"3200 MHz"}'
      },
    ];

    return all.where((p) {
      if (categoryId != null && p['categoryId'] != categoryId) return false;
      if (brand != null && p['brand'] != brand) return false;
      if (searchQuery != null && !(p['name'] as String).toLowerCase().contains(searchQuery.toLowerCase())) return false;
      if (minPrice != null && (p['price'] as num) < minPrice) return false;
      if (maxPrice != null && (p['price'] as num) > maxPrice) return false;
      if (socket != null && p['socket'] != socket) return false;
      if (memoryType != null && p['memoryType'] != memoryType) return false;
      if (chipset != null && !(p['specifications']?.toString().contains(chipset) ?? false)) return false;
      if (speed != null && !(p['specifications']?.toString().contains(speed) ?? false)) return false;
      if (vram != null && !(p['specifications']?.toString().contains(vram) ?? false)) return false;
      return true;
    }).toList();
  }
}

void main() {
  const testGpu = ProductModel(
    productId: 1,
    name: 'GeForce RTX 4070 Ti 12GB',
    brand: 'NVIDIA',
    price: 749.00,
    stockQuantity: 10,
  );

  const testMobo = ProductModel(
    productId: 101,
    name: 'ASUS ROG Crosshair X670E Hero',
    brand: 'ASUS',
    price: 699.00,
    stockQuantity: 4,
  );

  group('CartService Unit Tests', () {
    setUp(() {
      CartService.instance.clear();
    });

    test('initial state is empty', () {
      expect(CartService.instance.isEmpty, true);
      expect(CartService.instance.totalCount, 0);
      expect(CartService.instance.subtotal, 0.0);
    });

    test('adds product and calculates subtotal and shipping', () {
      final error = CartService.instance.addItem(testGpu, quantity: 2);
      expect(error, isNull);
      expect(CartService.instance.totalCount, 2);
      expect(CartService.instance.subtotal, 749.00 * 2);
      expect(CartService.instance.shippingAmount, 15.0);
      expect(CartService.instance.totalAmount, (749.00 * 2) + 15.0);
    });

    test('prevents adding quantity beyond available stock', () {
      final error = CartService.instance.addItem(testMobo, quantity: 10);
      expect(error, isNotNull);
      expect(error, contains('Only 4 available in stock'));
      expect(CartService.instance.isEmpty, true);
    });

    test('updates quantity and removes item when quantity reaches 0', () {
      CartService.instance.addItem(testGpu, quantity: 2);

      CartService.instance.updateQuantity(testGpu.productId, 1);
      expect(CartService.instance.totalCount, 1);

      CartService.instance.updateQuantity(testGpu.productId, 0);
      expect(CartService.instance.isEmpty, true);
    });
  });

  group('CatalogRepository Filter Tests (Alex Story Match)', () {
    final repo = CatalogRepository(apiService: MockCatalogApiService());

    test('loads default categories', () async {
      final categories = await repo.getCategories();
      expect(categories.length, 5);
      expect(categories.any((c) => c.name == 'GPU'), true);
      expect(categories.any((c) => c.name == 'CPU'), true);
    });

    test('filters GPU category by NVIDIA and price range 500-800 to find RTX 4070 Ti', () async {
      final results = await repo.getProducts(
        filter: const CatalogFilter(
          categoryId: 2, // GPU
          brand: 'NVIDIA',
          minPrice: 500,
          maxPrice: 800,
        ),
      );

      expect(results.length, 1);
      expect(results.first.name, 'GeForce RTX 4070 Ti 12GB');
      expect(results.first.brand, 'NVIDIA');
      expect(results.first.price, 749.00);
      expect(results.first.powerWattage, 240);
    });

    test('filters by search keyword', () async {
      final results = await repo.getProducts(
        filter: const CatalogFilter(searchQuery: 'Ryzen'),
      );
      expect(results.isNotEmpty, true);
      expect(results.any((p) => p.name.contains('Ryzen 9 7950X')), true);
    });

    test('Nanotek style: filters Motherboard by ASUS and B650 chipset', () async {
      final results = await repo.getProducts(
        filter: const CatalogFilter(
          categoryId: 3, // Motherboard
          brand: 'ASUS',
          chipset: 'B650',
          socket: 'AM5',
        ),
      );

      expect(results.length, 1);
      expect(results.first.name, 'TUF Gaming B650-Plus WiFi');
      expect(results.first.chipset, 'B650');
      expect(results.first.socket, 'AM5');
    });

    test('Nanotek style: filters RAM by DDR4 and 3200 MHz speed', () async {
      final results = await repo.getProducts(
        filter: const CatalogFilter(
          categoryId: 4, // RAM
          memoryType: 'DDR4',
          speed: '3200 MHz',
        ),
      );

      expect(results.length, 2);
      expect(results.every((r) => r.memoryType == 'DDR4' && r.speed == '3200 MHz'), true);
    });

    test('Nanotek style: filters GPU by 12GB VRAM', () async {
      final results = await repo.getProducts(
        filter: const CatalogFilter(
          categoryId: 2, // GPU
          vram: '12GB',
        ),
      );

      expect(results.length, 1);
      expect(results.first.name, 'GeForce RTX 4070 Ti 12GB');
      expect(results.first.vram, '12GB');
    });
  });

  group('Catalog & Cart Widget Tests', () {
    final mockRepo = CatalogRepository(apiService: MockCatalogApiService());

    setUp(() {
      CartService.instance.clear();
    });

    testWidgets('renders catalog and adds item to cart, updating badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.catalog: (context) => CatalogScreen(repository: mockRepo),
            AppRoutes.cart: (context) => const CartScreen(),
            AppRoutes.productDetail: (context) => const ProductDetailScreen(),
          },
          home: CatalogScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      // Check app bar and search
      expect(find.byType(PCForgeAppBar), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Tap GPU Category Chip
      await tester.tap(find.byKey(const Key('category_gpu_chip')));
      await tester.pumpAndSettle();

      // Add RTX 4070 Ti (Product #1) to cart
      final addBtn = find.byKey(const Key('add_to_cart_btn_1'));
      await tester.scrollUntilVisible(addBtn, 150, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Badge in AppBar shows '1'
      expect(find.text('1'), findsWidgets);

      // Open Cart via SnackBar action
      await tester.tap(find.text('View Cart'));
      await tester.pumpAndSettle();

      // Cart screen displays item and checkout button
      expect(find.text('Shopping Cart'), findsOneWidget);
      expect(find.text('GeForce RTX 4070 Ti 12GB'), findsOneWidget);
      expect(find.byKey(const Key('proceed_to_checkout_btn')), findsOneWidget);
    });
  });
}
