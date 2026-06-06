import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PublicWishlistItem {
  final String productId;
  final String name;
  final double price;
  final double? promotionalPrice;
  final String? image;
  final int stock;

  PublicWishlistItem({
    required this.productId,
    required this.name,
    required this.price,
    this.promotionalPrice,
    this.image,
    this.stock = 0,
  });

  double get effectivePrice => promotionalPrice != null && promotionalPrice! > 0 ? promotionalPrice! : price;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'price': price,
    'promotionalPrice': promotionalPrice,
    'image': image,
    'stock': stock,
  };

  factory PublicWishlistItem.fromJson(Map<String, dynamic> json) => PublicWishlistItem(
    productId: json['productId'] ?? '',
    name: json['name'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    promotionalPrice: json['promotionalPrice']?.toDouble(),
    image: json['image'],
    stock: json['stock'] ?? 0,
  );
}

class PublicWishlistProvider extends ChangeNotifier {
  final Map<String, List<PublicWishlistItem>> _wishlists = {};

  List<PublicWishlistItem> _getOrCreate(String slug) {
    return _wishlists.putIfAbsent(slug, () => []);
  }

  List<PublicWishlistItem> items(String slug) => _getOrCreate(slug);

  int count(String slug) => _getOrCreate(slug).length;

  bool isInWishlist(String slug, String productId) {
    return _getOrCreate(slug).any((i) => i.productId == productId);
  }

  Future<void> toggle(String slug, PublicWishlistItem item) async {
    final list = _getOrCreate(slug);
    final existing = list.where((i) => i.productId == item.productId).firstOrNull;
    if (existing != null) {
      list.remove(existing);
    } else {
      list.add(item);
    }
    await _persist(slug);
    notifyListeners();
  }

  Future<void> removeItem(String slug, String productId) async {
    _getOrCreate(slug).removeWhere((i) => i.productId == productId);
    await _persist(slug);
    notifyListeners();
  }

  Future<void> clearWishlist(String slug) async {
    _wishlists.remove(slug);
    await _persist(slug);
    notifyListeners();
  }

  Future<void> loadWishlist(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('public_wishlist_$slug');
    if (data != null) {
      final list = (jsonDecode(data) as List).map((e) => PublicWishlistItem.fromJson(e)).toList();
      _wishlists[slug] = list;
    }
    notifyListeners();
  }

  Future<void> _persist(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _wishlists[slug] ?? [];
    await prefs.setString('public_wishlist_$slug', jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
