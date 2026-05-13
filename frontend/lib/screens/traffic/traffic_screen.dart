import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});
  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<dynamic> _visits = [];
  List<dynamic> _topCountries = [];
  List<dynamic> _topCities = [];
  bool _loading = false;
  String? _error;
  int _perPage = 10;
  final int _page = 0;

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
        _api.get('/boutiques/$bid/traffic/visits', queryParameters: {'page': _page, 'size': _perPage}),
        _api.get('/boutiques/$bid/traffic/top-countries'),
        _api.get('/boutiques/$bid/traffic/top-cities'),
      ]);
      _stats = results[0]['data'];
      _visits = (results[1]['data']['content'] as List);
      _topCountries = results[2]['data'] as List;
      _topCities = results[3]['data'] as List;
    } catch (e) { _error = 'Erreur de chargement'; }
    setState(() => _loading = false);
  }

  Future<void> _refresh() async => _load();

  Future<void> _exportCSV() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export CSV...')));
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    final s = d.toString();
    if (s.length >= 16) return s.substring(0, 16).replaceAll('T', ' ');
    return s;
  }

  void _openAnalytics() {
    Navigator.pushNamed(context, '/traffic/analytics');
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
            Text('Traffic du site – $boutiqueName'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    onPressed: _load,
                  ),
                ],
              ),
            )
          : ListView(
              children: [
                // Gradient top stats bar
                Container(
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
                      _trafficStat('Total Visites', '${_stats?['totalVisits'] ?? 0}'),
                      _trafficStat("Aujourd'hui", '${_stats?['todayVisits'] ?? 0}'),
                      _trafficStat('Cette Semaine', '${_stats?['weekVisits'] ?? 0}'),
                      _trafficStat('Ce Mois', '${_stats?['monthVisits'] ?? 0}'),
                    ],
                  ),
                ),
                // Quick link to full analytics
                Padding(
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
                ),
                // Map card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.language, color: AppColors.textPrimary, size: 18),
                            const SizedBox(width: 8),
                            Text('Analyse Géographique du Trafic',
                                style: AppTypography.heading3),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: _refresh,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Container(
                        height: 280,
                        color: const Color(0xFFF5F5F5),
                        child: const Center(
                          child: Icon(Icons.map_outlined, size: 64,
                              color: AppColors.border),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top Countries + Top Cities
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _GreenGradientCard(
                          icon: Icons.flag_outlined,
                          title: 'Top Pays',
                          badge: '${_topCountries.length} Pays',
                          items: _topCountries.map((e) => _GeoRow(
                            name: e['country']?.toString() ?? 'Inconnu',
                            count: (e['count'] as num).toInt(),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GreenGradientCard(
                          icon: Icons.location_city_outlined,
                          title: 'Top Villes',
                          badge: '${_topCities.length} Villes',
                          items: _topCities.map((e) => _GeoRow(
                            name: e['city']?.toString() ?? 'Inconnu',
                            subtitle: e['country']?.toString(),
                            count: (e['count'] as num).toInt(),
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Dernières Visites table
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people_outline, size: 18,
                                    color: AppColors.textPrimary),
                                const SizedBox(width: 8),
                                Text('Dernières Visites', style: AppTypography.heading3),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                DropdownButton<int>(
                                  value: _perPage,
                                  underline: const SizedBox(),
                                  items: [10, 25, 50].map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n Par page',
                                        style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _perPage = v);
                                      _load();
                                    }
                                  },
                                ),
                                SizedBox(
                                  height: 36,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.download, size: 14),
                                    label: const Text('Exporter'),
                                    onPressed: _exportCSV,
                                  ),
                                ),
                                SizedBox(
                                  height: 36,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Actualiser'),
                                    onPressed: _refresh,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                              AppColors.surfaceAlt),
                          columns: [
                            _col('IP Client'),
                            _col('Date/Heure'),
                            _col('Page'),
                            _col('Référent'),
                            _col('Navigateur'),
                            _col('Actions'),
                          ],
                          rows: _visits.map((v) => DataRow(cells: [
                            DataCell(Text(v['ipHash']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ))),
                            DataCell(Text(_formatDate(v['viewedAt']),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(v['page']?.toString() ?? '/',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(v['referrer']?.toString() ?? 'Direct',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(v['browser']?.toString() ?? 'Autre',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.location_on_outlined,
                                      size: 16),
                                  color: AppColors.textSecondary,
                                  onPressed: () {},
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline,
                                      size: 16),
                                  color: AppColors.textSecondary,
                                  onPressed: () {},
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            )),
                          ])).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  DataColumn _col(String label) => DataColumn(
    label: Text(label, style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
    )));

  Widget _trafficStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
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
}

class _GreenGradientCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;
  final List<_GeoRow> items;

  const _GreenGradientCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A7A4A), Color(0xFF2ECC71)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Center(
              child: Text('Aucune donnée',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
            )
          else
            ...items,
        ],
      ),
    );
  }
}

class _GeoRow extends StatelessWidget {
  final String name;
  final String? subtitle;
  final int count;

  const _GeoRow({
    required this.name,
    this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}