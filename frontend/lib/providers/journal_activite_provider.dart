import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/activity_log.dart';

class JournalActiviteProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  String? _boutiqueId;

  List<ActivityLog> _activities = [];
  bool _loading = false;
  String? _error;
  int _page = 0, _totalPages = 0;
  bool _done = false;

  String _searchQuery = '';
  String _actionFilter = '';
  String _statusFilter = '';
  String _startDate = '';
  String _endDate = '';

  Timer? _refreshTimer;
  int _onlineCount = 0;

  List<ActivityLog> get activities => _activities;
  bool get loading => _loading;
  String? get error => _error;
  bool get done => _done;
  String get searchQuery => _searchQuery;
  String get actionFilter => _actionFilter;
  String get statusFilter => _statusFilter;
  String get startDate => _startDate;
  String get endDate => _endDate;
  int get onlineCount => _onlineCount;

  void init(String boutiqueId) {
    _boutiqueId = boutiqueId;
    loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadActivities(refresh: true);
    });
  }

  void initAdmin() {
    _boutiqueId = null;
    loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      loadActivities(refresh: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void loadAll() {
    loadActivities(refresh: true);
  }

  Future<void> loadActivities({bool refresh = false}) async {
    if (_done && !refresh) return;
    if (refresh) { _page = 0; _activities = []; _done = false; }
    if (_page > 0 && _page >= _totalPages) { _done = true; return; }
    _loading = true; notifyListeners();
    try {
      final params = <String, dynamic>{
        'page': _page, 'size': 20,
        'search': _searchQuery.isNotEmpty ? _searchQuery : null,
        'action': _actionFilter.isNotEmpty ? _actionFilter : null,
        'status': _statusFilter.isNotEmpty ? _statusFilter : null,
        'startDate': _startDate.isNotEmpty ? _startDate : null,
        'endDate': _endDate.isNotEmpty ? _endDate : null,
      };
      params.removeWhere((_, v) => v == null);
      if (_boutiqueId != null) params['boutiqueId'] = _boutiqueId;

      final res = await _api.get('/admin/activities', queryParameters: params);
      final data = res['data'];
      _activities.addAll((data['content'] as List).map((e) => ActivityLog.fromJson(e)));
      _page++;
      _totalPages = data['totalPages'] ?? 0;
      _done = _page >= _totalPages;
      _error = null;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      _done = true;
    }
    _loading = false; notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    loadActivities(refresh: true);
  }

  void setActionFilter(String action) {
    _actionFilter = action;
    loadActivities(refresh: true);
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    loadActivities(refresh: true);
  }

  void setDateRange(String start, String end) {
    _startDate = start;
    _endDate = end;
    loadActivities(refresh: true);
  }

  void clearFilters() {
    _searchQuery = '';
    _actionFilter = '';
    _statusFilter = '';
    _startDate = '';
    _endDate = '';
    loadActivities(refresh: true);
  }

  void refresh() {
    loadActivities(refresh: true);
  }

  void updateOnlineCount(int count) {
    _onlineCount = count;
    notifyListeners();
  }

  void onWebSocketActivity(Map<String, dynamic> data) {
    loadActivities(refresh: true);
  }

  void onWebSocketPresence(dynamic data) {
    if (data is int) {
      _onlineCount = data;
    } else if (data is Map && data['count'] != null) {
      _onlineCount = data['count'] as int;
    }
    notifyListeners();
  }

  Future<String?> exportCsv() async {
    try {
      final params = <String, dynamic>{
        'search': _searchQuery.isNotEmpty ? _searchQuery : null,
        'action': _actionFilter.isNotEmpty ? _actionFilter : null,
        'status': _statusFilter.isNotEmpty ? _statusFilter : null,
        'startDate': _startDate.isNotEmpty ? _startDate : null,
        'endDate': _endDate.isNotEmpty ? _endDate : null,
      };
      params.removeWhere((_, v) => v == null);
      if (_boutiqueId != null) params['boutiqueId'] = _boutiqueId;
      final response = await _api.dio.get('/admin/activities/export',
          queryParameters: params,
          options: Options(responseType: ResponseType.bytes));
      return utf8.decode(response.data as List<int>);
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      return null;
    }
  }
}
