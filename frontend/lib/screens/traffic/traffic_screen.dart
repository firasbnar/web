import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/api_client.dart';
import '../../models/traffic_stats.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/traffic_map_widget.dart';
import '../../widgets/visit_table.dart';
import '../../widgets/app_back_arrow.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});
  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  static const _isProd = bool.fromEnvironment('dart.vm.product');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  String? get _boutiqueId {
    final bp = context.read<BoutiqueProvider>();
    return bp.activeBoutique?.id ?? (bp.boutiques.isNotEmpty ? bp.boutiques.first.id : null);
  }

  Future<void> _load() async {
    final bp = context.read<BoutiqueProvider>();
    await bp.ensureActiveBoutique();
    if (!mounted) return;
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
      _topCountries = (results[1]['data'] as List?) ?? [];
      _topCities = (results[2]['data'] as List?) ?? [];
      final mapData = results[3]['data'] as List? ?? [];
      _mapPoints = mapData.map((e) => MapPoint.fromJson(e as Map<String, dynamic>)).toList();
      _recentPage = results[4]['data'];
      final recentContent = results[4]['data']?['content'] as List? ?? [];
      _recentVisits = recentContent.map((e) => RecentVisit.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) { _error = ApiClient.extractErrorMessage(e); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async => _load();

  Future<void> _injectDevTraffic() async {
    final bid = _boutiqueId;
    if (bid == null) return;
    try {
      final slug = context.read<BoutiqueProvider>().activeBoutique?.slug;
      if (slug == null) return;
      await _api.post('/dev/traffic/inject', data: {
        'slug': slug,
        'visits': 12,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test traffic injecté'.tr()), behavior: SnackBarBehavior.floating),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'common.error'.tr()}: ${ApiClient.extractErrorMessage(e)}'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.travel_explore, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('traffic.title'.tr(), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(boutiqueName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isProd)
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.science, size: 16),
                label: Text('Inject'.tr()),
                onPressed: _injectDevTraffic,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('menu.analytics'.tr()),
              onPressed: _openAnalytics,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            Text(_error ?? '', style: GoogleFonts.inter(color: AppColors.danger, fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('common.retry'.tr()),
              onPressed: _refresh,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildKpiGrid(),
          const SizedBox(height: 24),
          TrafficMapWidget(points: _mapPoints, loading: _loading, onRefresh: _refresh),
          const SizedBox(height: 24),
          _buildGeoRow(),
          const SizedBox(height: 24),
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('traffic.title'.tr(), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('traffic.overview'.tr(),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: Text('common.refresh'.tr()),
          onPressed: _refresh,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _kpiCard('traffic.visitors'.tr(), _stats?['totalVisits'] ?? 0, Icons.bar_chart, const Color(0xFF2710BF), const Color(0xFF6C4FFF)),
            _kpiCard('traffic.today'.tr(), _stats?['todayVisits'] ?? 0, Icons.today, const Color(0xFF0EA5E9), const Color(0xFF38BDF8)),
            _kpiCard('traffic.this_week'.tr(), _stats?['weekVisits'] ?? 0, Icons.date_range, const Color(0xFF10B981), const Color(0xFF34D399)),
            _kpiCard('traffic.this_month'.tr(), _stats?['monthVisits'] ?? 0, Icons.calendar_month, const Color(0xFFF59E0B), const Color(0xFFFBBF24)),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String label, int value, IconData icon, Color start, Color end) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16, right: -16,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [start.withOpacity(0.1), start.withOpacity(0)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: [start, end]),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCounter(
                      target: value,
                      style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeoRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _geoCard('traffic.countries'.tr(), Icons.flag_outlined, _topCountries, isCountry: true)),
              const SizedBox(width: 16),
              Expanded(child: _geoCard('Top Cities'.tr(), Icons.location_city_outlined, _topCities, isCountry: false)),
            ],
          );
        }
        return Column(
          children: [
            _geoCard('traffic.countries'.tr(), Icons.flag_outlined, _topCountries, isCountry: true),
            const SizedBox(height: 16),
            _geoCard('Top Cities'.tr(), Icons.location_city_outlined, _topCities, isCountry: false),
          ],
        );
      },
    );
  }

  Widget _geoCard(String title, IconData icon, List<dynamic> data, {required bool isCountry}) {
    final maxVal = data.isEmpty ? 0 : ((data.first['count'] as num?)?.toInt() ?? 0);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Text('${data.length} ${isCountry ? 'traffic.countries'.tr() : 'Cities'.tr()}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(isCountry ? Icons.flag_outlined : Icons.location_city_outlined, size: 32, color: AppColors.border),
                    const SizedBox(height: 8),
                    Text('common.no_data'.tr(), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                  ],
                ),
              ),
            )
          else
            ...(data.take(10).map((e) => _geoRow(e, maxVal, isCountry))),
        ],
      ),
    );
  }

  Widget _geoRow(dynamic e, int maxVal, bool isCountry) {
    final name = isCountry ? (e['country']?.toString() ?? 'common.no_data'.tr()) : (e['city']?.toString() ?? 'common.no_data'.tr());
    final count = ((e['count'] as num?)?.toInt() ?? 0);
    final pct = maxVal > 0 ? count / maxVal : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              if (isCountry) ...[
                Text(_flagForCountry(name), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('$count', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(width: 4),
              SizedBox(
                width: 32,
                child: Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint), textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _flagForCountry(String country) {
    const flags = {
      'Tunisie': '\u{1F1F9}\u{1F1F3}',
      'France': '\u{1F1EB}\u{1F1F7}',
      'Algérie': '\u{1F1E9}\u{1F1FF}',
      'Maroc': '\u{1F1F2}\u{1F1E6}',
      'États-Unis': '\u{1F1FA}\u{1F1F8}',
      'Canada': '\u{1F1E8}\u{1F1E6}',
      'Royaume-Uni': '\u{1F1EC}\u{1F1E7}',
      'Allemagne': '\u{1F1E9}\u{1F1EA}',
      'Italie': '\u{1F1EE}\u{1F1F9}',
      'Espagne': '\u{1F1EA}\u{1F1F8}',
      'Belgique': '\u{1F1E7}\u{1F1EA}',
      'Suisse': '\u{1F1E8}\u{1F1ED}',
      'Pays-Bas': '\u{1F1F3}\u{1F1F1}',
      'Chine': '\u{1F1E8}\u{1F1F3}',
      'Japon': '\u{1F1EF}\u{1F1F5}',
      'Brésil': '\u{1F1E7}\u{1F1F7}',
      'Inde': '\u{1F1EE}\u{1F1F3}',
      'Australie': '\u{1F1E6}\u{1F1FA}',
      'Libye': '\u{1F1F1}\u{1F1FE}',
      'Égypte': '\u{1F1EA}\u{1F1EC}',
      'Arabie Saoudite': '\u{1F1F8}\u{1F1E6}',
      'Türkiye': '\u{1F1F9}\u{1F1F7}',
      'Tunisia': '\u{1F1F9}\u{1F1F3}',
    };
    return flags[country] ?? '\u{1F30D}';
  }
}
