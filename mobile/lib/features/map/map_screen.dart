import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/civic_ui.dart';
import '../../data/models.dart';
import '../complaints/complaint_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _bangalore = LatLng(12.9716, 77.5946);

  String? _priority;
  bool _showHotspots = false;

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsProvider(30));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Live complaint map'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showHotspots = !_showHotspots),
            icon: Icon(
              _showHotspots
                  ? Icons.local_fire_department_rounded
                  : Icons.local_fire_department_outlined,
              size: 18,
            ),
            label: Text(_showHotspots ? 'Hotspots on' : 'Hotspots'),
            style: TextButton.styleFrom(
              foregroundColor:
                  _showHotspots ? AppColors.danger : AppColors.ink2,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: analytics.when(
        loading: () => const LoadingPane(),
        error: (error, _) => ListView(
          children: [
            ErrorPane(
              message: error.toString(),
              onRetry: () => ref.invalidate(analyticsProvider),
            ),
          ],
        ),
        data: (data) {
          final points = _priority == null
              ? data.mapPoints
              : data.mapPoints.where((p) => p.priority == _priority).toList();
          return Column(
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _PriorityChip(
                      label: 'All priorities',
                      selected: _priority == null,
                      color: AppColors.primary,
                      onTap: () => setState(() => _priority = null),
                    ),
                    for (final entry in const {
                      'critical': AppColors.danger,
                      'high': Color(0xFFB45309),
                      'medium': AppColors.warn,
                      'low': AppColors.ink3,
                    }.entries)
                      _PriorityChip(
                        label: kPriorityLabels[entry.key] ?? entry.key,
                        selected: _priority == entry.key,
                        color: entry.value,
                        onTap: () => setState(() => _priority =
                            _priority == entry.key ? null : entry.key),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: _bangalore,
                          initialZoom: 11.4,
                          minZoom: 10,
                          maxZoom: 18,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.civicai.mobile',
                          ),
                          if (_showHotspots) _HotspotLayer(),
                          MarkerLayer(
                            markers: [
                              for (final point in points)
                                Marker(
                                  point: LatLng(point.latitude, point.longitude),
                                  width: 30,
                                  height: 30,
                                  child: _MapMarker(
                                    priority: point.priority,
                                    onTap: () =>
                                        _openPoint(context, point),
                                  ),
                                ),
                            ],
                          ),
                          const RichAttributionWidget(
                            alignment: AttributionAlignment.bottomLeft,
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        left: 14,
                        right: 88,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: AppColors.line),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x140B1714),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${points.length} geotagged case${points.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              Text(
                                'Tap a pin',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showHotspots)
                        const Positioned(
                          left: 14,
                          top: 14,
                          child: _HotspotLegend(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPoint(BuildContext context, MapPoint point) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    point.number,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink3,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                StatusPill(point.status, compact: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              point.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PriorityPill(point.priority, compact: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${point.ward} · ${point.category}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ComplaintDetailScreen(complaintId: point.id),
                    ),
                  );
                },
                child: const Text('Open complaint'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.priority, required this.onTap});

  final String priority;
  final VoidCallback onTap;

  static const _colors = {
    'critical': AppColors.danger,
    'high': Color(0xFFB45309),
    'medium': AppColors.warn,
    'low': AppColors.ink3,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _colors[priority] ?? AppColors.ink3,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.circle, size: 5, color: Colors.white),
      ),
    );
  }
}

class _HotspotLayer extends ConsumerWidget {
  const _HotspotLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(hotspotsProvider).valueOrNull;
    if (feed == null || feed.hotspots.isEmpty) {
      return const SizedBox.shrink();
    }
    return CircleLayer(
      circles: [
        for (final hotspot in feed.hotspots)
          CircleMarker(
            point: LatLng(hotspot.latitude, hotspot.longitude),
            radius: hotspot.radiusMeters,
            useRadiusInMeter: true,
            color: AppColors.danger.withValues(alpha: 0.14),
            borderColor: AppColors.danger.withValues(alpha: 0.55),
            borderStrokeWidth: 1.6,
          ),
      ],
    );
  }
}

class _HotspotLegend extends StatelessWidget {
  const _HotspotLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 15, color: AppColors.danger),
          SizedBox(width: 5),
          Text(
            'AI recurrence clusters',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.10) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color:
                  selected ? color.withValues(alpha: 0.35) : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? color : AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}
