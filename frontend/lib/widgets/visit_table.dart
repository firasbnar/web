import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';
import '../services/csv_export_service.dart';
import '../models/traffic_stats.dart';
import '../theme/app_colors.dart';

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
    return list
        .where((v) =>
            (v.ipHash?.toLowerCase().contains(q) ?? false) ||
            (v.page?.toLowerCase().contains(q) ?? false) ||
            (v.country?.toLowerCase().contains(q) ?? false) ||
            (v.city?.toLowerCase().contains(q) ?? false) ||
            (v.browser?.toLowerCase().contains(q) ?? false) ||
            (v.referrer?.toLowerCase().contains(q) ?? false))
        .toList();
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
      final response = await ApiClient().dio.get(
          '/traffic/${widget.boutiqueId}/export',
          options: Options(responseType: ResponseType.bytes));
      final csv = utf8.decode(response.data as List<int>);
      CsvExportService.download(csv, 'traffic_export.csv');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export terminé'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Erreur export: ${ApiClient.extractErrorMessage(e)}'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        );
      }
    }
  }

  String _formatDate(String? d) {
    if (d == null) return '-';
    if (d.length >= 16) return d.substring(0, 16).replaceAll('T', ' ');
    return d;
  }

  String _detectBrowser(String? userAgent) {
    if (userAgent == null) return 'Autre';
    final ua = userAgent.toLowerCase();
    if (ua.contains('edg')) return 'Edge';
    if (ua.contains('chrome')) return 'Chrome';
    if (ua.contains('firefox')) return 'Firefox';
    if (ua.contains('safari')) return 'Safari';
    if (ua.contains('opera') || ua.contains('opr')) return 'Opera';
    return 'Autre';
  }

  String _browserBadgeColor(String? browser) {
    switch (browser?.toLowerCase()) {
      case 'chrome':
        return '#4285F4';
      case 'firefox':
        return '#FF7139';
      case 'safari':
        return '#006CFF';
      case 'edge':
        return '#0078D7';
      case 'opera':
        return '#FF1B2D';
      default:
        return '#9B97B8';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVisits;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.people_outline,
                          size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dernières Visites',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        if (widget.pageInfo != null)
                          Text(
                              '${widget.pageInfo!['totalElements'] ?? 0} visites au total',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    if (widget.loading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher par IP, page, pays, navigateur...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.textHint),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() => _searchQuery = ''))
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: widget.pageSize,
                          isDense: true,
                          items: [10, 25, 50]
                              .map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textPrimary)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) widget.onPageSizeChanged?.call(v);
                          },
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 150),
                      child: _toolbarButton(
                        icon: Icons.download,
                        label: 'common.export'.tr(),
                        onPressed: _exportCsv,
                        outlined: true,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 130),
                      child: _toolbarButton(
                        icon: Icons.refresh,
                        label: 'common.refresh'.tr(),
                        onPressed: widget.onRefresh,
                        outlined: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline,
                          size: 28, color: AppColors.danger),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.error ?? '',
                        style: GoogleFonts.inter(
                            color: AppColors.danger, fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inbox_outlined,
                          size: 32, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('Aucune visite trouvée',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Les visites apparaîtront ici une fois enregistrées.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 52,
                horizontalMargin: 20,
                columnSpacing: 24,
                showCheckboxColumn: false,
                sortColumnIndex: _columnIndex(_sortColumn),
                sortAscending: _sortAscending,
                columns: [
                  _sortCol('Visiteur', 'ipHash'),
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
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                          ip != null && ip.length > 12
                              ? '${ip.substring(0, 12)}\u2026'
                              : ip ?? '',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary)),
                    )),
                    DataCell(Text(_formatDate(v.viewedAt),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textPrimary))),
                    DataCell(Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(v.page ?? '/',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(_buildReferrerBadge(v.referrer)),
                    DataCell(_buildBrowserBadge(v.browser, v.userAgent)),
                    DataCell(Text(v.country ?? 'Local',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textPrimary))),
                    DataCell(Text(v.city ?? 'Local',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textPrimary))),
                  ]);
                }).toList(),
              ),
            ),
          if (widget.pageInfo != null) ..._buildPagination(widget.pageInfo!),
        ],
      ),
    );
  }

  Widget _buildBrowserBadge(String? browser, String? userAgent) {
    final b = browser ?? _detectBrowser(userAgent);
    final colorHex = _browserBadgeColor(b);
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(b,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _buildReferrerBadge(String? referrer) {
    final r = (referrer == null || referrer.isEmpty) ? 'Direct' : referrer;
    final isDirect = r == 'Direct';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDirect
            ? AppColors.primarySurface
            : AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      constraints: const BoxConstraints(maxWidth: 120),
      child: Text(r,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDirect ? AppColors.primary : AppColors.success,
          ),
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _toolbarButton(
      {required IconData icon,
      required String label,
      VoidCallback? onPressed,
      bool outlined = false}) {
    if (outlined) {
      return OutlinedButton.icon(
        icon: Icon(icon, size: 14),
        label: Text(label,
            style:
                GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      );
    }
    return FilledButton.icon(
      icon: Icon(icon, size: 14),
      label: Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  List<Widget> _buildPagination(Map<String, dynamic> pageInfo) {
    final current = (pageInfo['currentPage'] as num?)?.toInt() ?? 0;
    final total = (pageInfo['totalPages'] as num?)?.toInt() ?? 1;
    final hasPrev = current > 0;
    final hasNext = current < total - 1;

    return [
      const Divider(height: 1, color: AppColors.border),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '${pageInfo['totalElements'] ?? 0} visites · Page ${current + 1} sur $total',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPrev)
                  _pageButton(Icons.chevron_left, 'Précédent',
                      () => widget.onPageChanged?.call(current - 1)),
                if (hasPrev && hasNext) const SizedBox(width: 8),
                if (hasNext)
                  _pageButton(Icons.chevron_right, 'Suivant',
                      () => widget.onPageChanged?.call(current + 1)),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _pageButton(IconData icon, String label, VoidCallback? onPressed) {
    return FilledButton.icon(
      icon: Icon(icon, size: 14),
      label: Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  int? _columnIndex(String col) {
    switch (col) {
      case 'ipHash':
        return 0;
      case 'viewedAt':
        return 1;
      case 'page':
        return 2;
      case 'referrer':
        return 3;
      case 'browser':
        return 4;
      case 'country':
        return 5;
      case 'city':
        return 6;
      default:
        return null;
    }
  }

  DataColumn _sortCol(String label, String column) {
    return DataColumn(
      label: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.3)),
      onSort: (_, __) => _sort(column),
    );
  }
}
