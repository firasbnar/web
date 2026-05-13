class WishlistItem {
  final String? id;
  final String? productId;
  final String? productName;
  final String? productImage;
  final double price;
  final double? comparePrice;
  final int stock;
  final String? boutiqueId;
  final String? boutiqueName;
  final String? createdAt;

  WishlistItem({
    this.id, this.productId, this.productName, this.productImage,
    required this.price, this.comparePrice, this.stock = 0,
    this.boutiqueId, this.boutiqueName, this.createdAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
    id: json['id']?.toString(),
    productId: json['productId']?.toString(),
    productName: json['productName'],
    productImage: json['productImage'],
    price: (json['price'] ?? 0).toDouble(),
    comparePrice: json['comparePrice']?.toDouble(),
    stock: json['stock'] ?? 0,
    boutiqueId: json['boutiqueId']?.toString(),
    boutiqueName: json['boutiqueName'],
    createdAt: json['createdAt'],
  );
}
