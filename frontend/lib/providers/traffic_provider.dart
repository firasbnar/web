import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/traffic_stats.dart';

class TrafficProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  TrafficStatsModel? _stats;
  TrafficOverviewModel? _overview;
  List<VisitorEntry> _visitors = [];
  List<TimelinePoint> _timeline = [];
  Map<String, dynamic>? _visitorsPage;
  bool _loading = false;
  String? _error;

  TrafficStatsModel? get stats => _stats;
  TrafficOverviewModel? get overview => _overview;
  List<VisitorEntry> get visitors => _visitors;
  List<TimelinePoint> get timeline => _timeline;
  Map<String, dynamic>? get visitorsPage => _visitorsPage;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadStats(String boutiqueId) async {
    try {
      final res = await _api.get('/traffic/$boutiqueId/stats');
      _stats = TrafficStatsModel.fromJson(res['data'] ?? {});
      notifyListeners();
    } catch (e) {
      _error = 'Erreur de chargement des statistiques';
      notifyListeners();
    }
  }

  Future<void> loadOverview(String boutiqueId) async {
    try {
      final res = await _api.get('/traffic/$boutiqueId/overview');
      _overview = TrafficOverviewModel.fromJson(res['data'] ?? {});
      notifyListeners();
    } catch (e) {
      _error = 'Erreur de chargement de la vue d\'ensemble';
      notifyListeners();
    }
  }

  Future<void> loadVisitors(String boutiqueId, {int page = 0, int size = 10}) async {
    try {
      final res = await _api.get('/traffic/$boutiqueId/visitors',
          queryParameters: {'page': page, 'size': size});
      _visitorsPage = res['data'];
      final content = res['data']?['content'] as List? ?? [];
      _visitors = content.map((e) => VisitorEntry.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Erreur de chargement des visiteurs';
      notifyListeners();
    }
  }

  Future<void> loadTimeline(String boutiqueId, String from, String to,
      {String period = 'daily'}) async {
    try {
      final res = await _api.get('/traffic/$boutiqueId/timeline',
          queryParameters: {'from': from, 'to': to, 'period': period});
      final data = res['data'] as List? ?? [];
      _timeline = data.map((e) => TimelinePoint.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Erreur de chargement de la timeline';
      notifyListeners();
    }
  }

  Future<void> loadAll(String boutiqueId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    await Future.wait([
      loadStats(boutiqueId),
      loadOverview(boutiqueId),
      loadVisitors(boutiqueId),
    ]);
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _stats = null;
    _overview = null;
    _visitors = [];
    _timeline = [];
    _visitorsPage = null;
    _error = null;
    notifyListeners();
  }
}