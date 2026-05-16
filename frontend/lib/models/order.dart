class Order {
  final String id;
  final String? boutiqueId;
  final String? userId;
  final String? customerId;
  final String? customerName;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double shippingFee;
  final double discount;
  final double total;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? paymentRef;
  final String? shippingAddress;
  final String? deliveryCompany;
  final String? trackingNumber;
  final String? notes;
  final String? invoiceNumber;
  final String? invoiceCreatedAt;
  final String? createdAt;
  final List<OrderItem> items;

  Order({
    required this.id, this.boutiqueId, this.userId, this.customerId, this.customerName,
    required this.orderNumber, required this.status,
    required this.subtotal, this.shippingFee = 0, this.discount = 0, required this.total,
    this.paymentMethod, this.paymentStatus, this.paymentRef,
    this.shippingAddress, this.deliveryCompany, this.trackingNumber,
    this.notes, this.invoiceNumber, this.invoiceCreatedAt, this.createdAt, this.items = const [],
  });

  Order copyWith({
    String? id,
    String? boutiqueId,
    String? userId,
    String? customerId,
    String? customerName,
    String? orderNumber,
    String? status,
    double? subtotal,
    double? shippingFee,
    double? discount,
    double? total,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentRef,
    String? shippingAddress,
    String? deliveryCompany,
    String? trackingNumber,
    String? notes,
    String? invoiceNumber,
    String? invoiceCreatedAt,
    String? createdAt,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      boutiqueId: boutiqueId ?? this.boutiqueId,
      userId: userId ?? this.userId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      shippingFee: shippingFee ?? this.shippingFee,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentRef: paymentRef ?? this.paymentRef,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      deliveryCompany: deliveryCompany ?? this.deliveryCompany,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      notes: notes ?? this.notes,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceCreatedAt: invoiceCreatedAt ?? this.invoiceCreatedAt,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> itemList = [];
    if (json['items'] != null) {
      itemList = (json['items'] as List).map((e) => OrderItem.fromJson(e)).toList();
    }
    return Order(
      id: json['id'].toString(),
      boutiqueId: json['boutiqueId']?.toString(),
      userId: json['userId']?.toString(),
      customerId: json['customerId']?.toString(),
      customerName: json['customerName'],
      orderNumber: json['orderNumber'] ?? '',
      status: json['status'] ?? 'PENDING',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      shippingFee: (json['shippingFee'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'],
      paymentStatus: json['paymentStatus'],
      paymentRef: json['paymentRef'],
      shippingAddress: json['shippingAddress'],
      deliveryCompany: json['deliveryCompany'],
      trackingNumber: json['trackingNumber'],
      notes: json['notes'],
      invoiceNumber: json['invoiceNumber'],
      invoiceCreatedAt: json['invoiceCreatedAt'],
      createdAt: json['createdAt'],
      items: itemList,
    );
  }
}

class OrderItem {
  final String? id;
  final String? productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;

  OrderItem({this.id, this.productId, required this.productName, required this.unitPrice, required this.quantity, required this.subtotal});

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id']?.toString(),
    productId: json['productId']?.toString(),
    productName: json['productName'] ?? '',
    unitPrice: (json['unitPrice'] ?? 0).toDouble(),
    quantity: json['quantity'] ?? 0,
    subtotal: (json['subtotal'] ?? 0).toDouble(),
  );
}
