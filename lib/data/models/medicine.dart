class Medicine {
  final String id;
  final String name;
  final String genericName;
  final String sku;
  final String category;
  final String dosageForm; // e.g. Tablet, Syrup, Injection, Cream, Drops, Capsule
  final String unit;       // e.g. Box, Strip, Bottle, Piece, Pack
  final int packSize;      // Units per pack, e.g., 10 tablets/strip
  final int minStock;
  final String location;   // e.g. Rack A-1, Shelf 3
  final double defaultPrice;
  final double defaultCostPrice;
  final bool isActive;
  final int totalStock;    // Computed from active batches
  final String? description;
  final String? saltComposition;
  final bool requiresPrescription;
  final String productType; // Medicine or Grocery

  Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.sku,
    required this.category,
    required this.dosageForm,
    required this.unit,
    this.packSize = 10,
    required this.minStock,
    required this.location,
    required this.defaultPrice,
    required this.defaultCostPrice,
    this.isActive = true,
    this.totalStock = 0,
    this.description,
    this.saltComposition,
    this.requiresPrescription = false,
    this.productType = 'Medicine',
  });

  bool get isLowStock => totalStock <= minStock;
  bool get isOutOfStock => totalStock <= 0;
  bool get isGrocery => productType.toLowerCase() == 'grocery';
  bool get isTabletOrPack {
    final form = dosageForm.toLowerCase();
    final u = unit.toLowerCase();
    return packSize > 1 || form.contains('tablet') || form.contains('capsule') || u.contains('box') || u.contains('pack') || u.contains('strip');
  }
  int get effectivePackSize {
    if (packSize > 1) return packSize;
    if (isTabletOrPack) return 10;
    return 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'generic_name': genericName,
      'sku': sku,
      'category': category,
      'dosage_form': dosageForm,
      'unit': unit,
      'pack_size': packSize,
      'min_stock': minStock,
      'location': location,
      'default_price': defaultPrice,
      'default_cost_price': defaultCostPrice,
      'is_active': isActive ? 1 : 0,
      'description': description,
      'salt_composition': saltComposition,
      'requires_prescription': requiresPrescription ? 1 : 0,
      'product_type': productType,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map, {int totalStock = 0}) {
    return Medicine(
      id: map['id'] as String,
      name: map['name'] as String,
      genericName: map['generic_name'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      dosageForm: map['dosage_form'] as String? ?? 'Tablet',
      unit: map['unit'] as String? ?? 'Box',
      packSize: (map['pack_size'] as num?)?.toInt() ?? 10,
      minStock: (map['min_stock'] as num?)?.toInt() ?? 10,
      location: map['location'] as String? ?? 'Main Rack',
      defaultPrice: (map['default_price'] as num?)?.toDouble() ?? 0.0,
      defaultCostPrice: (map['default_cost_price'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as int?) == 1,
      totalStock: totalStock,
      description: map['description'] as String?,
      saltComposition: map['salt_composition'] as String?,
      requiresPrescription: (map['requires_prescription'] as int?) == 1,
      productType: map['product_type'] as String? ?? 'Medicine',
    );
  }

  Medicine copyWith({
    String? id,
    String? name,
    String? genericName,
    String? sku,
    String? category,
    String? dosageForm,
    String? unit,
    int? packSize,
    int? minStock,
    String? location,
    double? defaultPrice,
    double? defaultCostPrice,
    bool? isActive,
    int? totalStock,
    String? description,
    String? saltComposition,
    bool? requiresPrescription,
    String? productType,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      dosageForm: dosageForm ?? this.dosageForm,
      unit: unit ?? this.unit,
      packSize: packSize ?? this.packSize,
      minStock: minStock ?? this.minStock,
      location: location ?? this.location,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      defaultCostPrice: defaultCostPrice ?? this.defaultCostPrice,
      isActive: isActive ?? this.isActive,
      totalStock: totalStock ?? this.totalStock,
      description: description ?? this.description,
      saltComposition: saltComposition ?? this.saltComposition,
      requiresPrescription: requiresPrescription ?? this.requiresPrescription,
      productType: productType ?? this.productType,
    );
  }
}
