class Review {
  final String id;
  final String? productId;
  final String? productName;
  final String customerName;
  final int rating;
  final String? comment;
  final String? ownerReply;
  final String status;
  final String createdAt;

  Review({
    required this.id,
    this.productId,
    this.productName,
    required this.customerName,
    required this.rating,
    this.comment,
    this.ownerReply,
    required this.status,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'].toString(),
    productId: json['productId']?.toString(),
    productName: json['productName']?.toString(),
    customerName: json['customerName'] ?? '',
    rating: json['rating'] ?? 0,
    comment: json['comment']?.toString(),
    ownerReply: json['ownerReply']?.toString(),
    status: json['status'] ?? 'PENDING',
    createdAt: json['createdAt']?.toString() ?? '',
  );

  bool get isApproved => status == 'APPROVED';
  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
}
