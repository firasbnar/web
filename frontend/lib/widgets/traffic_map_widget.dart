import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/traffic_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

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
    return Card(
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
                if (loading)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: onRefresh,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 300,
            child: _buildMapContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent(BuildContext context) {
    if (loading && points.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && points.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(error ?? '', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Réessayer'),
              onPressed: onRefresh,
            ),
          ],
        ),
      );
    }
    if (points.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: AppColors.border),
            SizedBox(height: 8),
            Text('Aucune donnée de localisation',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          ],
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 2.5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'io.makewebsite.app',
        ),
        MarkerLayer(
          markers: points.asMap().entries.map((entry) {
            final p = entry.value;
            if (p.latitude == null || p.longitude == null) {
              return const Marker(point: LatLng(0, 0), child: SizedBox());
            }
            return Marker(
              point: LatLng(p.latitude!, p.longitude!),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showPopup(context, p),
                child: const Icon(Icons.location_on, color: AppColors.danger, size: 28),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  LatLng get _center {
    if (points.isEmpty) return const LatLng(20, 0);
    final withCoords = points.where((p) => p.latitude != null && p.longitude != null).toList();
    if (withCoords.isEmpty) return const LatLng(20, 0);
    final avgLat = withCoords.map((p) => p.latitude!).reduce((a, b) => a + b) / withCoords.length;
    final avgLng = withCoords.map((p) => p.longitude!).reduce((a, b) => a + b) / withCoords.length;
    return LatLng(avgLat, avgLng);
  }

  void _showPopup(BuildContext context, MapPoint point) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(point.city ?? point.country ?? 'Visiteur',
                style: AppTypography.heading4),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (point.country != null) _detailRow('Pays', point.country!),
            if (point.city != null) _detailRow('Ville', point.city!),
            if (point.ipHash != null) _detailRow('IP', point.ipHash!),
            if (point.browser != null) _detailRow('Navigateur', point.browser!),
            if (point.deviceType != null) _detailRow('Appareil', point.deviceType!),
            if (point.operatingSystem != null) _detailRow('OS', point.operatingSystem!),
            _detailRow('Visites', '${point.totalVisits}'),
            if (point.lastActivityAt != null)
              _detailRow('Dernière activité', point.lastActivityAt!),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.body2.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
