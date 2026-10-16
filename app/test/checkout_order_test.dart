import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/core/app_routes.dart';
import 'package:pc_forge_mobile/core/auth_session.dart';
import 'package:pc_forge_mobile/features/auth/data/models/user_model.dart';
import 'package:pc_forge_mobile/features/cart/data/cart_service.dart';
import 'package:pc_forge_mobile/features/catalog/data/models/product_model.dart';
import 'package:pc_forge_mobile/features/checkout/data/user_contact_service.dart';
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
    String? couponCode,
    double? discountAmount,
    String? token,
  }) async {
    return {
      'orderId': 1001,
      'userId': 42,
      'totalAmount': 749.00,
      'status': 'Order placed',
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
        'totalAmount': 749.00,
        'status': 'Order placed',
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

  @override
  Future<Map<String, dynamic>> cancelOrder(int orderId, {String? token}) async {
    return {
      'orderId': orderId,
      'userId': 42,
      'totalAmount': 749.00,
      'status': 'Cancelled',
      'shippingAddress': '45 Flower Road, Colombo',
      'paymentMethod': 'Cash on Delivery',
      'createdAt': DateTime.now().toIso8601String(),
      'items': [
        {
          'orderItemId': 1,
          'orderId': orderId,
          'productId': 1,
          'productName': 'GeForce RTX 4070 Ti 12GB',
          'brand': 'NVIDIA',
          'quantity': 1,
          'unitPrice': 749.00,
        }
      ],
    };
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
      UserContactService.instance.clearAll();
      OrderService.instance.setApiServiceForTesting(MockOrderApiService());
    });

    test('places order from cart items, assigns ID, sets status Order placed, and clears cart', () async {
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
      expect(order.status, 'Order placed');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'GeForce RTX 4070 Ti 12GB');
      expect(order.totalAmount, 749.00);

      // Cart is cleared after order is confirmed
      expect(CartService.instance.isEmpty, true);

      // Appears in OrderService history
      expect(OrderService.instance.hasOrders, true);
      expect(OrderService.instance.orders.first.orderId, order.orderId);
    });

    test('cancels active order and updates status to Cancelled', () async {
      CartService.instance.addItem(testGpu, quantity: 1);
      final order = await OrderService.instance.placeOrder(
        userId: 42,
        shippingAddress: '45 Flower Road, Colombo',
        paymentMethod: 'Cash on Delivery',
        cartItems: CartService.instance.items,
        totalAmount: CartService.instance.totalAmount,
      );
      expect(order.status, 'Order placed');

      final cancelled = await OrderService.instance.cancelOrder(order.orderId);
      expect(cancelled.status, 'Cancelled');
      expect(OrderService.instance.orders.first.status, 'Cancelled');
    });
  });

  group('Checkout & Order Confirmation Widget Tests', () {
    setUp(() {
      CartService.instance.clear();
      UserContactService.instance.clearAll();
      AuthSession.instance.clearSession();
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

      // Fill in genuine contact details
      await tester.enterText(find.byKey(const Key('checkout_name_field')), 'John Doe');
      await tester.enterText(find.byKey(const Key('checkout_phone_field')), '0771234567');
      await tester.enterText(find.byKey(const Key('checkout_address_field')), 'No. 45, Flower Road');
      await tester.enterText(find.byKey(const Key('checkout_city_field')), 'Colombo 07');
      await tester.pumpAndSettle();

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

    testWidgets('orders > Rs. 100,000 require In-Store Pickup and disable Cash on Delivery', (WidgetTester tester) async {
      // Setup cart with high-value item > 100,000
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

      // Enter contact details
      await tester.enterText(find.byKey(const Key('checkout_name_field')), 'Jane Doe');
      await tester.enterText(find.byKey(const Key('checkout_phone_field')), '0779876543');
      await tester.enterText(find.byKey(const Key('checkout_address_field')), 'No. 10, Kandy Road');
      await tester.enterText(find.byKey(const Key('checkout_city_field')), 'Colombo');
      await tester.pumpAndSettle();

      // Advance to Step 1 (Payment)
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // Step 1: Shows high value order protection banner
      expect(find.text('High-Value Order Protection (> LKR 100,000)'), findsOneWidget);
      expect(find.text('Limit Exceeded'), findsOneWidget);

      // Advance to Step 2 (Review)
      await tester.tap(find.text('Review Order'));
      await tester.pumpAndSettle();

      // Step 2: Confirmation button reflects in-store pickup
      expect(find.textContaining('Reserve for Store Pickup'), findsOneWidget);
    });

    testWidgets('new user without saved contact has empty fields and validates on empty submit', (WidgetTester tester) async {
      // Authenticate a new user with NO saved address or phone
      const newUser = UserModel(userId: 101, email: 'newbie@pcforge.com', firstName: 'New', lastName: 'Customer');
      AuthSession.instance.setSession(user: newUser, token: 'mock_jwt_newbie');

      CartService.instance.addItem(testGpu, quantity: 1);

      await tester.pumpWidget(
        const MaterialApp(
          home: CheckoutScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Recipient name prefilled from genuine user profile
      expect(find.widgetWithText(TextFormField, 'New Customer'), findsOneWidget);

      // Phone, Address, City are strictly EMPTY, not prefilled with fake data!
      final phoneField = tester.widget<TextFormField>(find.byKey(const Key('checkout_phone_field')));
      expect(phoneField.controller?.text, isEmpty);

      final addressField = tester.widget<TextFormField>(find.byKey(const Key('checkout_address_field')));
      expect(addressField.controller?.text, isEmpty);

      final cityField = tester.widget<TextFormField>(find.byKey(const Key('checkout_city_field')));
      expect(cityField.controller?.text, isEmpty);

      // Attempting to advance without entering contact details displays validation errors
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter phone number'), findsOneWidget);
      expect(find.text('Please enter delivery address'), findsOneWidget);
      expect(find.text('Please enter city'), findsOneWidget);
    });

    testWidgets('saved contact details persist for user and are never leaked to another user', (WidgetTester tester) async {
      // User 201 has saved shipping details
      const userA = UserModel(userId: 201, email: 'usera@pcforge.com', firstName: 'Alice', lastName: 'Smith');
      UserContactService.instance.saveContact(
        201,
        const UserShippingContact(
          recipientName: 'Alice Smith',
          phoneNumber: '0712345678',
          address: 'No. 88, Galle Road',
          city: 'Colombo 03',
        ),
      );

      // 1. User A logs in and opens checkout
      AuthSession.instance.setSession(user: userA, token: 'mock_token_a');
      CartService.instance.addItem(testGpu, quantity: 1);

      await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
      await tester.pumpAndSettle();

      // User A sees their legitimate saved details
      expect(find.widgetWithText(TextFormField, 'Alice Smith'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '0712345678'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'No. 88, Galle Road'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Colombo 03'), findsOneWidget);

      // 2. User B logs in (userId: 202)
      const userB = UserModel(userId: 202, email: 'userb@pcforge.com', firstName: 'Bob', lastName: 'Jones');
      AuthSession.instance.setSession(user: userB, token: 'mock_token_b');

      await tester.pumpWidget(MaterialApp(home: CheckoutScreen(key: UniqueKey())));
      await tester.pumpAndSettle();

      // User B sees their own name, but empty phone and address (User A's details are NEVER leaked!)
      expect(find.widgetWithText(TextFormField, 'Bob Jones'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '0712345678'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'No. 88, Galle Road'), findsNothing);
    });
  });
}
