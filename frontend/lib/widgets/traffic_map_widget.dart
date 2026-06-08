import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/env_config.dart';
import '../models/traffic_stats.dart';
import '../theme/app_colors.dart';

class TrafficMapWidget extends StatelessWidget {
  final List<MapPoint> points;
  final bool loading;
  final String? error;
  final VoidCallback? onRefresh;

  const TrafficMapWidget({
    super.key,
    required this.points,
    this.loading = false,
    this.error,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.language, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analyse Géographique', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('${points.where((p) => p.latitude != null && p.longitude != null).length} localisations',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                if (onRefresh != null)
                  IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: onRefresh),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          SizedBox(height: 320, child: _buildMapContent(context)),
        ],
      ),
    );
  }

  static const _defaultLat = 35.8256;
  static const _defaultLng = 10.63699;
  static const _defaultZoom = 3.5;

  Widget _buildMapContent(BuildContext context) {
    final withCoords = points.where((p) => p.latitude != null && p.longitude != null).toList();
    final hasError = error != null;

    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: withCoords.isNotEmpty ? _center(withCoords) : const LatLng(_defaultLat, _defaultLng),
              initialZoom: withCoords.length == 1 ? 10.0 : _defaultZoom,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: EnvConfig.mapTileUrl,
                userAgentPackageName: 'io.makewebsite.app',
              ),
              if (withCoords.isNotEmpty)
                MarkerLayer(
                  markers: withCoords.map((p) => Marker(
                    point: LatLng(p.latitude!, p.longitude!),
                    width: 44, height: 44,
                    child: GestureDetector(
                      onTap: () => _showPopup(context, p),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.near_me, color: Colors.white, size: 16),
                          ),
                          if (p.totalVisits > 1)
                            Positioned(
                              right: -2, top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text('${p.totalVisits}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
            ],
          ),
          if (loading && withCoords.isEmpty)
            Positioned.fill(
              child: Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
            ),
          if (withCoords.isEmpty && !loading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 32, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(hasError ? error! : 'Aucune donnée réelle pour le moment',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                            textAlign: TextAlign.center),
                        if (hasError && onRefresh != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Réessayer'),
                            onPressed: onRefresh,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (withCoords.isNotEmpty)
            Positioned(
              right: 12, bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                ),
                child: Text('${withCoords.length} localisation(s)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  LatLng _center(List<MapPoint> withCoords) {
    final avgLat = withCoords.map((p) => p.latitude!).reduce((a, b) => a + b) / withCoords.length;
    final avgLng = withCoords.map((p) => p.longitude!).reduce((a, b) => a + b) / withCoords.length;
    return LatLng(avgLat, avgLng);
  }

  void _showPopup(BuildContext context, MapPoint point) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on, color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(point.city ?? point.country ?? 'Visiteur',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visits count highlighted
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Visites : ${point.totalVisits}',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (point.city != null) _detailRow('Ville', point.city!),
            if (point.country != null) _detailRow('Pays', point.country!),
            if (point.address != null) _detailRow('Adresse', point.address!),
            if (point.browser != null) _detailRow('Navigateur', point.browser!),
            if (point.deviceType != null) _detailRow('Appareil', point.deviceType!),
            if (point.operatingSystem != null) _detailRow('OS', point.operatingSystem!),
            if (point.lastActivityAt != null) _detailRow('Dernière activité', point.lastActivityAt!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
