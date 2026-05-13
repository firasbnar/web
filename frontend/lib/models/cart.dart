import 'cart_item.dart';

class Cart {
  final String? id;
  final String? boutiqueId;
  final String? boutiqueName;
  final List<CartItem> items;
  final int itemCount;
  final double subtotal;

  Cart({
    this.id, this.boutiqueId, this.boutiqueName,
    this.items = const [], this.itemCount = 0, this.subtotal = 0,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    List<CartItem> itemList = [];
    if (json['items'] != null) {
      itemList = (json['items'] as List).map((e) => CartItem.fromJson(e)).toList();
    }
    return Cart(
      id: json['id']?.toString(),
      boutiqueId: json['boutiqueId']?.toString(),
      boutiqueName: json['boutiqueName'],
      items: itemList,
      itemCount: json['itemCount'] ?? 0,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}
