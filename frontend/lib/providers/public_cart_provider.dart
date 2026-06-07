import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PublicCartItem {
  final String productId;
  final String name;
  final double price;
  final double? promotionalPrice;
  final String? image;
  final int stock;
  int quantity;
  final String? selectedColor;
  final String? selectedSize;

  PublicCartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.promotionalPrice,
    this.image,
    this.stock = 0,
    this.quantity = 1,
    this.selectedColor,
    this.selectedSize,
  });

  String get variantKey => '${productId}_${selectedColor ?? ''}_${selectedSize ?? ''}';

  double get effectivePrice => promotionalPrice != null && promotionalPrice! > 0 ? promotionalPrice! : price;
  double get subtotal => effectivePrice * quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'promotionalPrice': promotionalPrice,
    'image': image,
    'stock': stock,
    'quantity': quantity,
    'selectedColor': selectedColor,
    'selectedSize': selectedSize,
  };

  factory PublicCartItem.fromJson(Map<String, dynamic> json) => PublicCartItem(
    productId: json['productId'] ?? '',
    name: json['name'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    promotionalPrice: json['promotionalPrice']?.toDouble(),
    image: json['image'],
    stock: json['stock'] ?? 0,
    quantity: json['quantity'] ?? 1,
    selectedColor: json['selectedColor'] as String?,
    selectedSize: json['selectedSize'] as String?,
  );
}

class PublicCartProvider extends ChangeNotifier {
  final Map<String, List<PublicCartItem>> _carts = {};

  List<PublicCartItem> _getOrCreate(String slug) {
    return _carts.putIfAbsent(slug, () => []);
  }

  List<PublicCartItem> items(String slug) => _getOrCreate(slug);

  int itemCount(String slug) {
    return _getOrCreate(slug).fold(0, (sum, item) => sum + item.quantity);
  }

  double subtotal(String slug) {
    return _getOrCreate(slug).fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Future<void> addItem(String slug, PublicCartItem item) async {
    final list = _getOrCreate(slug);
    final existing = list.where((i) => i.variantKey == item.variantKey).firstOrNull;
    if (existing != null) {
      existing.quantity += item.quantity;
    } else {
      list.add(item);
    }
    await _persist(slug);
    notifyListeners();
  }

  Future<void> updateQuantity(String slug, String variantKey, int quantity) async {
    final list = _getOrCreate(slug);
    final item = list.where((i) => i.variantKey == variantKey).firstOrNull;
    if (item != null) {
      if (quantity <= 0) {
        list.remove(item);
      } else {
        item.quantity = quantity;
      }
    }
    await _persist(slug);
    notifyListeners();
  }

  Future<void> removeItem(String slug, String variantKey) async {
    final list = _getOrCreate(slug);
    list.removeWhere((i) => i.variantKey == variantKey);
    await _persist(slug);
    notifyListeners();
  }

  Future<void> clearCart(String slug) async {
    _carts.remove(slug);
    await _persist(slug);
    notifyListeners();
  }

  Future<void> loadCart(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('public_cart_$slug');
    if (data != null) {
      final list = (jsonDecode(data) as List).map((e) => PublicCartItem.fromJson(e)).toList();
      _carts[slug] = list;
    }
    notifyListeners();
  }

  Future<void> _persist(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _carts[slug] ?? [];
    await prefs.setString('public_cart_$slug', jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
