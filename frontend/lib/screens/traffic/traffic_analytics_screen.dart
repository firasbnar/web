import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/traffic_stats.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/traffic_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_button.dart';

import 'dart:async';

class TrafficAnalyticsScreen extends StatefulWidget {
  const TrafficAnalyticsScreen({super.key});

  @override
  State<TrafficAnalyticsScreen> createState() => _TrafficAnalyticsScreenState();
}

class _TrafficAnalyticsScreenState extends State<TrafficAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollTimer;
  String? _boutiqueId;
  String _period = 'daily';
  DateTimeRange? _dateRange;
  int _currentPage = 0;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _dateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLoad());
  }

  void _initLoad() {
    final bp = context.read<BoutiqueProvider>();
    final id = bp.activeBoutique?.id ??
        (bp.boutiques.isNotEmpty ? bp.boutiques.first.id : null);
    setState(() => _boutiqueId = id);
    if (_boutiqueId != null) {
      _loadData();
      _startPolling();
    }
  }

  void _loadData() {
    if (_boutiqueId == null) return;
    final tp = context.read<TrafficProvider>();
    tp.loadAll(_boutiqueId!);
    if (_dateRange != null) {
      tp.loadTimeline(
        _boutiqueId!,
        _dateRange!.start.toIso8601String().split('T')[0],
        _dateRange!.end.toIso8601String().split('T')[0],
        period: _period,
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_boutiqueId != null && mounted) {
        context.read<TrafficProvider>().loadStats(_boutiqueId!);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TrafficProvider>();
    final bp = context.watch<BoutiqueProvider>();
    final boutiqueName = bp.activeBoutique?.name ?? 'menu.store'.tr();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${'menu.analytics'.tr()} – $boutiqueName',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _refresh,
              color: AppColors.primary,
              tooltip: 'common.refresh'.tr(),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'traffic.overview'.tr()),
            Tab(text: 'traffic.visitors'.tr()),
            Tab(text: 'Charts'.tr()),
            Tab(text: 'Details'.tr()),
          ],
        ),
      ),
      body: tp.loading && tp.stats == null
          ? const Center(child: CircularProgressIndicator())
          : tp.error != null && tp.stats == null
              ? _buildError(tp.error ?? 'common.error'.tr(), _refresh)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(tp),
                    _buildVisitorsTab(tp),
                    _buildChartsTab(tp),
                    _buildDetailsTab(tp),
                  ],
                ),
    );
  }

  // ─── OVERVIEW TAB ─────────────────────────────────────────────────
  Widget _buildOverviewTab(TrafficProvider tp) {
    final stats = tp.stats;
    if (stats == null) return const SliverToBoxAdapter(child: SizedBox());

return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
// ── Live banner ──
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               gradient: const LinearGradient(
                 colors: [AppColors.primary, AppColors.primaryLight],
                 begin: Alignment.centerLeft,
                 end: Alignment.centerRight,
               ),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Row(
               children: [
                 const Icon(Icons.wifi_tethering, color: Colors.white, size: 28),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(
                          '${stats.activeVisitors} ${'traffic.visitors'.tr()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Real-time update'.tr(),
                         style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                           fontSize: 12,
                         ),
                       ),
                     ],
                   ),
                 ),
                 const Icon(Icons.live_tv, color: Colors.white, size: 28),
               ],
             ),
           ),
          const SizedBox(height: 20),

          // ── Stat cards row ──
          GridView.count(
            crossAxisCount: kIsWeb ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: kIsWeb ? 2.2 : 1.8,
            children: [
              _buildStatCard('traffic.visitors'.tr(),
                  '${stats.totalVisits}', Icons.people_outlined, AppColors.primary),
              _buildStatCard('traffic.unique_visitors'.tr(),
                  '${stats.uniqueVisitors}', Icons.person_pin, AppColors.success),
              _buildStatCard('traffic.today'.tr(),
                  '${stats.todayVisits}', Icons.calendar_today, AppColors.warning),
              _buildStatCard('traffic.this_week'.tr(),
                  '${stats.weekVisits}', Icons.timeline, AppColors.primaryLight),
              _buildStatCard('traffic.this_month'.tr(),
                  '${stats.monthVisits}', Icons.calendar_month, AppColors.success),
              _buildStatCard('Online now'.tr(),
                  '${stats.activeVisitors}', Icons.wifi, AppColors.danger),
            ],
          ),
          const SizedBox(height: 20),

          // ── Authenticated vs Anonymous ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visitor distribution'.tr(),
                      style: AppTypography.heading3),
                  const SizedBox(height: 12),
                  _buildHorizontalBar(
                      'Authenticated'.tr(),
                      stats.authenticatedVisitors,
                      stats.totalVisits,
                      AppColors.primary),
                  const SizedBox(height: 8),
                  _buildHorizontalBar(
                      'Anonymous'.tr(),
                      stats.anonymousVisitors,
                      stats.totalVisits,
                      AppColors.success),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Top Countries ──
          if (tp.overview != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.public,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('traffic.countries'.tr(), style: AppTypography.heading3),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...tp.overview!.topCountries.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(c.country,
                                  style: const TextStyle(fontSize: 13))),
                          Text('${c.count}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    )),
                    if (tp.overview!.topCountries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('common.no_data'.tr(),
                            style: TextStyle(color: AppColors.textHint)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ─── VISITORS TAB ────────────────────────────────────────────────
  Widget _buildVisitorsTab(TrafficProvider tp) {
    if (tp.loading && tp.visitors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async {
        final id = _boutiqueId;
        if (id != null) await tp.loadVisitors(id, page: 0, size: _pageSize);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _period,
                          items: [
                            DropdownMenuItem(
                                value: 'daily', child: Text('Daily'.tr())),
                            DropdownMenuItem(
                                value: 'weekly', child: Text('Weekly'.tr())),
                            DropdownMenuItem(
                                value: 'monthly', child: Text('Monthly'.tr())),
                          ],
                          onChanged: (v) {
                            setState(() => _period = v!);
                            if (_dateRange != null && _boutiqueId != null) {
                              context.read<TrafficProvider>().loadTimeline(
                                    _boutiqueId!,
                                    _dateRange!.start
                                        .toIso8601String()
                                        .split('T')[0],
                                    _dateRange!.end
                                        .toIso8601String()
                                        .split('T')[0],
                                    period: v!,
                                  );
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'traffic.period'.tr(),
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Table
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AppColors.surfaceAlt),
                columns: [
                  DataColumn(
                      label: Text('IP Hash',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('common.country'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Device'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Browser'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Visits'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Last activity'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: tp.visitors.map((v) {
                  return DataRow(cells: [
                    DataCell(Text(
                      v.ipHash.length > 12
                          ? '${v.ipHash.substring(0, 12)}…'
                          : v.ipHash,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
                    )),
                    DataCell(Text(v.country ?? '-',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(v.deviceType ?? '-',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(v.browser ?? '-',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${v.totalVisits}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(Text(v.lastActivityAt ?? '-',
                        style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
          ),

          // Pagination info
          if (tp.visitorsPage != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${'Page'.tr()} ${(tp.visitorsPage!['currentPage'] ?? 0) + 1} / ${tp.visitorsPage!['totalPages'] ?? 1}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${tp.visitorsPage!['totalElements'] ?? 0} ${'traffic.visitors'.tr()}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            ..._buildVisitorsPagination(tp),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildVisitorsPagination(TrafficProvider tp) {
    final page = tp.visitorsPage;
    if (page == null) return [];
    final cur = (page['currentPage'] as num?)?.toInt() ?? 0;
    final tot = (page['totalPages'] as num?)?.toInt() ?? 1;
    final hasPrev = cur > 0;
    final hasNext = cur < tot - 1;
    if (!hasPrev && !hasNext) return [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            if (hasPrev)
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text('Previous'.tr()),
                  onPressed: () {
                    final id = _boutiqueId;
                    if (id == null) return;
                    _currentPage = cur - 1;
                    tp.loadVisitors(id, page: _currentPage, size: _pageSize);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ),
            if (hasPrev && hasNext) const Spacer(),
            if (hasNext)
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text('common.next'.tr()),
                  onPressed: () {
                    final id = _boutiqueId;
                    if (id == null) return;
                    _currentPage = cur + 1;
                    tp.loadVisitors(id, page: _currentPage, size: _pageSize);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  // ─── CHARTS TAB ──────────────────────────────────────────────────
  Widget _buildChartsTab(TrafficProvider tp) {
    if (tp.loading && tp.timeline.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Timeline chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visits over time'.tr(),
                      style: AppTypography.heading3),
                  const SizedBox(height: 16),
                  if (tp.timeline.isNotEmpty)
                    SizedBox(
                      height: 250,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _maxY(tp.timeline),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${tp.timeline[groupIndex].visits} ${'Visits'.tr()}\n',
                                  const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${tp.timeline[groupIndex].uniqueVisitors} ${'Unique'.tr()}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 &&
                                      idx < tp.timeline.length) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(top: 8),
                                      child: Text(
                                        tp.timeline[idx].date.length > 10
                                            ? tp.timeline[idx]
                                                .date
                                                .substring(5)
                                            : tp.timeline[idx].date,
                                        style: const TextStyle(
                                            fontSize: 10),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: tp.timeline.asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.visits.toDouble(),
                                  color: AppColors.primary,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: Center(
                          child: Text('common.no_data'.tr(),
                              style: TextStyle(color: AppColors.textHint))),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Device breakdown pie
          if (tp.overview?.deviceBreakdown != null &&
              tp.overview!.deviceBreakdown.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('traffic.devices'.tr(), style: AppTypography.heading3),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: tp.overview!.deviceBreakdown.map((d) {
                            return PieChartSectionData(
                              color: _deviceColor(d.deviceType),
                              value: d.count.toDouble(),
                              title: '${d.deviceType}\n${d.count}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

// Browser breakdown
           if (tp.overview?.browserBreakdown != null &&
               tp.overview!.browserBreakdown.isNotEmpty) ...[
             Card(
               child: Padding(
                 padding: const EdgeInsets.all(16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Text('traffic.browsers'.tr(),
                          style: AppTypography.heading3),
                     const SizedBox(height: 12),
                     ...tp.overview!.browserBreakdown.map((b) => Padding(
                       padding:
                           const EdgeInsets.symmetric(vertical: 4),
                       child: Row(
                         children: [
                           Expanded(
                             flex: 3,
                             child: Text(b.browser,
                                 style: const TextStyle(fontSize: 13)),
                           ),
                           Expanded(
                             flex: 5,
                             child: ClipRRect(
                               borderRadius:
                                   BorderRadius.circular(4),
                               child: LinearProgressIndicator(
                                 value: b.percentage / 100,
                                 minHeight: 20,
                                 backgroundColor:
                                     AppColors.border,
                                 valueColor:
                                     const AlwaysStoppedAnimation<
                                             Color>(
                                         AppColors.primary),
                               ),
                             ),
                           ),
                           const SizedBox(width: 8),
                           SizedBox(
                             width: 45,
                             child: Text(
                               '${b.percentage.toStringAsFixed(1)}%',
                               style: const TextStyle(
                                   fontSize: 12,
                                   fontWeight:
                                       FontWeight.w600),
                               textAlign: TextAlign.right,
                             ),
                           ),
                         ],
                       ),
                     )),
                   ],
                 ),
               ),
             ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  // ─── DETAILS TAB ─────────────────────────────────────────────────
  Widget _buildDetailsTab(TrafficProvider tp) {
    if (tp.loading && tp.visitors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async {
        final id = _boutiqueId;
        if (id != null) await tp.loadVisitors(id, page: 0, size: _pageSize);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Referral sources
          if (tp.overview?.referralSources != null &&
              tp.overview!.referralSources.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('traffic.traffic_sources'.tr(),
                        style: AppTypography.heading3),
                    const SizedBox(height: 12),
                    ...tp.overview!.referralSources.map((r) => Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(r.source,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Expanded(
                            flex: 5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: r.percentage / 100,
                                minHeight: 20,
                                backgroundColor: AppColors.border,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        AppColors.success),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 45,
                            child: Text(
                              '${r.percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Real-time active visitors
          if (tp.stats != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi_tethering,
                            color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Text('Active visitors'.tr(),
                            style: AppTypography.heading3),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
child: Text(
                             '${tp.stats?.activeVisitors ?? 0}',
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(
                      value: 1,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.danger),
                    ),
                    const SizedBox(height: 4),
                    Text('Auto-refresh every 30s'.tr(),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────
  Widget _buildStatCard(String label, String value, IconData icon,
      Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                        fontSize: kIsWeb ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      )),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBar(String label, int value, int total, Color color) {
    final pct = total > 0 ? value / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 24,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text('${value > 0 ? (pct * 100).toStringAsFixed(0) : 0}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildError(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text('common.retry'.tr()),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }

  double _maxY(List<TimelinePoint> points) {
    if (points.isEmpty) return 10;
    return points.map((p) => p.visits).reduce((a, b) => a > b ? a : b)
            .toDouble() *
        1.1;
  }

  Color _deviceColor(String? device) {
    switch (device?.toLowerCase()) {
      case 'mobile':
        return Colors.blue;
      case 'tablet':
        return Colors.orange;
      case 'desktop':
        return AppColors.primary;
      default:
        return AppColors.textHint;
    }
  }
}