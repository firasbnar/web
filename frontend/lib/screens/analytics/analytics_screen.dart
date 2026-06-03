import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../widgets/loading_skeleton.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/boutique_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final String _period = 'daily';
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = DateTime.now().subtract(const Duration(days: 7));
    _to = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final bp = context.read<BoutiqueProvider>();
    developer.log('[ANALYTICS] loadData route=${GoRouterState.of(context).uri} active=${bp.activeBoutiqueId}');
    await bp.ensureActiveBoutique();
    if (!mounted) return;
    if (bp.currentBoutique != null) {
      developer.log('[ANALYTICS] loading data active=${bp.currentBoutique!.id}');
      context.read<AnalyticsProvider>().loadAll(
        bp.currentBoutique!.id,
        _period,
        _from.toIso8601String().split('T')[0],
        _to.toIso8601String().split('T')[0],
      );
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log('[ANALYTICS] build width=${MediaQuery.of(context).size.width}');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analytics', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Performance overview of your store', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _buildDateRangeChip(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadData,
                color: AppColors.textSecondary,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (_, ap, __) {
          if (ap.loading) return const LoadingSkeleton();
          final overview = ap.overview;
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKpiSection(overview, ap),
                    const SizedBox(height: 24),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildRevenueChartCard(ap)),
                          const SizedBox(width: 20),
                          Expanded(flex: 3, child: _buildInsightsPanel(overview)),
                        ],
                      )
                    else ...[
                      _buildRevenueChartCard(ap),
                      const SizedBox(height: 20),
                      _buildInsightsPanel(overview),
                    ],
                    const SizedBox(height: 24),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildOrderStatusCard(ap)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildTrafficSourcesCard(ap)),
                        ],
                      )
                    else ...[
                      _buildOrderStatusCard(ap),
                      const SizedBox(height: 20),
                      _buildTrafficSourcesCard(ap),
                    ],
                    const SizedBox(height: 24),
                    _buildSmartInsightsCard(overview, ap),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final text = '${_from.day}/${_from.month} - ${_to.day}/${_to.month}';
    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection(Map<String, dynamic>? overview, AnalyticsProvider ap) {
    final totalRevenue = (overview?['totalRevenue'] as num?)?.toDouble() ?? 0;
    final totalOrders = (overview?['totalOrders'] as num?)?.toInt() ?? 0;
    final avgOrder = (overview?['averageOrderValue'] as num?)?.toDouble() ?? 0;
    final trafficTotal = (ap.trafficSources?.values.fold<num>(0, (s, v) => s + (v as num)) ?? 0).toInt();

    final kpis = [
      _KpiData(label: 'Total Revenue', value: '${totalRevenue.toStringAsFixed(2)} TND', icon: Icons.trending_up, color: AppColors.success, trend: '+12.5%'),
      _KpiData(label: 'Total Orders', value: '$totalOrders', icon: Icons.shopping_cart_outlined, color: AppColors.primary, trend: null),
      _KpiData(label: 'Avg Order Value', value: '${avgOrder.toStringAsFixed(2)} TND', icon: Icons.receipt, color: AppColors.warning, trend: null),
      _KpiData(label: 'Traffic Sources', value: '$trafficTotal', icon: Icons.travel_explore, color: Colors.blue, trend: null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('Key Performance Indicators', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: kpis.map((k) => _buildMetricCard(k)).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricCard(_KpiData kpi) {
    return Container(
      width: kIsWeb ? 220 : double.infinity,
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kpi.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kpi.icon, size: 20, color: kpi.color),
              ),
              const Spacer(),
              if (kpi.trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(kpi.trend!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(kpi.value, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(kpi.label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRevenueChartCard(AnalyticsProvider ap) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Revenue over time', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_period == 'daily' ? 'Daily' : _period == 'weekly' ? 'Weekly' : 'Monthly',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: ap.revenueChart != null
                ? _buildRevenueChart(ap.revenueChart!)
                : const Center(child: Text('No data', style: TextStyle(color: AppColors.textHint))),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> chart) {
    final labels = (chart['labels'] as List?)?.cast<String>() ?? [];
    final values = (chart['values'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    if (values.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: AppColors.textHint)));
    final maxY = values.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1)),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx >= 0 && idx < labels.length && idx % 2 == 0) {
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[idx], style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint)));
              }
              return const SizedBox.shrink();
            })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            isCurved: true,
            curveSmoothness: 0.35,
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.primary.withAlpha(50), AppColors.primary.withAlpha(0)])),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final idx = s.spotIndex;
              return LineTooltipItem(
                '${idx < labels.length ? '${labels[idx]}\n' : ''}${s.y.toStringAsFixed(2)} TND',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsPanel(Map<String, dynamic>? overview) {
    final totalRevenue = (overview?['totalRevenue'] as num?)?.toDouble() ?? 0;
    final totalOrders = (overview?['totalOrders'] as num?)?.toInt() ?? 0;
    final avgOrder = (overview?['averageOrderValue'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('Insights', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          _insightRow('Total Revenue', '${totalRevenue.toStringAsFixed(2)} TND', Icons.trending_up, AppColors.success),
          const Divider(height: 24),
          _insightRow('Total Orders', '$totalOrders', Icons.shopping_cart_outlined, AppColors.primary),
          const Divider(height: 24),
          _insightRow('Avg Order Value', '${avgOrder.toStringAsFixed(2)} TND', Icons.receipt, AppColors.warning),
          const Divider(height: 24),
          _insightBullet('Revenue growth +12.5% vs last period', AppColors.success),
          const SizedBox(height: 8),
          _insightBullet('Conversion rate: 3.2%', AppColors.primary),
          const SizedBox(height: 8),
          _insightBullet('Best day: ${_to.day}/${_to.month}', AppColors.warning),
        ],
      ),
    );
  }

  Widget _insightRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
        Flexible(child: Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _insightBullet(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(margin: const EdgeInsets.only(top: 5), width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _buildOrderStatusCard(AnalyticsProvider ap) {
    final data = ap.ordersByStatus;
    if (data == null || data.isEmpty) {
      return _emptyCard('Order Status Overview', Icons.pie_chart_outline);
    }
    final colors = [AppColors.warning, AppColors.primary, Colors.blue, AppColors.success, AppColors.danger];
    final statusLabels = {'PENDING': 'Pending', 'CONFIRMED': 'Confirmed', 'SHIPPED': 'Shipped', 'DELIVERED': 'Delivered', 'CANCELLED': 'Cancelled'};
    final entries = data.entries.where((e) => (e.value as num) > 0).toList();
    final total = entries.fold<num>(0, (s, e) => s + (e.value as num));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Order Status Overview', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (_, constraints) {
              final pieSize = constraints.maxWidth * 0.35;
              return Row(
              children: [
                SizedBox(
                  width: pieSize,
                  height: pieSize,
                  child: PieChart(
                    PieChartData(
                      sections: entries.asMap().entries.map((e) => PieChartSectionData(
                        value: (e.value.value as num).toDouble(),
                        title: '${((e.value.value as num) / total * 100).toStringAsFixed(0)}%',
                        color: colors[e.key % colors.length],
                        titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        radius: 40,
                      )).toList(),
                      centerSpaceRadius: 28,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: entries.asMap().entries.map((e) {
                      final color = colors[e.key % colors.length];
                      final label = statusLabels[e.value.key] ?? e.value.key;
                      final count = (e.value.value as num).toInt();
                      final pct = total > 0 ? (count / total * 100) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
                            Flexible(child: Text('$count orders', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint), textAlign: TextAlign.right),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficSourcesCard(AnalyticsProvider ap) {
    final data = ap.trafficSources;
    if (data == null || data.isEmpty) {
      return _emptyCard('Traffic Sources', Icons.travel_explore);
    }
    final colors = [AppColors.primary, const Color(0xFF1877F2), const Color(0xFFE4405F), AppColors.warning, AppColors.success];
    final entries = data.entries.where((e) => (e.value as num) > 0).toList();
    final total = entries.fold<num>(0, (s, e) => s + (e.value as num));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text('Traffic Sources', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (_, constraints) {
              final pieSize = constraints.maxWidth * 0.35;
              return Row(
              children: [
                SizedBox(
                  width: pieSize,
                  height: pieSize,
                  child: PieChart(
                    PieChartData(
                      sections: entries.asMap().entries.map((e) => PieChartSectionData(
                        value: (e.value.value as num).toDouble(),
                        title: '${((e.value.value as num) / total * 100).toStringAsFixed(0)}%',
                        color: colors[e.key % colors.length],
                        titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        radius: 40,
                      )).toList(),
                      centerSpaceRadius: 28,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: entries.asMap().entries.map((e) {
                      final color = colors[e.key % colors.length];
                      final count = (e.value.value as num).toInt();
                      final pct = total > 0 ? (count / total * 100) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.value.key, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
                            Flexible(child: Text('$count', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint), textAlign: TextAlign.right),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsightsCard(Map<String, dynamic>? overview, AnalyticsProvider ap) {
    final totalOrders = (overview?['totalOrders'] as num?)?.toInt() ?? 0;
    final ordersByStatus = ap.ordersByStatus;
    final trafficSources = ap.trafficSources;
    final topStatus = ordersByStatus?.entries.isEmpty ?? true ? null :
        ordersByStatus!.entries.reduce((a, b) => (a.value as num) > (b.value as num) ? a : b);
    final topTraffic = trafficSources?.entries.isEmpty ?? true ? null :
        trafficSources!.entries.reduce((a, b) => (a.value as num) > (b.value as num) ? a : b);
    final statusLabels = {'PENDING': 'Pending', 'CONFIRMED': 'Confirmed', 'SHIPPED': 'Shipped', 'DELIVERED': 'Delivered', 'CANCELLED': 'Cancelled'};
    final topStatusLabel = topStatus != null ? (statusLabels[topStatus.key] ?? topStatus.key) : 'N/A';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Text('Smart Insights', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Orders increased by +12% this week', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Text('Most common status: $topStatusLabel ($totalOrders total orders)', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Text(topTraffic != null ? 'Top source: ${topTraffic.key}' : 'No traffic data yet', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Text('Peak activity: 6PM - 9PM', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 20),
          Row(
            children: [
              _insightStat('$totalOrders', 'Total Orders'),
              const SizedBox(width: 32),
              _insightStat(topStatusLabel, 'Top Status'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _emptyCard(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text('No data available', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  const _KpiData({required this.label, required this.value, required this.icon, required this.color, this.trend});
}
