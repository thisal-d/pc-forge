// Dart models for Member 04 Order Planning Agent proposal & order submission.
// Matches UI 4 (ui4.png) and UI 5 (ui5.png) in PCForge Agentic Workflow.

class AiOrderPricingItemModel {
  final int productId;
  final String slot;
  final String name;
  final double unitPrice;
  final int quantity;
  final double totalPrice;

  const AiOrderPricingItemModel({
    required this.productId,
    required this.slot,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  factory AiOrderPricingItemModel.fromJson(Map<String, dynamic> json) {
    return AiOrderPricingItemModel(
      productId: (json['product_id'] as num?)?.toInt() ?? (json['productId'] as num?)?.toInt() ?? 0,
      slot: json['slot']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'slot': slot,
    'name': name,
    'unit_price': unitPrice,
    'quantity': quantity,
    'total_price': totalPrice,
  };
}

class AiPricingBreakdownModel {
  final String currency;
  final double subtotal;
  final String? discountCode;
  final double discountAmount;
  final String? discountLabel;
  final String deliveryMethod;
  final double deliveryFee;
  final double totalPrice;
  final String formattedSubtotal;
  final String formattedDiscount;
  final String formattedDelivery;
  final String formattedTotal;

  const AiPricingBreakdownModel({
    this.currency = 'LKR',
    this.subtotal = 0.0,
    this.discountCode,
    this.discountAmount = 0.0,
    this.discountLabel,
    this.deliveryMethod = 'Standard Delivery',
    this.deliveryFee = 2500.0,
    this.totalPrice = 0.0,
    this.formattedSubtotal = 'LKR 0',
    this.formattedDiscount = '- LKR 0',
    this.formattedDelivery = 'LKR 0',
    this.formattedTotal = 'LKR 0',
  });

  factory AiPricingBreakdownModel.fromJson(Map<String, dynamic> json) {
    return AiPricingBreakdownModel(
      currency: json['currency']?.toString() ?? 'LKR',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountCode: json['discount_code']?.toString() ?? json['discountCode']?.toString(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountLabel: json['discount_label']?.toString() ?? json['discountLabel']?.toString(),
      deliveryMethod: json['delivery_method']?.toString() ?? json['deliveryMethod']?.toString() ?? 'Standard Delivery',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      formattedSubtotal: json['formatted_subtotal']?.toString() ?? json['formattedSubtotal']?.toString() ?? 'LKR 0',
      formattedDiscount: json['formatted_discount']?.toString() ?? json['formattedDiscount']?.toString() ?? '- LKR 0',
      formattedDelivery: json['formatted_delivery']?.toString() ?? json['formattedDelivery']?.toString() ?? 'LKR 0',
      formattedTotal: json['formatted_total']?.toString() ?? json['formattedTotal']?.toString() ?? 'LKR 0',
    );
  }
}

class AiOrderProposalModel {
  final String proposalId;
  final String orderNumber;
  final String buildName;
  final String reservationId;
  final String status;
  final String statusLabel;
  final int componentsCount;
  final AiPricingBreakdownModel pricing;
  final List<AiOrderPricingItemModel> components;
  final String estimatedDelivery;
  final String technicianNotice;

  const AiOrderProposalModel({
    required this.proposalId,
    required this.orderNumber,
    required this.buildName,
    required this.reservationId,
    this.status = 'WAITING_FOR_APPROVAL',
    this.statusLabel = 'Waiting for your approval',
    this.componentsCount = 8,
    required this.pricing,
    this.components = const [],
    this.estimatedDelivery = '3-5 business days',
    this.technicianNotice = "We'll notify you once a technician has checked your build — usually within a few hours.",
  });

  factory AiOrderProposalModel.fromJson(Map<String, dynamic> json) {
    final compsRaw = json['components'];
    final compsList = <AiOrderPricingItemModel>[];
    if (compsRaw is List) {
      for (final item in compsRaw) {
        if (item is Map) {
          compsList.add(AiOrderPricingItemModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return AiOrderProposalModel(
      proposalId: json['proposal_id']?.toString() ?? json['proposalId']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? json['orderNumber']?.toString() ?? 'PCF-10492',
      buildName: json['build_name']?.toString() ?? json['buildName']?.toString() ?? 'Custom PCForge Rig',
      reservationId: json['reservation_id']?.toString() ?? json['reservationId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'WAITING_FOR_APPROVAL',
      statusLabel: json['status_label']?.toString() ?? json['statusLabel']?.toString() ?? 'Waiting for your approval',
      componentsCount: (json['components_count'] as num?)?.toInt() ?? (json['componentsCount'] as num?)?.toInt() ?? compsList.length,
      pricing: json['pricing'] is Map
          ? AiPricingBreakdownModel.fromJson(Map<String, dynamic>.from(json['pricing'] as Map))
          : const AiPricingBreakdownModel(),
      components: compsList,
      estimatedDelivery: json['estimated_delivery']?.toString() ?? json['estimatedDelivery']?.toString() ?? '3-5 business days',
      technicianNotice: json['technician_notice']?.toString() ?? json['technicianNotice']?.toString() ??
          "We'll notify you once a technician has checked your build — usually within a few hours.",
    );
  }
}

class AiOrderProposalResultModel {
  final bool success;
  final AiOrderProposalModel? proposal;
  final List<String> agentTrace;
  final String? error;

  const AiOrderProposalResultModel({
    required this.success,
    this.proposal,
    this.agentTrace = const [],
    this.error,
  });

  factory AiOrderProposalResultModel.fromJson(Map<String, dynamic> json) {
    final rawTrace = json['agent_trace'] ?? json['agentTrace'];
    final traceList = <String>[];
    if (rawTrace is List) {
      for (final item in rawTrace) {
        if (item != null) {
          traceList.add(item.toString());
        }
      }
    }

    return AiOrderProposalResultModel(
      success: json['success'] as bool? ?? true,
      proposal: json['proposal'] is Map
          ? AiOrderProposalModel.fromJson(Map<String, dynamic>.from(json['proposal'] as Map))
          : null,
      agentTrace: traceList,
      error: json['error']?.toString(),
    );
  }
}

class AiSubmittedOrderModel {
  final bool success;
  final String orderNumber;
  final String status;
  final String formattedTotal;
  final String message;
  final DateTime createdAt;

  const AiSubmittedOrderModel({
    required this.success,
    required this.orderNumber,
    required this.status,
    required this.formattedTotal,
    required this.message,
    required this.createdAt,
  });

  factory AiSubmittedOrderModel.fromJson(Map<String, dynamic> json) {
    return AiSubmittedOrderModel(
      success: json['success'] as bool? ?? true,
      orderNumber: json['order_number']?.toString() ?? json['orderNumber']?.toString() ?? 'PCF-10492',
      status: json['status']?.toString() ?? 'Pending technician review',
      formattedTotal: json['formatted_total']?.toString() ?? json['formattedTotal']?.toString() ?? 'LKR 0',
      message: json['message']?.toString() ??
          "We'll notify you once a technician has checked your build — usually within a few hours.",
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }
}
