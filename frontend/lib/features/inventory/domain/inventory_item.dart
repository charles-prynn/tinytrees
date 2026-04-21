class InventoryItem {
  const InventoryItem({
    required this.itemKey,
    required this.quantity,
    required this.updatedAt,
  });

  final String itemKey;
  final int quantity;
  final DateTime? updatedAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemKey: json['item_key'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
