import 'package:flutter/foundation.dart';
import '../../cart/data/cart_service.dart';
import '../../cart/data/models/cart_item_model.dart';
import '../../../services/api_service.dart';
import 'models/order_model.dart';

class OrderService extends ChangeNotifier {
  static final OrderService instance = OrderService._internal();

  OrderService._internal();

  ApiService _apiService = ApiService();
  final List<OrderModel> _orders = [];

  @visibleForTesting
  void setApiServiceForTesting(ApiService api) {
    _apiService = api;
  }

  List<OrderModel> get orders => List.unmodifiable(_orders);

  bool get hasOrders => _orders.isNotEmpty;

  /// Loads orders for the current user from backend PostgreSQL
  Future<List<OrderModel>> loadOrders({String? token}) async {
    try {
      final remoteList = await _apiService.fetchOrders(token: token);
      _orders.clear();
      for (final item in remoteList) {
        _orders.add(OrderModel.fromJson(item));
      }
      notifyListeners();
    } catch (_) {
      // Network error — keep existing in-memory orders
    }
    return _orders;
  }

  /// Places a new order from cart items, registers with backend PostgreSQL, and clears the cart.
  Future<OrderModel> placeOrder({
    required int userId,
    required String shippingAddress,
    required String paymentMethod,
    required List<CartItemModel> cartItems,
    required double totalAmount,
    String? token,
  }) async {
    final itemsPayload = cartItems.map((cartItem) => {
      'productId': cartItem.productId,
      'quantity': cartItem.quantity,
    }).toList();

    // Direct call to live API - throws ApiException if backend rejects
    final apiRes = await _apiService.createOrder(
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      items: itemsPayload,
      token: token,
    );

    final order = OrderModel.fromJson(apiRes);

    _orders.insert(0, order);

    // Clear active cart ONLY when server confirms order creation
    CartService.instance.clear();

    notifyListeners();
    return order;
  }

  OrderModel? getOrderById(int orderId) {
    try {
      return _orders.firstWhere((o) => o.orderId == orderId);
    } catch (_) {
      return null;
    }
  }
}
