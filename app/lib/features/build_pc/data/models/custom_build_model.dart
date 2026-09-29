import '../../../catalog/data/models/product_model.dart';
import 'custom_build_slot.dart';

class CustomBuildModel {
  final int buildId;
  final String buildName;
  final Map<BuildSlotType, ProductModel> selectedComponents;
  final double totalCost;
  final int estimatedWattage;
  final String status; // 'Draft', 'Pending Staff Review', 'Approved by Staff', 'Completed'
  final String? customerNotes;
  final String? staffNotes;
  final DateTime submittedAt;
  final bool isCompatible;
  final List<String> compatibilityWarnings;

  const CustomBuildModel({
    required this.buildId,
    required this.buildName,
    required this.selectedComponents,
    required this.totalCost,
    required this.estimatedWattage,
    required this.status,
    this.customerNotes,
    this.staffNotes,
    required this.submittedAt,
    required this.isCompatible,
    this.compatibilityWarnings = const [],
  });

  /// Parse a CustomBuildDetailDto or CustomBuildSummaryDto from the backend API.
  factory CustomBuildModel.fromJson(Map<String, dynamic> json) {
    final components = <BuildSlotType, ProductModel>{};

    final rawComponents = json['components'];
    if (rawComponents is List) {
      for (final c in rawComponents) {
        final slotStr = (c['slotType'] as String? ?? '').toLowerCase().replaceAll(' ', '').replaceAll('_', '');
        final slot = BuildSlotType.values.firstWhere(
          (e) => e.name.toLowerCase() == slotStr,
          orElse: () {
            if (slotStr.contains('case') || slotStr.contains('chassis')) return BuildSlotType.pcCase;
            if (slotStr.contains('cool')) return BuildSlotType.cooler;
            if (slotStr.contains('power') || slotStr.contains('psu')) return BuildSlotType.psu;
            if (slotStr.contains('ram') || slotStr.contains('memory')) return BuildSlotType.ram;
            if (slotStr.contains('mobo') || slotStr.contains('motherboard')) return BuildSlotType.motherboard;
            if (slotStr.contains('gpu') || slotStr.contains('graphics')) return BuildSlotType.gpu;
            if (slotStr.contains('storage') || slotStr.contains('ssd') || slotStr.contains('disk')) return BuildSlotType.storage;
            return BuildSlotType.cpu;
          },
        );
        components[slot] = ProductModel(
          productId: (c['productId'] as num?)?.toInt() ?? 0,
          name: c['productName'] as String? ?? 'Component',
          price: (c['price'] as num?)?.toDouble() ?? 0.0,
          brand: c['brand'] as String?,
          socket: c['socket'] as String?,
          memoryType: c['memoryType'] as String?,
          powerWattage: (c['powerWattage'] as num?)?.toInt(),
          stockQuantity: (c['stockQuantity'] as num?)?.toInt() ?? 10,
        );
      }
    }

    return CustomBuildModel(
      buildId: (json['buildId'] as num?)?.toInt() ?? 0,
      buildName: json['buildName'] as String? ?? 'Custom Rig',
      selectedComponents: components,
      totalCost: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      estimatedWattage: (json['estimatedWattage'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'Pending Staff Review',
      customerNotes: json['customerNotes'] as String?,
      staffNotes: json['staffNotes'] as String?,
      submittedAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isCompatible:
          (json['isSocketCompatible'] as bool? ?? true) &&
          (json['isMemoryCompatible'] as bool? ?? true),
      compatibilityWarnings: const [],
    );
  }

  bool get isPendingReview =>
      status.toLowerCase().contains('pending');
  bool get isApproved =>
      status.toLowerCase().contains('approved');
  bool get isChangesRequested =>
      status.toLowerCase().contains('changes requested') ||
      status.toLowerCase().contains('request changed');
  bool get isReviewing =>
      status.toLowerCase().contains('in review') ||
      status.toLowerCase().contains('reviewing');

  CustomBuildModel copyWith({
    int? buildId,
    String? buildName,
    Map<BuildSlotType, ProductModel>? selectedComponents,
    double? totalCost,
    int? estimatedWattage,
    String? status,
    String? staffNotes,
    DateTime? submittedAt,
    bool? isCompatible,
    List<String>? compatibilityWarnings,
  }) {
    return CustomBuildModel(
      buildId: buildId ?? this.buildId,
      buildName: buildName ?? this.buildName,
      selectedComponents: selectedComponents ?? this.selectedComponents,
      totalCost: totalCost ?? this.totalCost,
      estimatedWattage: estimatedWattage ?? this.estimatedWattage,
      status: status ?? this.status,
      staffNotes: staffNotes ?? this.staffNotes,
      submittedAt: submittedAt ?? this.submittedAt,
      isCompatible: isCompatible ?? this.isCompatible,
      compatibilityWarnings: compatibilityWarnings ?? this.compatibilityWarnings,
    );
  }
}
