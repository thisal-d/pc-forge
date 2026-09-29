import 'order_item_model.dart';

class OrderModel {
  final int orderId;
  final int userId;
  final double totalAmount;
  final String status;
  final String shippingAddress;
  final String paymentMethod;
  final DateTime createdAt;
  final List<OrderItemModel> items;
  final int? itemCount;

  const OrderModel({
    required this.orderId,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.createdAt,
    this.items = const [],
    this.itemCount,
  });

  String get formattedOrderId => '#ORD-${orderId.toString().padLeft(4, '0')}';

  int get totalItemCount => items.isNotEmpty
      ? items.fold(0, (sum, i) => sum + i.quantity)
      : (itemCount ?? 0);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return OrderModel(
      orderId: json['orderId'] as int? ?? 0,
      userId: json['userId'] as int? ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Pending',
      shippingAddress: json['shippingAddress'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String? ?? 'Credit Card',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: rawItems
          .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      itemCount: json['itemCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'userId': userId,
      'totalAmount': totalAmount,
      'status': status,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
