class RequirementProfileModel {
  final String? purpose;
  final String? budgetRaw;
  final double? budgetAmount;
  final String currency;
  final String? targetResolution;
  final bool? monitorNeeded;
  final List<String> preferences;
  final List<String> missingFields;
  final bool isComplete;

  const RequirementProfileModel({
    this.purpose,
    this.budgetRaw,
    this.budgetAmount,
    this.currency = 'LKR',
    this.targetResolution,
    this.monitorNeeded,
    this.preferences = const [],
    this.missingFields = const [],
    this.isComplete = false,
  });

  factory RequirementProfileModel.fromJson(Map<String, dynamic> json) {
    return RequirementProfileModel(
      purpose: json['purpose'] as String?,
      budgetRaw: json['budget_raw'] as String?,
      budgetAmount: json['budget_amount'] != null
          ? (json['budget_amount'] as num).toDouble()
          : null,
      currency: json['currency'] as String? ?? 'LKR',
      targetResolution: json['target_resolution'] as String?,
      monitorNeeded: json['monitor_needed'] as bool?,
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      missingFields: (json['missing_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isComplete: json['is_complete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'budget_raw': budgetRaw,
        'budget_amount': budgetAmount,
        'currency': currency,
        'target_resolution': targetResolution,
        'monitor_needed': monitorNeeded,
        'preferences': preferences,
        'missing_fields': missingFields,
        'is_complete': isComplete,
      };
}
