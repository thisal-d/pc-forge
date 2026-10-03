import '../../../catalog/data/models/product_model.dart';

class CartItemModel {
  final int cartItemId;
  final int cartId;
  final int productId;
  final int quantity;
  final ProductModel? product;

  const CartItemModel({
    required this.cartItemId,
    required this.cartId,
    required this.productId,
    required this.quantity,
    this.product,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      cartItemId: json['cartItemId'] as int? ?? 0,
      cartId: json['cartId'] as int? ?? 0,
      productId: json['productId'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 1,
      product: json['product'] != null
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cartItemId': cartItemId,
      'cartId': cartId,
      'productId': productId,
      'quantity': quantity,
      if (product != null) 'product': product!.toJson(),
    };
  }
}
