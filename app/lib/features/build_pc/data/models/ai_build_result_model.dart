class AiComponentItemModel {
  final int productId;
  final String name;
  final String category;
  final String brand;
  final String? model;
  final double price;
  final String? socket;
  final String? memoryType;
  final int? powerWattage;
  final String? formFactor;

  const AiComponentItemModel({
    required this.productId,
    required this.name,
    required this.category,
    required this.brand,
    this.model,
    required this.price,
    this.socket,
    this.memoryType,
    this.powerWattage,
    this.formFactor,
  });

  factory AiComponentItemModel.fromJson(Map<String, dynamic> json) {
    return AiComponentItemModel(
      productId: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Component',
      category: json['category'] as String? ?? 'Component',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      socket: json['socket'] as String?,
      memoryType: json['memory_type'] as String?,
      powerWattage: json['power_wattage'] as int?,
      formFactor: json['form_factor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'category': category,
        'brand': brand,
        'model': model,
        'price': price,
        'socket': socket,
        'memory_type': memoryType,
        'power_wattage': powerWattage,
        'form_factor': formFactor,
      };
}

class CompatibilityChecklistModel {
  final bool socketMatch;
  final String socketDetails;
  final bool memoryMatch;
  final String memoryDetails;
  final bool wattageOk;
  final int estimatedWattage;
  final int psuWattage;
  final int headroomWatts;
  final bool caseFitOk;
  final String caseFitDetails;
  final bool allPassed;

  const CompatibilityChecklistModel({
    this.socketMatch = true,
    this.socketDetails = '',
    this.memoryMatch = true,
    this.memoryDetails = '',
    this.wattageOk = true,
    this.estimatedWattage = 0,
    this.psuWattage = 0,
    this.headroomWatts = 0,
    this.caseFitOk = true,
    this.caseFitDetails = '',
    this.allPassed = true,
  });

  factory CompatibilityChecklistModel.fromJson(Map<String, dynamic> json) {
    return CompatibilityChecklistModel(
      socketMatch: json['socket_match'] as bool? ?? true,
      socketDetails: json['socket_details'] as String? ?? '',
      memoryMatch: json['memory_match'] as bool? ?? true,
      memoryDetails: json['memory_details'] as String? ?? '',
      wattageOk: json['wattage_ok'] as bool? ?? true,
      estimatedWattage: json['estimated_wattage'] as int? ?? 0,
      psuWattage: json['psu_wattage'] as int? ?? 0,
      headroomWatts: json['headroom_watts'] as int? ?? 0,
      caseFitOk: json['case_fit_ok'] as bool? ?? true,
      caseFitDetails: json['case_fit_details'] as String? ?? '',
      allPassed: json['all_passed'] as bool? ?? true,
    );
  }
}

class ValidatedBuildModel {
  final String buildName;
  final String purpose;
  final String targetResolution;
  final Map<String, AiComponentItemModel> components;
  final double totalPrice;
  final int estimatedWattage;
  final CompatibilityChecklistModel compatibility;
  final bool isValid;
  final String status;

  const ValidatedBuildModel({
    required this.buildName,
    required this.purpose,
    required this.targetResolution,
    required this.components,
    required this.totalPrice,
    required this.estimatedWattage,
    required this.compatibility,
    required this.isValid,
    required this.status,
  });

  factory ValidatedBuildModel.fromJson(Map<String, dynamic> json) {
    final compsRaw = json['components'] as Map<String, dynamic>? ?? {};
    final parsedComps = <String, AiComponentItemModel>{};
    compsRaw.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedComps[key] = AiComponentItemModel.fromJson(val);
      }
    });

    return ValidatedBuildModel(
      buildName: json['build_name'] as String? ?? 'PCForge Custom Build',
      purpose: json['purpose'] as String? ?? 'Gaming',
      targetResolution: json['target_resolution'] as String? ?? '1440p',
      components: parsedComps,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      estimatedWattage: json['estimated_wattage'] as int? ?? 0,
      compatibility: json['compatibility'] is Map<String, dynamic>
          ? CompatibilityChecklistModel.fromJson(
              json['compatibility'] as Map<String, dynamic>)
          : const CompatibilityChecklistModel(),
      isValid: json['is_valid'] as bool? ?? false,
      status: json['status'] as String? ?? 'VALIDATED_PENDING_STOCK',
    );
  }

  AiComponentItemModel? get cpu => components['cpu'];
  AiComponentItemModel? get motherboard => components['motherboard'];
  AiComponentItemModel? get ram => components['ram'];
  AiComponentItemModel? get gpu => components['gpu'];
  AiComponentItemModel? get psu => components['psu'];
  AiComponentItemModel? get storage => components['storage'];
  AiComponentItemModel? get pcCase => components['pc_case'];
  AiComponentItemModel? get cooler => components['cooler'];
}

class AiBuildResultModel {
  final bool success;
  final ValidatedBuildModel? build;
  final String summary;
  final List<String> traceSteps;
  final String? error;

  const AiBuildResultModel({
    required this.success,
    this.build,
    this.summary = '',
    this.traceSteps = const [],
    this.error,
  });

  factory AiBuildResultModel.fromJson(Map<String, dynamic> json) {
    return AiBuildResultModel(
      success: json['success'] as bool? ?? false,
      build: json['build'] is Map<String, dynamic>
          ? ValidatedBuildModel.fromJson(json['build'] as Map<String, dynamic>)
          : null,
      summary: json['summary'] as String? ?? '',
      traceSteps: (json['trace_steps'] is List)
          ? (json['trace_steps'] as List).map((e) => e.toString()).toList()
          : <String>[],
      error: json['error'] as String?,
    );
  }
}
