import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/customer.dart';

class CustomersProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _loading = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  final int _pageSize = 20;

  List<Customer> get customers => _customers;
  Customer? get selectedCustomer => _selectedCustomer;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadCustomers(String boutiqueId, {bool refresh = false, String search = ''}) async {
    if (refresh) { _currentPage = 0; _customers = []; _hasMore = true; }
    if (!_hasMore || _loading) return;
    _loading = true; notifyListeners();
    try {
      final params = <String, dynamic>{
        'boutiqueId': boutiqueId, 'page': _currentPage, 'size': _pageSize,
      };
      if (search.isNotEmpty) params['search'] = search;
      final res = await _api.get('/customers', queryParameters: params);
      final data = res['data'];
      final List content = data['content'] ?? [];
      _customers.addAll(content.map((e) => Customer.fromJson(e)).toList());
      _hasMore = data['last'] != true && content.length >= _pageSize;
      _currentPage++;
      _loading = false; notifyListeners();
    } catch (e) {
      _error = e.toString(); _loading = false; notifyListeners();
    }
  }

  Future<void> loadCustomer(String id) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get('/customers/$id');
      _selectedCustomer = Customer.fromJson(res['data']);
      _loading = false; notifyListeners();
    } catch (e) {
      _error = e.toString(); _loading = false; notifyListeners();
    }
  }

  Future<Customer?> createCustomer(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/customers', data: data);
      final customer = Customer.fromJson(res['data']);
      _customers.insert(0, customer);
      notifyListeners();
      return customer;
    } catch (e) {
      _error = e.toString(); notifyListeners();
      return null;
    }
  }

  Future<bool> deleteCustomer(String id) async {
    try {
      await _api.delete('/customers/$id');
      _customers.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString(); notifyListeners();
      return false;
    }
  }
}
