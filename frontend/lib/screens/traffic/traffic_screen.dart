import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../models/traffic_stats.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/country_flag_bar.dart';
import '../../widgets/traffic_map_widget.dart';
import '../../widgets/visit_table.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});
  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<MapPoint> _mapPoints = [];
  List<dynamic> _topCountries = [];
  List<dynamic> _topCities = [];
  List<RecentVisit> _recentVisits = [];
  Map<String, dynamic>? _recentPage;
  bool _loading = false;
  String? _error;
  int _perPage = 10;
  int _recentPageIdx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _boutiqueId {
    final bp = context.read<BoutiqueProvider>();
    return bp.activeBoutique?.id ?? (bp.boutiques.isNotEmpty ? bp.boutiques.first.id : null);
  }

  Future<void> _load() async {
    final bid = _boutiqueId;
    if (bid == null) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.get('/boutiques/$bid/traffic/stats'),
        _api.get('/boutiques/$bid/traffic/top-countries'),
        _api.get('/boutiques/$bid/traffic/top-cities'),
        _api.get('/traffic/$bid/map'),
        _api.get('/traffic/$bid/recent', queryParameters: {'page': _recentPageIdx, 'size': _perPage}),
      ]);
      _stats = results[0]['data'];
      _topCountries = results[1]['data'] as List? ?? [];
      _topCities = results[2]['data'] as List? ?? [];
      final mapData = results[3]['data'] as List? ?? [];
      _mapPoints = mapData.map((e) => MapPoint.fromJson(e as Map<String, dynamic>)).toList();
      _recentPage = results[4]['data'];
      final recentContent = results[4]['data']?['content'] as List? ?? [];
      _recentVisits = recentContent.map((e) => RecentVisit.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) { _error = ApiClient.extractErrorMessage(e); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async => _load();

  Future<void> _loadRecentPage(int page) async {
    final bid = _boutiqueId;
    if (bid == null) return;
    setState(() => _recentPageIdx = page);
    try {
      final res = await _api.get('/traffic/$bid/recent',
          queryParameters: {'page': page, 'size': _perPage});
      _recentPage = res['data'];
      final content = res['data']?['content'] as List? ?? [];
      _recentVisits = content.map((e) => RecentVisit.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) { _error = ApiClient.extractErrorMessage(e); }
    if (mounted) setState(() {});
  }

  void _openAnalytics() {
    context.go('/traffic/analytics');
  }

  @override
  Widget build(BuildContext context) {
    final boutiqueName = context.read<BoutiqueProvider>().activeBoutique?.name ?? 'Boutique';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.show_chart, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Traffic du site \u2013 $boutiqueName'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading && _stats == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _stats == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 8),
                  Text(_error ?? '', style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('R\u00e9essayer'),
                    onPressed: _refresh,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  _buildStatsBar(),
                  _buildAnalyticsButton(),
                  TrafficMapWidget(
                    points: _mapPoints,
                    loading: _loading,
                    onRefresh: _refresh,
                  ),
                  _buildGeoRow(),
                  const SizedBox(height: 8),
                  VisitTable(
                    visits: _recentVisits,
                    pageInfo: _recentPage,
                    loading: _loading,
                    boutiqueId: _boutiqueId,
                    onRefresh: _refresh,
                    currentPage: _recentPageIdx,
                    pageSize: _perPage,
                    onPageChanged: _loadRecentPage,
                    onPageSizeChanged: (size) {
                      setState(() => _perPage = size);
                      _load();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4040C8), Color(0xFF8B2FC9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          _statItem('Total Visites', '${_stats?['totalVisits'] ?? 0}', _stats?['totalVisits'] ?? 0),
          _statItem("Aujourd'hui", '${_stats?['todayVisits'] ?? 0}', _stats?['todayVisits'] ?? 0),
          _statItem('Cette Semaine', '${_stats?['weekVisits'] ?? 0}', _stats?['weekVisits'] ?? 0),
          _statItem('Ce Mois', '${_stats?['monthVisits'] ?? 0}', _stats?['monthVisits'] ?? 0),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, int target) {
    return Expanded(
      child: Column(
        children: [
          AnimatedCounter(
            target: target,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.bar_chart, size: 20),
        label: const Text('Voir le tableau de bord Analytics complet'),
        onPressed: _openAnalytics,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildGeoRow() {
    final maxCountry = _topCountries.isEmpty ? 0 : ((_topCountries.first['count'] as num?)?.toInt() ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Text('Top Pays', style: AppTypography.heading4),
                        const Spacer(),
                        Text('${_topCountries.length} Pays',
                            style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_topCountries.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aucune donn\u00e9e',
                              style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                        ),
                      )
                    else
                      ...(_topCountries.take(10).map((e) => CountryFlagBar(
                        country: e['country']?.toString() ?? 'Inconnu',
                        count: ((e['count'] as num?)?.toInt() ?? 0),
                        maxCount: maxCountry,
                        barColor: AppColors.primary,
                      ))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_city_outlined, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Text('Top Villes', style: AppTypography.heading4),
                        const Spacer(),
                        Text('${_topCities.length} Villes',
                            style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_topCities.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aucune donn\u00e9e',
                              style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                        ),
                      )
                    else
                      ...(_topCities.take(10).map((e) {
                        final count = ((e['count'] as num?)?.toInt() ?? 0);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(e['city']?.toString() ?? 'Inconnu',
                                    style: AppTypography.body2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 40,
                                child: Text('$count',
                                    style: AppTypography.body2.copyWith(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        );
                      })),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
