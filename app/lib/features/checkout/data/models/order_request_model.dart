class OrderRequestModel {
  final String shippingAddress;
  final String city;
  final String postalCode;
  final String paymentMethod;
  final double totalAmount;

  const OrderRequestModel({
    required this.shippingAddress,
    required this.city,
    required this.postalCode,
    required this.paymentMethod,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'shippingAddress': shippingAddress,
      'city': city,
      'postalCode': postalCode,
      'paymentMethod': paymentMethod,
      'totalAmount': totalAmount,
    };
  }
}
