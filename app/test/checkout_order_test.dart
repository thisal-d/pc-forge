import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/core/app_routes.dart';
import 'package:pc_forge_mobile/features/cart/data/cart_service.dart';
import 'package:pc_forge_mobile/features/catalog/data/models/product_model.dart';
import 'package:pc_forge_mobile/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:pc_forge_mobile/features/orders/data/order_service.dart';
import 'package:pc_forge_mobile/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:pc_forge_mobile/features/orders/presentation/screens/order_history_screen.dart';
import 'package:pc_forge_mobile/services/api_service.dart';

class MockOrderApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> createOrder({
    required String shippingAddress,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? token,
  }) async {
    return {
      'orderId': 1001,
      'userId': 42,
      'totalAmount': 764.00,
      'status': 'Paid',
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'createdAt': DateTime.now().toIso8601String(),
      'items': [
        {
          'orderItemId': 1,
          'orderId': 1001,
          'productId': 1,
          'productName': 'GeForce RTX 4070 Ti 12GB',
          'brand': 'NVIDIA',
          'quantity': 1,
          'unitPrice': 749.00,
        }
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOrders({String? token}) async {
    return [
      {
        'orderId': 1001,
        'userId': 42,
        'totalAmount': 764.00,
        'status': 'Paid',
        'shippingAddress': '45 Flower Road, Colombo',
        'paymentMethod': 'Credit / Debit Card',
        'createdAt': DateTime.now().toIso8601String(),
        'itemCount': 1,
        'items': [
          {
            'orderItemId': 1,
            'orderId': 1001,
            'productId': 1,
            'productName': 'GeForce RTX 4070 Ti 12GB',
            'brand': 'NVIDIA',
            'quantity': 1,
            'unitPrice': 749.00,
          }
        ],
      }
    ];
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

  group('OrderService Tests', () {
    setUp(() {
      CartService.instance.clear();
      OrderService.instance.setApiServiceForTesting(MockOrderApiService());
    });

    test('places order from cart items, assigns ID, sets status Paid, and clears cart', () async {
      CartService.instance.addItem(testGpu, quantity: 1);
      expect(CartService.instance.totalCount, 1);

      final order = await OrderService.instance.placeOrder(
        userId: 42,
        shippingAddress: '45 Flower Road, Colombo',
        paymentMethod: 'Credit / Debit Card',
        cartItems: CartService.instance.items,
        totalAmount: CartService.instance.totalAmount,
      );

      expect(order.orderId, greaterThanOrEqualTo(1001));
      expect(order.status, 'Paid');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'GeForce RTX 4070 Ti 12GB');
      expect(order.totalAmount, 764.00);

      // Cart is cleared after order is confirmed
      expect(CartService.instance.isEmpty, true);

      // Appears in OrderService history
      expect(OrderService.instance.hasOrders, true);
      expect(OrderService.instance.orders.first.orderId, order.orderId);
    });
  });

  group('Checkout & Order Confirmation Widget Tests', () {
    setUp(() {
      CartService.instance.clear();
      OrderService.instance.setApiServiceForTesting(MockOrderApiService());
    });

    testWidgets('completes full checkout flow from cart to order confirmation', (WidgetTester tester) async {
      // 1. Setup cart with RTX 4070 Ti
      CartService.instance.addItem(testGpu, quantity: 1);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.checkout: (context) => const CheckoutScreen(),
            AppRoutes.orderDetail: (context) => const OrderDetailScreen(),
            AppRoutes.orders: (context) => const OrderHistoryScreen(),
          },
          home: const CheckoutScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check fields are present
      expect(find.text('Checkout & Order'), findsOneWidget);

      // Advance through wizard steps:
      // Step 0 -> Step 1 (Shipping to Payment)
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (Payment to Review)
      await tester.tap(find.text('Review Order'));
      await tester.pumpAndSettle();

      // Step 2: Place Order button is displayed in the bottom action bar
      final placeOrderBtn = find.byKey(const Key('place_order_btn'));
      expect(placeOrderBtn, findsOneWidget);

      // Tap Place Order button
      await tester.tap(placeOrderBtn);
      await tester.pumpAndSettle();

      // Verify Order Confirmation screen
      expect(find.text('Order Placed Successfully!'), findsOneWidget);
      expect(find.text('GeForce RTX 4070 Ti 12GB'), findsOneWidget);
      expect(find.byKey(const Key('continue_shopping_btn')), findsOneWidget);
    });

    testWidgets('orders >= Rs. 100,000 require In-Store Pickup and disable Cash on Delivery', (WidgetTester tester) async {
      // Setup cart with high-value item >= 100,000
      const expensiveItem = ProductModel(
        productId: 99,
        name: 'Threadripper PRO 5995WX',
        brand: 'AMD',
        price: 350000.00,
        stockQuantity: 2,
      );
      CartService.instance.addItem(expensiveItem, quantity: 1);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.checkout: (context) => const CheckoutScreen(),
            AppRoutes.orderDetail: (context) => const OrderDetailScreen(),
            AppRoutes.orders: (context) => const OrderHistoryScreen(),
          },
          home: const CheckoutScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 0: Notice for Showroom Collection is present
      expect(find.text('In-Store Showroom Collection Required'), findsOneWidget);

      // Advance to Step 1 (Payment)
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // Step 1: Shows high value order protection banner
      expect(find.text('High-Value Order Protection (≥ LKR 100,000)'), findsOneWidget);
      expect(find.text('Limit Exceeded'), findsOneWidget);

      // Advance to Step 2 (Review)
      await tester.tap(find.text('Review Order'));
      await tester.pumpAndSettle();

      // Step 2: Confirmation button reflects in-store pickup
      expect(find.textContaining('Reserve for Store Pickup'), findsOneWidget);
    });
  });
}
