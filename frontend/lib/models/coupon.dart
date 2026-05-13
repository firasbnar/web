class Coupon {
  final String id;
  final String? boutiqueId;
  final String code;
  final String? discountType;
  final double discountValue;
  final double? minOrderAmount;
  final int? maxUses;
  final int? usedCount;
  final String? expiresAt;
  final bool isActive;

  Coupon({required this.id, this.boutiqueId, required this.code, this.discountType, required this.discountValue, this.minOrderAmount, this.maxUses, this.usedCount, this.expiresAt, this.isActive = true});

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
    id: json['id'].toString(),
    boutiqueId: json['boutiqueId']?.toString(),
    code: json['code'] ?? '',
    discountType: json['discountType'],
    discountValue: (json['discountValue'] ?? 0).toDouble(),
    minOrderAmount: json['minOrderAmount']?.toDouble(),
    maxUses: json['maxUses'],
    usedCount: json['usedCount'],
    expiresAt: json['expiresAt'],
    isActive: json['isActive'] ?? true,
  );
}
