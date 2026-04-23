class PriceEntry {
  final String store;
  final double price;
  final String date;

  PriceEntry({required this.store, required this.price, required this.date});

  factory PriceEntry.fromJson(Map<String, dynamic> json) => PriceEntry(
        store: json['store'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        date: json['date'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'store': store,
        'price': price,
        'date': date,
      };
}

class Batch {
  final double quantity;
  final String? expireDate;

  Batch({required this.quantity, this.expireDate});

  factory Batch.fromJson(Map<String, dynamic> json) => Batch(
        quantity: (json['quantity'] ?? 0).toDouble(),
        expireDate: json['expireDate'],
      );

  Map<String, dynamic> toJson() => {
        'quantity': quantity,
        if (expireDate != null) 'expireDate': expireDate,
      };
}

class InventoryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String? expireDate;
  final List<Batch> batches;
  final List<PriceEntry> priceHistory;

  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expireDate,
    this.batches = const [],
    this.priceHistory = const [],
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        quantity: (json['quantity'] ?? 0).toDouble(),
        unit: json['unit'] ?? '',
        expireDate: json['expireDate'],
        batches: (json['batches'] as List<dynamic>?)
                ?.map((e) => Batch.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        priceHistory: (json['priceHistory'] as List<dynamic>?)
                ?.map((e) => PriceEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        if (expireDate != null) 'expireDate': expireDate,
        'priceHistory': priceHistory.map((e) => e.toJson()).toList(),
      };

  /// True if any non-expired batch expires within [days] from now.
  bool expiringSoon([int days = 3]) {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: days));
    return batches.any((b) {
      if (b.expireDate == null || b.quantity <= 0) return false;
      final date = DateTime.tryParse(b.expireDate!);
      return date != null && !date.isBefore(now) && date.isBefore(threshold);
    });
  }

  /// True if any batch is already expired.
  bool get hasExpired {
    final now = DateTime.now();
    return batches.any((b) {
      if (b.expireDate == null || b.quantity <= 0) return false;
      final date = DateTime.tryParse(b.expireDate!);
      return date != null && date.isBefore(now);
    });
  }
}
