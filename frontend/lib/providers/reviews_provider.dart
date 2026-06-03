import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/review.dart';

class ReviewsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Review> _reviews = [];
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  String? _error;
  String _statusFilter = 'ALL';
  int _pendingCount = 0;

  List<Review> get reviews => _reviews;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  int get pendingCount => _pendingCount;

  void setStatusFilter(String filter) {
    _statusFilter = filter;
    _reviews = [];
    _currentPage = 0;
    _hasMore = true;
    notifyListeners();
  }

  Future<void> loadPendingCount(String boutiqueId) async {
    try {
      final res = await _api.get('/reviews/boutique/$boutiqueId/pending-count');
      _pendingCount = (res['data'] is int) ? res['data'] : (res['data']?['pendingCount'] ?? 0);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadReviews(String boutiqueId, {bool refresh = false}) async {
    if (refresh) {
      _reviews = [];
      _currentPage = 0;
      _hasMore = true;
    }
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{
        'page': _currentPage,
        'size': _pageSize,
        'sort': 'createdAt,desc',
      };
      if (_statusFilter != 'ALL') {
        params['status'] = _statusFilter;
      }
      final res = await _api.get('/reviews/boutique/$boutiqueId', queryParameters: params);
      final data = res['data'];
      final List content = data['content'] ?? [];
      final newReviews = content.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
      _reviews.addAll(newReviews);
      _pendingCount = data['pendingCount'] ?? 0;
      _currentPage++;
      _hasMore = newReviews.length >= _pageSize;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> approveReview(String reviewId) async {
    try {
      await _api.put('/reviews/$reviewId/approve');
      _updateReviewStatus(reviewId, 'APPROVED');
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectReview(String reviewId) async {
    try {
      await _api.put('/reviews/$reviewId/reject');
      _updateReviewStatus(reviewId, 'REJECTED');
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> replyToReview(String reviewId, String reply) async {
    try {
      final res = await _api.put('/reviews/$reviewId/reply', data: {'ownerReply': reply});
      final replyText = res['data']?['ownerReply']?.toString() ?? reply;
      final idx = _reviews.indexWhere((r) => r.id == reviewId);
      if (idx >= 0) {
        final old = _reviews[idx];
        _reviews[idx] = Review(
          id: old.id,
          productId: old.productId,
          productName: old.productName,
          customerName: old.customerName,
          rating: old.rating,
          comment: old.comment,
          ownerReply: replyText,
          status: old.status,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    try {
      await _api.delete('/reviews/$reviewId');
      _reviews.removeWhere((r) => r.id == reviewId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  void _updateReviewStatus(String reviewId, String newStatus) {
    final idx = _reviews.indexWhere((r) => r.id == reviewId);
    if (idx >= 0) {
      final old = _reviews[idx];
      _reviews[idx] = Review(
        id: old.id,
        productId: old.productId,
        productName: old.productName,
        customerName: old.customerName,
        rating: old.rating,
        comment: old.comment,
        ownerReply: old.ownerReply,
        status: newStatus,
        createdAt: old.createdAt,
      );
      if (newStatus != 'PENDING' && _pendingCount > 0) _pendingCount--;
      notifyListeners();
    }
  }
}
