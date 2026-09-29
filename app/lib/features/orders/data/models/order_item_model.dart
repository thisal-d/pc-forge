class OrderItemModel {
  final int orderItemId;
  final int orderId;
  final int productId;
  final String productName;
  final String? brand;
  final int quantity;
  final double unitPrice;

  const OrderItemModel({
    required this.orderItemId,
    required this.orderId,
    required this.productId,
    required this.productName,
    this.brand,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => unitPrice * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      orderItemId: json['orderItemId'] as int? ?? 0,
      orderId: json['orderId'] as int? ?? 0,
      productId: json['productId'] as int? ?? 0,
      productName: json['productName'] as String? ?? 'PC Component',
      brand: json['brand'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderItemId': orderItemId,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}
