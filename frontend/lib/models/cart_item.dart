class CartItem {
  final String? id;
  final String? productId;
  final String? productName;
  final String? productImage;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final int? availableStock;

  CartItem({
    this.id, this.productId, this.productName, this.productImage,
    required this.unitPrice, required this.quantity, required this.subtotal,
    this.availableStock,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id']?.toString(),
    productId: json['productId']?.toString(),
    productName: json['productName'],
    productImage: json['productImage'],
    unitPrice: (json['unitPrice'] ?? 0).toDouble(),
    quantity: json['quantity'] ?? 0,
    subtotal: (json['subtotal'] ?? 0).toDouble(),
    availableStock: json['availableStock'],
  );
}
