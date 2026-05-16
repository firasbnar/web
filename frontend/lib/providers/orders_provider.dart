import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/order.dart';

class OrdersProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Order> _orders = [];
  Order? _selectedOrder;
  bool _loading = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  String _statusFilter = '';
  final int _pageSize = 20;

  List<Order> get orders => _orders;
  Order? get selectedOrder => _selectedOrder;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadOrders(String boutiqueId, {bool refresh = false, String? search, String? startDate, String? endDate}) async {
    if (refresh) { _currentPage = 0; _orders = []; _hasMore = true; }
    if (!_hasMore || _loading) return;
    _loading = true; notifyListeners();
    try {
      final params = <String, dynamic>{
        'boutiqueId': boutiqueId, 'page': _currentPage, 'size': _pageSize,
      };
      if (_statusFilter.isNotEmpty) params['status'] = _statusFilter;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (startDate != null) params['startDate'] = startDate;
      if (endDate != null) params['endDate'] = endDate;
      final res = await _api.get('/orders', queryParameters: params);
      final data = res['data'];
      final List content = data['content'] ?? [];
      _orders.addAll(content.map((e) => Order.fromJson(e)).toList());
      _hasMore = data['last'] != true && content.length >= _pageSize;
      _currentPage++;
      _loading = false; notifyListeners();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); _loading = false; notifyListeners();
    }
  }

  Future<void> loadOrder(String id) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get('/orders/$id');
      _selectedOrder = Order.fromJson(res['data']);
      _loading = false; notifyListeners();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); _loading = false; notifyListeners();
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    try {
      final res = await _api.put('/orders/$id/status', data: {'status': status});
      _selectedOrder = Order.fromJson(res['data']);
      final idx = _orders.indexWhere((o) => o.id == id);
      if (idx >= 0) _orders[idx] = _selectedOrder!;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }

  Future<bool> updatePayment(String id, String paymentStatus, String? paymentRef) async {
    try {
      await _api.put('/orders/$id/payment', data: {'paymentStatus': paymentStatus, 'paymentRef': paymentRef});
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }

  Future<bool> updateTracking(String id, String company, String tracking) async {
    try {
      await _api.put('/orders/$id/tracking', data: {'deliveryCompany': company, 'trackingNumber': tracking});
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }

  void setStatusFilter(String status, String boutiqueId) {
    _statusFilter = status == 'ALL' ? '' : status;
    loadOrders(boutiqueId, refresh: true);
  }

  Future<bool> generateInvoice(String id) async {
    try {
      final res = await _api.post('/orders/$id/invoice');
      if (_selectedOrder != null && _selectedOrder!.id == id) {
        _selectedOrder = _selectedOrder!.copyWith(
          invoiceNumber: res['data']?.toString(),
        );
        final idx = _orders.indexWhere((o) => o.id == id);
        if (idx >= 0) _orders[idx] = _selectedOrder!;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  String invoiceUrl(String id) => '${ApiClient.baseUrl}/orders/$id/invoice';

  String invoicePrintUrl(String boutiqueId, String orderId) =>
      '${ApiClient.baseUrl}/boutiques/$boutiqueId/orders/$orderId/invoice/print';
}
