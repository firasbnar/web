import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/cashier.dart';
import '../models/activity_log.dart';

class PosAdminProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  String? _boutiqueId;

  Map<String, dynamic>? _dashboard;
  List<Cashier> _cashiers = [];
  List<Map<String, dynamic>> _orders = [];
  List<ActivityLog> _activities = [];
  Map<String, dynamic>? _cashierStats;
  List<Map<String, dynamic>> _searchResults = [];
  Cashier? _selectedCashier;

  bool _loadingDashboard = false;
  bool _loadingCashiers = false;
  bool _loadingOrders = false;
  bool _loadingActivities = false;
  final bool _loadingCashierStats = false;
  bool _searchingUsers = false;

  String? _dashboardError;
  String? _cashiersError;
  String? _ordersError;
  String? _activitiesError;
  String? _cashierStatsError;
  String? _cashierActionError;

  int _cashierPage = 0, _orderPage = 0, _activityPage = 0;
  int _cashierTotalPages = 0, _orderTotalPages = 0, _activityTotalPages = 0;
  bool _cashiersDone = false, _ordersDone = false, _activitiesDone = false;

  String _orderStatusFilter = '';
  String _orderDateFilter = '';
  String _activityActionFilter = '';
  String _cashierSearchQuery = '';
  String? _orderUserIdFilter;

  Timer? _refreshTimer;

  Map<String, dynamic>? get dashboard => _dashboard;
  List<Cashier> get cashiers => _cashiers;
  List<Map<String, dynamic>> get orders => _orders;
  List<ActivityLog> get activities => _activities;
  Map<String, dynamic>? get cashierStats => _cashierStats;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  Cashier? get selectedCashier => _selectedCashier;

  bool get loadingDashboard => _loadingDashboard;
  bool get loadingCashiers => _loadingCashiers;
  bool get loadingOrders => _loadingOrders;
  bool get loadingActivities => _loadingActivities;
  bool get loadingCashierStats => _loadingCashierStats;
  bool get searchingUsers => _searchingUsers;

  String? get dashboardError => _dashboardError;
  String? get cashiersError => _cashiersError;
  String? get ordersError => _ordersError;
  String? get activitiesError => _activitiesError;
  String? get cashierStatsError => _cashierStatsError;
  String? get cashierActionError => _cashierActionError;

  bool get cashiersDone => _cashiersDone;
  bool get ordersDone => _ordersDone;
  bool get activitiesDone => _activitiesDone;

  String get orderStatusFilter => _orderStatusFilter;
  String get orderDateFilter => _orderDateFilter;
  String get activityActionFilter => _activityActionFilter;
  String get cashierSearchQuery => _cashierSearchQuery;
  String? get orderUserIdFilter => _orderUserIdFilter;

  void init(String boutiqueId) {
    _boutiqueId = boutiqueId;
    loadAll();
    loadCashierStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      loadDashboard();
      loadCashierStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void loadAll() {
    loadDashboard();
    loadCashiers(refresh: true);
    loadOrders(refresh: true);
    loadActivities(refresh: true);
  }

  Future<void> loadDashboard() async {
    if (_boutiqueId == null) return;
    _loadingDashboard = true; notifyListeners();
    try {
      final res = await _api.get('/boutiques/$_boutiqueId/caisse/stats');
      _dashboard = res['data'];
      _dashboardError = null;
    } catch (e) {
      _dashboardError = ApiClient.extractErrorMessage(e);
    }
    _loadingDashboard = false; notifyListeners();
  }

  Future<void> loadCashierStats() async {
    if (_boutiqueId == null) return;
    try {
      final res = await _api.get('/boutiques/$_boutiqueId/caisse/cashiers/stats');
      _cashierStats = res['data'];
      _cashierStatsError = null;
    } catch (e) {
      _cashierStatsError = ApiClient.extractErrorMessage(e);
    }
    notifyListeners();
  }

  Future<void> loadCashiers({bool refresh = false}) async {
    if (_boutiqueId == null || (_cashiersDone && !refresh)) return;
    if (refresh) { _cashierPage = 0; _cashiers = []; _cashiersDone = false; }
    _loadingCashiers = true; notifyListeners();
    try {
      final params = <String, dynamic>{'page': _cashierPage, 'size': 20};
      if (_cashierSearchQuery.isNotEmpty) params['search'] = _cashierSearchQuery;
      final res = await _api.get('/boutiques/$_boutiqueId/caisse/cashiers',
          queryParameters: params);
      final data = res['data'];
      _cashiers.addAll((data['content'] as List).map((e) => Cashier.fromJson(e)));
      _cashierPage++;
      _cashierTotalPages = data['totalPages'] ?? 0;
      _cashiersDone = _cashierPage >= _cashierTotalPages;
      _cashiersError = null;
    } catch (e) {
      _cashiersError = ApiClient.extractErrorMessage(e);
      _cashiersDone = true;
    }
    _loadingCashiers = false; notifyListeners();
  }

  Future<void> loadOrders({bool refresh = false}) async {
    if (_boutiqueId == null || (_ordersDone && !refresh)) return;
    if (refresh) { _orderPage = 0; _orders = []; _ordersDone = false; }
    _loadingOrders = true; notifyListeners();
    try {
      final params = <String, dynamic>{'page': _orderPage, 'size': 20};
      if (_orderStatusFilter.isNotEmpty) params['status'] = _orderStatusFilter;
      if (_orderDateFilter.isNotEmpty) params['date'] = _orderDateFilter;
      if (_orderUserIdFilter != null) params['userId'] = _orderUserIdFilter;
      final res = await _api.get('/boutiques/$_boutiqueId/caisse/orders',
          queryParameters: params);
      final data = res['data'];
      _orders.addAll((data['content'] as List).cast<Map<String, dynamic>>());
      _orderPage++;
      _orderTotalPages = data['totalPages'] ?? 0;
      _ordersDone = _orderPage >= _orderTotalPages;
      _ordersError = null;
    } catch (e) {
      _ordersError = ApiClient.extractErrorMessage(e);
      _ordersDone = true;
    }
    _loadingOrders = false; notifyListeners();
  }

  Future<void> loadActivities({bool refresh = false}) async {
    if (_boutiqueId == null || (_activitiesDone && !refresh)) return;
    if (refresh) { _activityPage = 0; _activities = []; _activitiesDone = false; }
    _loadingActivities = true; notifyListeners();
    try {
      final params = <String, dynamic>{'page': _activityPage, 'size': 20};
      if (_activityActionFilter.isNotEmpty) params['action'] = _activityActionFilter;
      final res = await _api.get('/boutiques/$_boutiqueId/caisse/activities',
          queryParameters: params);
      final data = res['data'];
      _activities.addAll((data['content'] as List).map((e) => ActivityLog.fromJson(e)));
      _activityPage++;
      _activityTotalPages = data['totalPages'] ?? 0;
      _activitiesDone = _activityPage >= _activityTotalPages;
      _activitiesError = null;
    } catch (e) {
      _activitiesError = ApiClient.extractErrorMessage(e);
      _activitiesDone = true;
    }
    _loadingActivities = false; notifyListeners();
  }

  void setOrderStatusFilter(String status) {
    _orderStatusFilter = status;
    loadOrders(refresh: true);
  }

  void setOrderDateFilter(String date) {
    _orderDateFilter = date;
    loadOrders(refresh: true);
  }

  void setActivityActionFilter(String action) {
    _activityActionFilter = action;
    loadActivities(refresh: true);
  }

  void setCashierSearchQuery(String query) {
    _cashierSearchQuery = query;
    loadCashiers(refresh: true);
  }

  void selectCashier(Cashier? cashier) {
    _selectedCashier = cashier;
    _orderUserIdFilter = cashier?.id;
    loadOrders(refresh: true);
    notifyListeners();
  }

  Future<bool> toggleCashierStatus(String userId, bool suspend) async {
    if (_boutiqueId == null) return false;
    try {
      if (suspend) {
        await _api.put('/boutiques/$_boutiqueId/caisse/cashiers/$userId/suspend');
      } else {
        await _api.put('/boutiques/$_boutiqueId/caisse/cashiers/$userId/activate');
      }
      loadCashiers(refresh: true);
      loadDashboard();
      return true;
    } catch (e) {
      _cashierActionError = ApiClient.extractErrorMessage(e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (_boutiqueId == null) return [];
    _searchingUsers = true; notifyListeners();
    try {
      final res = await _api.get('/boutiques/$_boutiqueId/caisse/users/search',
          queryParameters: {'query': query});
      _searchResults = (res['data'] as List).cast<Map<String, dynamic>>();
      _searchingUsers = false; notifyListeners();
      return _searchResults;
    } catch (e) {
      _searchingUsers = false; notifyListeners();
      return [];
    }
  }

  Future<bool> createCashier(String email, String fullName, String role) async {
    if (_boutiqueId == null) return false;
    try {
      await _api.post('/boutiques/$_boutiqueId/caisse/cashiers', data: {
        'email': email, 'fullName': fullName, 'role': role,
      });
      loadCashiers(refresh: true);
      loadCashierStats();
      return true;
    } catch (e) {
      _cashierActionError = ApiClient.extractErrorMessage(e);
      return false;
    }
  }

  Future<bool> deleteCashier(String userId) async {
    if (_boutiqueId == null) return false;
    try {
      await _api.delete('/boutiques/$_boutiqueId/caisse/cashiers/$userId');
      loadCashiers(refresh: true);
      loadCashierStats();
      return true;
    } catch (e) {
      _cashierActionError = ApiClient.extractErrorMessage(e);
      return false;
    }
  }

  void onWebSocketStats(Map<String, dynamic> data) {
    _dashboard = data;
    notifyListeners();
  }

  void onWebSocketOrder(Map<String, dynamic> data) {
    loadOrders(refresh: true);
    loadDashboard();
  }

  void onWebSocketActivity(Map<String, dynamic> data) {
    loadActivities(refresh: true);
  }
}
