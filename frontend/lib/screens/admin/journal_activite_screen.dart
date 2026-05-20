import 'package:flutter/material.dart';
import '../../services/csv_export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/journal_activite_provider.dart';
import '../../models/activity_log.dart';
import 'package:provider/provider.dart';

class JournalActiviteScreen extends StatefulWidget {
  const JournalActiviteScreen({super.key});
  @override
  State<JournalActiviteScreen> createState() => _JournalActiviteScreenState();
}

class _JournalActiviteScreenState extends State<JournalActiviteScreen> {
  JournalActiviteProvider? _provider;
  final _searchCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_provider == null) {
        final bp = context.read<BoutiqueProvider>();
        final p = JournalActiviteProvider();
        if (bp.currentBoutique != null) {
          p.init(bp.currentBoutique!.id);
        } else {
          p.initAdmin();
        }
        _provider = p;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _provider?.dispose();
    _searchCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<JournalActiviteProvider>(
        builder: (_, p, __) => Scaffold(
          appBar: AppBar(
            title: const Text('Journal d\'activité'),
            actions: [
              if (p.onlineCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                      ),
                      const SizedBox(width: 4),
                      Text('${p.onlineCount}', style: AppTypography.caption),
                    ],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => _exportLogs(p),
                tooltip: 'Exporter',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: p.refresh,
                tooltip: 'Actualiser',
              ),
            ],
          ),
          body: Column(
            children: [
              _searchBar(p),
              _filterRow(p),
              Expanded(child: _activityList(p)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar(JournalActiviteProvider p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur ou une activité...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); p.setSearch(''); },
                      )
                    : null,
              ),
              onChanged: (v) {
                p.setSearch(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _startDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Date début',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onTap: () => _pickDate((d) {
                _startDateCtrl.text = d;
                p.setDateRange(d, _endDateCtrl.text);
              }),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _endDateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Date fin',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onTap: () => _pickDate((d) {
                _endDateCtrl.text = d;
                p.setDateRange(_startDateCtrl.text, d);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow(JournalActiviteProvider p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Toutes', p.actionFilter == '', () => p.setActionFilter('')),
            _filterChip('Connexion', p.actionFilter == 'CONNEXION_CAISSE_REUSSIE', () => p.setActionFilter('CONNEXION_CAISSE_REUSSIE')),
            _filterChip('Échec', p.actionFilter == 'CONNEXION_CAISSE_ECHOUEE', () => p.setActionFilter('CONNEXION_CAISSE_ECHOUEE')),
            _filterChip('Déconnexion', p.actionFilter == 'DECONNEXION_CAISSE', () => p.setActionFilter('DECONNEXION_CAISSE')),
            _filterChip('Caisse', p.actionFilter == 'OUVERTURE_CAISSE', () => p.setActionFilter('OUVERTURE_CAISSE')),
            _filterChip('Commande', p.actionFilter == 'CREATION_COMMANDE', () => p.setActionFilter('CREATION_COMMANDE')),
            _filterChip('Annulation', p.actionFilter == 'ANNULATION_COMMANDE', () => p.setActionFilter('ANNULATION_COMMANDE')),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: AppColors.border),
            const SizedBox(width: 8),
            _filterChip('Tous statuts', p.statusFilter == '', () => p.setStatusFilter('')),
            _filterChip('Succès', p.statusFilter == 'SUCCESS', () => p.setStatusFilter('SUCCESS')),
            _filterChip('Échec', p.statusFilter == 'FAILED', () => p.setStatusFilter('FAILED')),
            _filterChip('Expiré', p.statusFilter == 'EXPIRED', () => p.setStatusFilter('EXPIRED')),
            if (p.searchQuery.isNotEmpty || p.actionFilter.isNotEmpty || p.statusFilter.isNotEmpty || p.startDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _startDateCtrl.clear();
                    _endDateCtrl.clear();
                    p.clearFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withAlpha(30),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text('Effacer filtres', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityList(JournalActiviteProvider p) {
    if (p.loading && p.activities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && p.activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(p.error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: p.refresh,
            ),
          ],
        ),
      );
    }
    if (p.activities.isEmpty) {
      return const Center(child: Text('Aucune activité enregistrée'));
    }
    return RefreshIndicator(
      onRefresh: () async { p.refresh(); },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: p.activities.length + (p.done ? 0 : 1),
        itemBuilder: (_, i) {
          if (i >= p.activities.length) {
            p.loadActivities();
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }
          return _activityItem(p.activities[i]);
        },
      ),
    );
  }

  Widget _activityItem(ActivityLog a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showActivityDetail(a),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _statusColor(a.status).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_actionIcon(a.action), color: _statusColor(a.status), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(a.userName, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      _statusBadge(a.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(a.actionLabel, style: AppTypography.caption.copyWith(fontSize: 12)),
                  if (a.details != null && a.details!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(a.details!, style: AppTypography.caption.copyWith(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (a.ipAddress != null)
                        _infoChip(Icons.language, a.ipAddress!),
                      if (a.deviceInfo != null)
                        _infoChip(Icons.devices, a.deviceInfo!.length > 30 ? '${a.deviceInfo!.substring(0, 30)}...' : a.deviceInfo!),
                    ],
                  ),
                ],
              ),
            ),
            if (a.createdAt != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDate(a.createdAt!), style: AppTypography.caption.copyWith(fontSize: 10)),
                  if (a.createdAt!.length >= 16)
                    Text(a.createdAt!.substring(11, 16), style: AppTypography.caption.copyWith(fontSize: 9, color: AppColors.textSecondary)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.textSecondary),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _statusColor(status).withAlpha(30),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 9, color: _statusColor(status)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SUCCESS': return AppColors.success;
      case 'FAILED': return AppColors.danger;
      case 'EXPIRED': return Colors.orange;
      default: return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'SUCCESS': return 'Succès';
      case 'FAILED': return 'Échec';
      case 'EXPIRED': return 'Expiré';
      default: return status;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'CONNEXION_CAISSE_REUSSIE': return Icons.login;
      case 'CONNEXION_CAISSE_ECHOUEE': return Icons.error_outline;
      case 'DECONNEXION_CAISSE': return Icons.logout;
      case 'OUVERTURE_CAISSE': return Icons.point_of_sale;
      case 'FERMETURE_CAISSE': return Icons.power_off;
      case 'CREATION_COMMANDE': return Icons.add_shopping_cart;
      case 'ANNULATION_COMMANDE': return Icons.cancel;
      case 'MODIFICATION_UTILISATEUR': return Icons.edit;
      case 'RESET_STATISTIQUES': return Icons.restart_alt;
      case 'SESSION_EXPIREE': return Icons.timer_off;
      case 'ORDER_STATUS_CHANGED': return Icons.update;
      default: return Icons.circle;
    }
  }

  void _showActivityDetail(ActivityLog a) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(_actionIcon(a.action), color: _statusColor(a.status), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.actionLabel, style: AppTypography.heading3),
                      _statusBadge(a.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Utilisateur', a.userName),
            if (a.ipAddress != null) _detailRow('Adresse IP', a.ipAddress!),
            if (a.deviceInfo != null) _detailRow('Appareil', a.deviceInfo!),
            if (a.createdAt != null) _detailRow('Date', _formatDate(a.createdAt!)),
            if (a.createdAt != null && a.createdAt!.length >= 16) _detailRow('Heure', a.createdAt!.substring(11, 16)),
            if (a.details != null && a.details!.isNotEmpty) _detailRow('Détails', a.details!),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: AppTypography.caption)),
          Expanded(child: Text(value, style: AppTypography.body2)),
        ],
      ),
    );
  }

  Future<void> _pickDate(void Function(String) onSelected) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      onSelected('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _exportLogs(JournalActiviteProvider p) async {
    final csv = await p.exportCsv();
    if (csv != null) {
      CsvExportService.download(csv, 'activites.csv');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(csv != null ? 'Export terminé (${csv.length} caractères)' : 'Erreur lors de l\'export'),
          backgroundColor: csv != null ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return iso.substring(0, 10);
    } catch (_) {
      return iso;
    }
  }
}
