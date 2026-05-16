class DeliveryZone {
  final String id;
  final String name;
  final String? countries;
  final double fee;
  final double? minOrderAmount;
  final int? estimatedDays;
  final bool isActive;

  DeliveryZone({
    required this.id,
    required this.name,
    this.countries,
    this.fee = 0,
    this.minOrderAmount,
    this.estimatedDays,
    this.isActive = true,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) => DeliveryZone(
    id: json['id'].toString(),
    name: json['name'] ?? '',
    countries: json['countries'],
    fee: (json['fee'] ?? 0).toDouble(),
    minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble(),
    estimatedDays: json['estimatedDays'],
    isActive: json['isActive'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (countries != null) 'countries': countries,
    'fee': fee,
    if (minOrderAmount != null) 'minOrderAmount': minOrderAmount,
    if (estimatedDays != null) 'estimatedDays': estimatedDays,
    'isActive': isActive,
  };
}
