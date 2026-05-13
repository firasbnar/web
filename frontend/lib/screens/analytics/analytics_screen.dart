import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/boutique_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _period = 'daily';
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = DateTime.now().subtract(const Duration(days: 7));
    _to = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final bp = context.read<BoutiqueProvider>();
    if (bp.currentBoutique != null) {
      context.read<AnalyticsProvider>().loadAll(
        bp.currentBoutique!.id,
        _period,
        _from.toIso8601String().split('T')[0],
        _to.toIso8601String().split('T')[0],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytiques'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _period,
            onSelected: (v) { setState(() => _period = v); _loadData(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'daily', child: Text('Jour')),
              const PopupMenuItem(value: 'weekly', child: Text('Semaine')),
              const PopupMenuItem(value: 'monthly', child: Text('Mois')),
            ],
          ),
        ],
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (_, ap, __) {
          if (ap.loading) return const LoadingSkeleton();
          final overview = ap.overview;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      StatCard(label: 'Revenu total', value: '${overview?['totalRevenue']?.toStringAsFixed(2) ?? "0.00"} TND', icon: Icons.trending_up, color: AppColors.success),
                      const SizedBox(width: 12),
                      StatCard(label: 'Commandes', value: '${overview?['totalOrders'] ?? 0}', icon: Icons.shopping_cart_outlined),
                      const SizedBox(width: 12),
                      StatCard(label: 'Panier moyen', value: '${overview?['averageOrderValue']?.toStringAsFixed(2) ?? "0.00"} TND', icon: Icons.receipt),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Revenus', style: AppTypography.heading3),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ap.revenueChart != null
                      ? _buildRevenueChart(ap.revenueChart!)
                      : const Center(child: Text('Aucune donnée')),
                ),
                const SizedBox(height: 24),
                Text('Commandes par statut', style: AppTypography.heading3),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ap.ordersByStatus != null
                      ? _buildStatusPieChart(ap.ordersByStatus!)
                      : const Center(child: Text('Aucune donnée')),
                ),
                const SizedBox(height: 24),
                Text('Sources de trafic', style: AppTypography.heading3),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ap.trafficSources != null
                      ? _buildTrafficPieChart(ap.trafficSources!)
                      : const Center(child: Text('Aucune donnée')),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> chart) {
    final labels = (chart['labels'] as List?)?.cast<String>() ?? [];
    final values = (chart['values'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    if (values.isEmpty) return const Center(child: Text('Aucune donnée'));

    final maxY = values.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < labels.length && idx % 2 == 0) {
                  return Text(labels[idx], style: const TextStyle(fontSize: 9));
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            color: AppColors.primary,
            barWidth: 2,
            isCurved: true,
            belowBarData: BarAreaData(show: true, color: AppColors.primary.withAlpha(30)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart(Map<String, dynamic> data) {
    final colors = [AppColors.warning, AppColors.primary, Colors.blue, AppColors.success, AppColors.danger];
    final statusLabels = {'PENDING': 'En attente', 'CONFIRMED': 'Confirmé', 'SHIPPED': 'Expédié', 'DELIVERED': 'Livré', 'CANCELLED': 'Annulé'};
    final entries = data.entries.where((e) => (e.value as num) > 0).toList();
    if (entries.isEmpty) return const Center(child: Text('Aucune donnée'));

    return PieChart(
      PieChartData(
        sections: entries.asMap().entries.map((e) => PieChartSectionData(
          value: (e.value.value as num).toDouble(),
          title: statusLabels[e.value.key] ?? e.value.key,
          color: colors[e.key % colors.length],
          titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
          radius: 40,
        )).toList(),
        centerSpaceRadius: 20,
      ),
    );
  }

  Widget _buildTrafficPieChart(Map<String, dynamic> data) {
    final colors = [AppColors.primary, const Color(0xFF1877F2), const Color(0xFFE4405F), AppColors.warning];
    final entries = data.entries.where((e) => (e.value as num) > 0).toList();
    if (entries.isEmpty) return const Center(child: Text('Aucune donnée'));

    return PieChart(
      PieChartData(
        sections: entries.asMap().entries.map((e) => PieChartSectionData(
          value: (e.value.value as num).toDouble(),
          title: e.value.key,
          color: colors[e.key % colors.length],
          titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
          radius: 40,
        )).toList(),
        centerSpaceRadius: 20,
      ),
    );
  }
}
