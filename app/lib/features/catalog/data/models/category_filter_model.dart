class FilterOptionModel {
  final int optionId;
  final String value;
  final int displayOrder;

  const FilterOptionModel({
    required this.optionId,
    required this.value,
    this.displayOrder = 0,
  });

  factory FilterOptionModel.fromJson(Map<String, dynamic> json) {
    return FilterOptionModel(
      optionId: json['optionId'] as int? ?? 0,
      value: (json['value'] ?? json['optionValue'] ?? '').toString(),
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optionId': optionId,
      'value': value,
      'displayOrder': displayOrder,
    };
  }
}

class CategoryFilterModel {
  final int filterId;
  final int categoryId;
  final String categoryName;
  final String filterKey;
  final String displayName;
  final String filterType;
  final String? unit;
  final int displayOrder;
  final bool isFilterable;
  final List<FilterOptionModel> options;

  const CategoryFilterModel({
    required this.filterId,
    required this.categoryId,
    this.categoryName = '',
    required this.filterKey,
    required this.displayName,
    this.filterType = 'multiselect',
    this.unit,
    this.displayOrder = 0,
    this.isFilterable = true,
    this.options = const [],
  });

  factory CategoryFilterModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final List<FilterOptionModel> parsedOptions = [];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) {
          parsedOptions.add(FilterOptionModel.fromJson(Map<String, dynamic>.from(item)));
        } else if (item is String) {
          parsedOptions.add(FilterOptionModel(
            optionId: parsedOptions.length + 1,
            value: item,
            displayOrder: parsedOptions.length + 1,
          ));
        }
      }
    }

    return CategoryFilterModel(
      filterId: json['filterId'] as int? ?? 0,
      categoryId: json['categoryId'] as int? ?? 0,
      categoryName: json['categoryName'] as String? ?? '',
      filterKey: json['filterKey'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      filterType: json['filterType'] as String? ?? 'multiselect',
      unit: json['unit'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
      isFilterable: json['isFilterable'] as bool? ?? true,
      options: parsedOptions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filterId': filterId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'filterKey': filterKey,
      'displayName': displayName,
      'filterType': filterType,
      'unit': unit,
      'displayOrder': displayOrder,
      'isFilterable': isFilterable,
      'options': options.map((e) => e.toJson()).toList(),
    };
  }
}
