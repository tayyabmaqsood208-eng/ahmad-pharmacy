class AppSettings {
  final String pharmacyName;
  final String address;
  final String phone;
  final String email;
  final String taxNumber;
  final String currencySymbol;
  final double defaultTaxRate;
  final int defaultLowStockThreshold;
  final bool isDarkMode;

  AppSettings({
    this.pharmacyName = 'Ahmad Pharmacy',
    this.address = '123 Health Ave, Medical District',
    this.phone = '+1 (555) 019-2834',
    this.email = 'pos@ahmadpharmacy.com',
    this.taxNumber = 'TX-987654321',
    this.currencySymbol = 'Rs',
    this.defaultTaxRate = 5.0,
    this.defaultLowStockThreshold = 15,
    this.isDarkMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'pharmacy_name': pharmacyName,
      'address': address,
      'phone': phone,
      'email': email,
      'tax_number': taxNumber,
      'currency_symbol': currencySymbol,
      'default_tax_rate': defaultTaxRate,
      'default_low_stock_threshold': defaultLowStockThreshold,
      'is_dark_mode': isDarkMode ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      pharmacyName: map['pharmacy_name'] as String? ?? 'Ahmad Pharmacy',
      address: map['address'] as String? ?? '123 Health Ave, Medical District',
      phone: map['phone'] as String? ?? '+1 (555) 019-2834',
      email: map['email'] as String? ?? 'pos@ahmadpharmacy.com',
      taxNumber: map['tax_number'] as String? ?? 'TX-987654321',
      currencySymbol: map['currency_symbol'] as String? ?? 'Rs',
      defaultTaxRate: (map['default_tax_rate'] as num?)?.toDouble() ?? 5.0,
      defaultLowStockThreshold: (map['default_low_stock_threshold'] as num?)?.toInt() ?? 15,
      isDarkMode: (map['is_dark_mode'] as int?) == 1,
    );
  }

  AppSettings copyWith({
    String? pharmacyName,
    String? address,
    String? phone,
    String? email,
    String? taxNumber,
    String? currencySymbol,
    double? defaultTaxRate,
    int? defaultLowStockThreshold,
    bool? isDarkMode,
  }) {
    return AppSettings(
      pharmacyName: pharmacyName ?? this.pharmacyName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      defaultLowStockThreshold: defaultLowStockThreshold ?? this.defaultLowStockThreshold,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}
