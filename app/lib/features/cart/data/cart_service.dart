import 'package:flutter/foundation.dart';
import '../../catalog/data/models/product_model.dart';
import 'models/cart_item_model.dart';

/// In-memory reactive Cart State Manager
class CartService extends ChangeNotifier {
  static final CartService instance = CartService._internal();

  CartService._internal();

  final List<CartItemModel> _items = [];
  int _nextItemId = 1;

  List<CartItemModel> get items => List.unmodifiable(_items);

  int get totalCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(
        0.0,
        (sum, item) => sum + ((item.product?.price ?? 0.0) * item.quantity),
      );

  double get shippingAmount => subtotal > 0 ? 15.0 : 0.0;

  double get totalAmount => subtotal + shippingAmount;

  bool get isEmpty => _items.isEmpty;

  bool isInCart(int productId) =>
      _items.any((item) => item.productId == productId);

  int getProductQuantity(int productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    return index != -1 ? _items[index].quantity : 0;
  }

  /// Adds a product to cart. Verifies local stock availability.
  /// Returns null on success, or an error message string if stock check fails.
  String? addItem(ProductModel product, {int quantity = 1}) {
    if (product.stockQuantity <= 0) {
      return '${product.name} is currently out of stock.';
    }

    final existingIndex =
        _items.indexWhere((item) => item.productId == product.productId);

    if (existingIndex != -1) {
      final currentQty = _items[existingIndex].quantity;
      final newQty = currentQty + quantity;
      if (newQty > product.stockQuantity) {
        return 'Cannot add more. Only ${product.stockQuantity} available in stock.';
      }
      _items[existingIndex] = CartItemModel(
        cartItemId: _items[existingIndex].cartItemId,
        cartId: 1,
        productId: product.productId,
        quantity: newQty,
        product: product,
      );
    } else {
      if (quantity > product.stockQuantity) {
        return 'Cannot add. Only ${product.stockQuantity} available in stock.';
      }
      _items.add(
        CartItemModel(
          cartItemId: _nextItemId++,
          cartId: 1,
          productId: product.productId,
          quantity: quantity,
          product: product,
        ),
      );
    }

    notifyListeners();
    return null;
  }

  /// Increases or decreases item quantity.
  String? updateQuantity(int productId, int newQuantity) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index == -1) return 'Item not found in cart.';

    final product = _items[index].product;
    if (newQuantity <= 0) {
      _items.removeAt(index);
      notifyListeners();
      return null;
    }

    if (product != null && newQuantity > product.stockQuantity) {
      return 'Cannot exceed available stock (${product.stockQuantity}).';
    }

    _items[index] = CartItemModel(
      cartItemId: _items[index].cartItemId,
      cartId: 1,
      productId: productId,
      quantity: newQuantity,
      product: product,
    );

    notifyListeners();
    return null;
  }

  /// Removes an item from the cart
  void removeItem(int productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  /// Clears all cart items
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
