import '../core/url_utils.dart';

class Product {
  final String id;
  final String? boutiqueId;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final double price;
  final double? comparePrice;
  final int stock;
  final String? sku;
  final List<String> images;
  final bool isActive;
  final bool isFeatured;
  final String? seoTitle;
  final String? seoDescription;
  final double? purchasePrice;
  final String? colors;
  final String? sizes;
  final String? descriptionHtml;

  Product({
    required this.id, this.boutiqueId, this.categoryId, this.categoryName,
    required this.name, this.description, required this.price,
    this.comparePrice, this.stock = 0, this.sku,
    this.images = const [], this.isActive = true, this.isFeatured = false,
    this.seoTitle, this.seoDescription,
    this.purchasePrice, this.colors, this.sizes, this.descriptionHtml,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> imgList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imgList = (json['images'] as List).map((e) => e.toString()).toList();
      } else if (json['images'] is String) {
        try {
          final s = json['images'] as String;
          if (s.startsWith('[')) {
            imgList = s.substring(1, s.length - 1)
                .split(',').map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
          }
        } catch (_) {}
      }
    }
    imgList = imgList.map((url) => normalizeRemoteUrl(url) ?? url).toList();
    return Product(
      id: json['id'].toString(),
      boutiqueId: json['boutiqueId']?.toString(),
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName'],
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      comparePrice: json['comparePrice']?.toDouble(),
      stock: json['stock'] ?? 0,
      sku: json['sku'],
      images: imgList,
      isActive: json['isActive'] ?? true,
      isFeatured: json['isFeatured'] ?? false,
      seoTitle: json['seoTitle'],
      seoDescription: json['seoDescription'],
      purchasePrice: json['purchasePrice']?.toDouble(),
      colors: json['colors'],
      sizes: json['sizes'],
      descriptionHtml: json['descriptionHtml'],
    );
  }
}

class Category {
  final String id;
  final String? boutiqueId;
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;

  Category({required this.id, this.boutiqueId, required this.name, required this.slug, this.imageUrl, this.sortOrder = 0});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'].toString(),
    boutiqueId: json['boutiqueId']?.toString(),
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    imageUrl: normalizeRemoteUrl(json['imageUrl']),
    sortOrder: json['sortOrder'] ?? 0,
  );
}
