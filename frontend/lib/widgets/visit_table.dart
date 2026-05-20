import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../services/csv_export_service.dart';
import '../models/traffic_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class VisitTable extends StatefulWidget {
  final List<RecentVisit> visits;
  final Map<String, dynamic>? pageInfo;
  final bool loading;
  final String? error;
  final String? boutiqueId;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final VoidCallback? onRefresh;
  final int currentPage;
  final int pageSize;

  const VisitTable({
    super.key,
    required this.visits,
    this.pageInfo,
    this.loading = false,
    this.error,
    this.boutiqueId,
    this.onPageChanged,
    this.onPageSizeChanged,
    this.onRefresh,
    this.currentPage = 0,
    this.pageSize = 10,
  });

  @override
  State<VisitTable> createState() => _VisitTableState();
}

class _VisitTableState extends State<VisitTable> {
  String _searchQuery = '';
  String _sortColumn = 'viewedAt';
  bool _sortAscending = false;

  List<RecentVisit> get _filteredVisits {
    final list = widget.visits;
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((v) =>
        (v.ipHash?.toLowerCase().contains(q) ?? false) ||
        (v.page?.toLowerCase().contains(q) ?? false) ||
        (v.country?.toLowerCase().contains(q) ?? false) ||
        (v.city?.toLowerCase().contains(q) ?? false) ||
        (v.browser?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  void _sort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  Future<void> _exportCsv() async {
    if (widget.boutiqueId == null) return;
    try {
      final response = await ApiClient().dio.get('/traffic/${widget.boutiqueId}/export',
          options: Options(responseType: ResponseType.bytes));
      final csv = utf8.decode(response.data as List<int>);
      CsvExportService.download(csv, 'traffic_export.csv');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export terminé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export: ${ApiClient.extractErrorMessage(e)}')),
        );
      }
    }
  }

  String _formatDate(String? d) {
    if (d == null) return '-';
    if (d.length >= 16) return d.substring(0, 16).replaceAll('T', ' ');
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVisits;
    return Card(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 18, color: AppColors.textPrimary),
                        const SizedBox(width: 8),
                        Text('Dernières Visites', style: AppTypography.heading3),
                      ],
                    ),
                    if (widget.loading)
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher par IP, page, pays...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<int>(
                      value: widget.pageSize,
                      underline: const SizedBox(),
                      items: [10, 25, 50].map((n) => DropdownMenuItem(
                        value: n,
                        child: Text('$n Par page', style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (v) { if (v != null) widget.onPageSizeChanged?.call(v); },
                    ),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Exporter CSV'),
                        onPressed: _exportCsv,
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Actualiser'),
                        onPressed: widget.onRefresh,
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
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
                    const SizedBox(height: 8),
                    Text(widget.error ?? '', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: AppColors.border),
                    SizedBox(height: 8),
                    Text('Aucune visite trouvée',
                        style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                sortColumnIndex: _columnIndex(_sortColumn),
                sortAscending: _sortAscending,
                columns: [
                  _sortCol('IP', 'ipHash'),
                  _sortCol('Date/Heure', 'viewedAt'),
                  _sortCol('Page', 'page'),
                  _sortCol('Référent', 'referrer'),
                  _sortCol('Navigateur', 'browser'),
                  _sortCol('Pays', 'country'),
                  _sortCol('Ville', 'city'),
                ],
                rows: filtered.map((v) {
                  final ip = v.ipHash;
                  return DataRow(cells: [
                  DataCell(Text(ip != null && ip.length > 12
                      ? '${ip.substring(0, 12)}\u2026'
                      : ip ?? '',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.primary))),
                  DataCell(Text(_formatDate(v.viewedAt), style: const TextStyle(fontSize: 12))),
                  DataCell(Text(v.page ?? '/', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(v.referrer ?? 'Direct', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(v.browser ?? 'Autre', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(v.country ?? '-', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(v.city ?? '-', style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
          if (widget.pageInfo != null) ..._buildPagination(widget.pageInfo!),
        ],
      ),
    );
  }

  List<Widget> _buildPagination(Map<String, dynamic> pageInfo) {
    final current = (pageInfo['currentPage'] as num?)?.toInt() ?? 0;
    final total = (pageInfo['totalPages'] as num?)?.toInt() ?? 1;
    final hasPrev = current > 0;
    final hasNext = current < total - 1;

    return [
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${current + 1} / $total',
              style: AppTypography.caption,
            ),
            Text(
              '${pageInfo['totalElements'] ?? 0} visites',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
      if (hasPrev || hasNext)
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
          child: Row(
            mainAxisAlignment: !hasPrev
                ? MainAxisAlignment.end
                : !hasNext
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceBetween,
            children: [
              if (hasPrev)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200, minHeight: 36),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Précédent'),
                    onPressed: () => widget.onPageChanged?.call(current - 1),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ),
              if (hasNext)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200, minHeight: 36),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Suivant'),
                    onPressed: () => widget.onPageChanged?.call(current + 1),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  int? _columnIndex(String col) {
    switch (col) {
      case 'ipHash': return 0;
      case 'viewedAt': return 1;
      case 'page': return 2;
      case 'referrer': return 3;
      case 'browser': return 4;
      case 'country': return 5;
      case 'city': return 6;
      default: return null;
    }
  }

  DataColumn _sortCol(String label, String column) {
    return DataColumn(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      onSort: (_, __) => _sort(column),
    );
  }
}
