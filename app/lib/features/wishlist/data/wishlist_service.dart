import 'package:flutter/foundation.dart';
import '../../catalog/data/models/product_model.dart';

/// Reactive Wishlist State Manager
class WishlistService extends ChangeNotifier {
  static final WishlistService instance = WishlistService._internal();

  WishlistService._internal();

  final Map<int, ProductModel> _wishlistItems = {};

  List<ProductModel> get items => _wishlistItems.values.toList();

  int get totalCount => _wishlistItems.length;

  bool get isEmpty => _wishlistItems.isEmpty;

  bool isWishlisted(int productId) => _wishlistItems.containsKey(productId);

  void toggleWishlist(ProductModel product) {
    if (_wishlistItems.containsKey(product.productId)) {
      _wishlistItems.remove(product.productId);
    } else {
      _wishlistItems[product.productId] = product;
    }
    notifyListeners();
  }

  void removeFromWishlist(int productId) {
    if (_wishlistItems.remove(productId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    _wishlistItems.clear();
    notifyListeners();
  }
}
