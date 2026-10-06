import 'dart:convert';

class ProductModel {
  final int productId;
  final int? categoryId;
  final String? categoryName;
  final String name;
  final String? brand;
  final String? model;
  final double price;
  final int stockQuantity;
  final String? imageUrl;
  final String? description;

  // Compatibility & Facet Attributes (Nanotek-style)
  final String? socket;           // e.g. AM5, LGA1700, AM4
  final String? chipset;          // e.g. X670E, B650, Z790, B760
  final String? memoryType;       // e.g. DDR5, DDR4
  final String? speed;            // e.g. 6000 MHz, 3200 MHz, 5600 MHz
  final String? capacity;         // e.g. 32GB (2x16GB), 16GB, 64GB
  final String? vram;             // e.g. 12GB, 24GB, 8GB, 16GB
  final int? powerWattage;        // e.g. 240 (GPU), 170 (CPU), 850 (PSU)
  final String? efficiencyRating; // e.g. 80+ Gold, 80+ Bronze
  final String? formFactor;       // e.g. ATX, Micro-ATX, Mini-ITX

  // Enriched E-Commerce Attributes
  final int warrantyMonths;
  final String? badge;            // e.g. "🔥 Popular", "🔥 Best Seller"
  final String? subSpec;          // e.g. "6 Cores 12 Threads | 3.7 GHz / 4.6 GHz"
  final List<String> images;      // Multi-image gallery URLs
  final String? customWarrantyText;
  final String status;

  const ProductModel({
    required this.productId,
    this.categoryId,
    this.categoryName,
    required this.name,
    this.brand,
    this.model,
    required this.price,
    this.stockQuantity = 0,
    this.imageUrl,
    this.description,
    this.socket,
    this.chipset,
    this.memoryType,
    this.speed,
    this.capacity,
    this.vram,
    this.powerWattage,
    this.efficiencyRating,
    this.formFactor,
    this.warrantyMonths = 0,
    this.badge,
    this.subSpec,
    this.images = const [],
    this.customWarrantyText,
    this.status = 'Active',
  });

  bool get isActive => status.toLowerCase() == 'active';

  /// Human-readable manufacturer warranty string grounded in DB warrantyMonths
  String get warrantyDisplay {
    if (customWarrantyText != null && customWarrantyText!.isNotEmpty) {
      return customWarrantyText!;
    }
    if (warrantyMonths >= 120) {
      return '10 Years (Limited Lifetime)';
    }
    if (warrantyMonths >= 12) {
      final years = warrantyMonths ~/ 12;
      final rem = warrantyMonths % 12;
      if (rem > 0) {
        return '$years Year${years > 1 ? "s" : ""} $rem Month${rem > 1 ? "s" : ""}';
      }
      return '$years Year${years > 1 ? "s" : ""}';
    }
    if (warrantyMonths > 0) {
      return '$warrantyMonths Months';
    }
    return 'Official Manufacturer Warranty';
  }

  String get warranty => warrantyDisplay;

  bool get isInStock => stockQuantity > 0;

  /// Dynamic helper to generate or return formatted sub-specification summary
  String get subSpecDisplay {
    if (subSpec != null && subSpec!.isNotEmpty) return subSpec!;

    final parts = <String>[];
    if (categoryName == 'CPU') {
      if (socket != null) parts.add('Socket $socket');
      if (powerWattage != null) parts.add('${powerWattage}W TDP');
    } else if (categoryName == 'GPU') {
      if (vram != null) parts.add('$vram GDDR6X');
      if (powerWattage != null) parts.add('${powerWattage}W TDP');
    } else if (categoryName == 'Motherboard') {
      if (chipset != null) parts.add(chipset!);
      if (socket != null) parts.add(socket!);
      if (formFactor != null) parts.add(formFactor!);
    } else if (categoryName == 'RAM') {
      if (capacity != null) parts.add(capacity!);
      if (speed != null) parts.add(speed!);
      if (memoryType != null) parts.add(memoryType!);
    } else if (categoryName == 'PSU') {
      if (powerWattage != null) parts.add('${powerWattage}W');
      if (efficiencyRating != null) parts.add(efficiencyRating!);
    }

    if (parts.isNotEmpty) {
      return parts.join(' | ');
    }
    return description != null && description!.length > 45
        ? '${description!.substring(0, 45)}...'
        : (description ?? 'High Performance Component');
  }

  /// List of spec badges for chips row
  List<String> get specChips {
    final chips = <String>[];
    if (socket != null) chips.add(socket!);
    if (chipset != null) chips.add(chipset!);
    if (memoryType != null) chips.add(memoryType!);
    if (speed != null) chips.add(speed!);
    if (capacity != null) chips.add(capacity!);
    if (vram != null) chips.add(vram!);
    if (formFactor != null) chips.add(formFactor!);
    if (efficiencyRating != null) chips.add(efficiencyRating!);
    if (powerWattage != null) chips.add('${powerWattage}W');
    return chips;
  }

  /// All image URLs for gallery
  List<String> get allImages {
    if (images.isNotEmpty) return images;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) return [imageUrl!.trim()];
    return [];
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    Map? specs;
    if (json['specifications'] is Map) {
      specs = json['specifications'] as Map;
    } else if (json['specifications'] is String) {
      try {
        final decoded = jsonDecode(json['specifications'] as String);
        if (decoded is Map) specs = decoded;
      } catch (_) {}
    }

    final imgUrl = json['imageUrl'] as String?;
    final gallery = <String>[];
    if (imgUrl != null && imgUrl.trim().isNotEmpty) {
      gallery.add(imgUrl.trim());
    }
    if (json['images'] is List) {
      for (final item in json['images'] as List) {
        if (item is String && item.trim().isNotEmpty && !gallery.contains(item.trim())) {
          gallery.add(item.trim());
        }
      }
    }

    return ProductModel(
      productId: json['productId'] as int? ?? 0,
      categoryId: json['categoryId'] as int?,
      categoryName: json['categoryName'] as String?,
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: json['stockQuantity'] as int? ?? 0,
      imageUrl: imgUrl,
      description: json['description'] as String?,
      socket: (json['socket'] as String?) ?? (specs?['socket'] as String?),
      chipset: (json['chipset'] as String?) ?? (specs?['chipset'] as String?),
      memoryType: (json['memoryType'] as String?) ??
          (specs?['memoryType'] as String?) ??
          (specs?['ddrType'] as String?),
      speed: (json['speed'] as String?) ?? (specs?['speed'] as String?),
      capacity: (json['capacity'] as String?) ?? (specs?['capacity'] as String?),
      vram: (json['vram'] as String?) ?? (specs?['vram'] as String?),
      powerWattage: json['powerWattage'] as int? ?? (specs?['powerWattage'] as num?)?.toInt(),
      efficiencyRating: (json['efficiencyRating'] as String?) ?? (specs?['efficiency'] as String?),
      formFactor: (json['formFactor'] as String?) ?? (specs?['formFactor'] as String?),
      warrantyMonths: (json['warrantyMonths'] as num?)?.toInt() ??
          (json['warranty_months'] as num?)?.toInt() ??
          (specs?['warranty_months'] as num?)?.toInt() ??
          0,
      badge: json['badge'] as String?,
      subSpec: json['subSpec'] as String?,
      images: gallery,
      customWarrantyText: (json['warranty'] as String?),
      status: json['status'] as String? ?? 'Active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'name': name,
      'brand': brand,
      'model': model,
      'price': price,
      'stockQuantity': stockQuantity,
      'status': status,
      'imageUrl': imageUrl,
      'description': description,
      'socket': socket,
      'chipset': chipset,
      'memoryType': memoryType,
      'speed': speed,
      'capacity': capacity,
      'vram': vram,
      'powerWattage': powerWattage,
      'efficiencyRating': efficiencyRating,
      'formFactor': formFactor,
      'warrantyMonths': warrantyMonths,
      'badge': badge,
      'subSpec': subSpec,
      'images': images,
      'warranty': warrantyDisplay,
    };
  }

}
