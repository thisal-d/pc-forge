class AiComponentStockStatusModel {
  final String slotType;
  final int productId;
  final String name;
  final String category;
  final String brand;
  final double price;
  final int stockQuantity;
  final String status;
  final String statusLabel;
  final bool wasSubstituted;
  final String? originalProductName;

  const AiComponentStockStatusModel({
    required this.slotType,
    required this.productId,
    required this.name,
    required this.category,
    this.brand = '',
    this.price = 0.0,
    required this.stockQuantity,
    required this.status,
    required this.statusLabel,
    this.wasSubstituted = false,
    this.originalProductName,
  });

  factory AiComponentStockStatusModel.fromJson(Map<String, dynamic> json) {
    return AiComponentStockStatusModel(
      slotType: json['slot_type'] as String? ?? '',
      productId: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Component',
      category: json['category'] as String? ?? 'Component',
      brand: json['brand'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      status: json['status'] as String? ?? 'IN_STOCK',
      statusLabel: json['status_label'] as String? ?? 'In stock',
      wasSubstituted: json['was_substituted'] as bool? ?? false,
      originalProductName: json['original_product_name'] as String?,
    );
  }
}

class AiReservationHoldModel {
  final String reservationId;
  final int heldMinutes;
  final String expiresAt;
  final String status;
  final List<int> reservedProductIds;

  const AiReservationHoldModel({
    required this.reservationId,
    this.heldMinutes = 15,
    required this.expiresAt,
    this.status = 'Reserved \u2713',
    this.reservedProductIds = const [],
  });

  factory AiReservationHoldModel.fromJson(Map<String, dynamic> json) {
    return AiReservationHoldModel(
      reservationId: json['reservation_id'] as String? ?? 'RES-HOLD',
      heldMinutes: json['held_minutes'] as int? ?? 15,
      expiresAt: json['expires_at'] as String? ?? '',
      status: json['status'] as String? ?? 'Reserved \u2713',
      reservedProductIds: (json['reserved_product_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );
  }
}

class AiStockVerificationModel {
  final bool success;
  final bool allInStock;
  final double totalPrice;
  final Map<String, AiComponentStockStatusModel> components;
  final AiReservationHoldModel reservation;
  final List<String> substitutionsMade;
  final String summary;
  final List<String> traceSteps;
  final String? error;

  const AiStockVerificationModel({
    required this.success,
    this.allInStock = true,
    this.totalPrice = 0.0,
    required this.components,
    required this.reservation,
    this.substitutionsMade = const [],
    this.summary = '',
    this.traceSteps = const [],
    this.error,
  });

  factory AiStockVerificationModel.fromJson(Map<String, dynamic> json) {
    final compsRaw = json['components'] as Map<String, dynamic>? ?? {};
    final parsedComps = <String, AiComponentStockStatusModel>{};
    compsRaw.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        parsedComps[k] = AiComponentStockStatusModel.fromJson(v);
      }
    });

    final resRaw = json['reservation'] is Map<String, dynamic>
        ? json['reservation'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AiStockVerificationModel(
      success: json['success'] as bool? ?? false,
      allInStock: json['all_in_stock'] as bool? ?? true,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      components: parsedComps,
      reservation: AiReservationHoldModel.fromJson(resRaw),
      substitutionsMade: (json['substitutions_made'] is List)
          ? (json['substitutions_made'] as List).map((e) => e.toString()).toList()
          : <String>[],
      summary: json['summary'] as String? ?? '',
      traceSteps: (json['trace_steps'] is List)
          ? (json['trace_steps'] as List).map((e) => e.toString()).toList()
          : <String>[],
      error: json['error'] as String?,
    );
  }
}
