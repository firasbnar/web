import 'package:flutter/material.dart';
import '../core/api_client.dart';

class AnalyticsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _revenueChart;
  Map<String, dynamic>? _ordersByStatus;
  List<dynamic>? _topProducts;
  Map<String, dynamic>? _trafficSources;
  bool _loading = false;

  Map<String, dynamic>? get overview => _overview;
  Map<String, dynamic>? get revenueChart => _revenueChart;
  Map<String, dynamic>? get ordersByStatus => _ordersByStatus;
  List<dynamic>? get topProducts => _topProducts;
  Map<String, dynamic>? get trafficSources => _trafficSources;
  bool get loading => _loading;

  Future<void> loadOverview(String boutiqueId, String from, String to) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get('/analytics/overview', queryParameters: {'boutiqueId': boutiqueId, 'from': from, 'to': to});
      _overview = res['data'];
      _loading = false; notifyListeners();
    } catch (_) { _loading = false; notifyListeners(); }
  }

  Future<void> loadRevenueChart(String boutiqueId, String period, String from, String to) async {
    try {
      final res = await _api.get('/analytics/revenue-chart', queryParameters: {'boutiqueId': boutiqueId, 'period': period, 'from': from, 'to': to});
      _revenueChart = res['data'];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadOrdersByStatus(String boutiqueId) async {
    try {
      final res = await _api.get('/analytics/orders-by-status', queryParameters: {'boutiqueId': boutiqueId});
      _ordersByStatus = res['data'];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadTopProducts(String boutiqueId) async {
    try {
      final res = await _api.get('/analytics/top-products', queryParameters: {'boutiqueId': boutiqueId, 'limit': 5});
      _topProducts = res['data'];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadTrafficSources(String boutiqueId) async {
    try {
      final res = await _api.get('/analytics/traffic-sources', queryParameters: {'boutiqueId': boutiqueId});
      _trafficSources = res['data'];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAll(String boutiqueId, String period, String from, String to) async {
    await Future.wait([
      loadOverview(boutiqueId, from, to),
      loadRevenueChart(boutiqueId, period, from, to),
      loadOrdersByStatus(boutiqueId),
      loadTopProducts(boutiqueId),
      loadTrafficSources(boutiqueId),
    ]);
  }
}
