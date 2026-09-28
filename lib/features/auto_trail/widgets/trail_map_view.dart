import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/trail_point.dart';

class TrailMapView extends StatefulWidget {
  final List<TrailPoint> points;
  final TrailPoint? selectedPoint;
  final ValueChanged<TrailPoint?> onPointSelected;
  final ValueChanged<TrailPoint> onOpenMaps;
  final ValueChanged<TrailPoint> onShare;

  const TrailMapView({
    super.key,
    required this.points,
    this.selectedPoint,
    required this.onPointSelected,
    required this.onOpenMaps,
    required this.onShare,
  });

  @override
  State<TrailMapView> createState() => _TrailMapViewState();
}

class _TrailMapViewState extends State<TrailMapView> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant TrailMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPoint != null &&
        widget.selectedPoint != oldWidget.selectedPoint) {
      _mapController.move(
        LatLng(widget.selectedPoint!.latitude, widget.selectedPoint!.longitude),
        15.5,
      );
    }
  }

  void _fitBounds() {
    if (widget.points.isEmpty) return;
    if (widget.points.length == 1) {
      _mapController.move(
        LatLng(widget.points.first.latitude, widget.points.first.longitude),
        15.0,
      );
      return;
    }

    double minLat = widget.points.first.latitude;
    double maxLat = widget.points.first.latitude;
    double minLng = widget.points.first.longitude;
    double maxLng = widget.points.first.longitude;

    for (final pt in widget.points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  void _centerLatest() {
    if (widget.points.isNotEmpty) {
      final latest = widget.points.first;
      _mapController.move(
        LatLng(latest.latitude, latest.longitude),
        16.0,
      );
      widget.onPointSelected(latest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Center map around first/latest point, or default to world center
    final initialCenter = widget.points.isNotEmpty
        ? LatLng(widget.points.first.latitude, widget.points.first.longitude)
        : const LatLng(25.2048, 55.2708); // fallback center

    // Chronological order for drawing polyline route
    final sortedPoints = List<TrailPoint>.from(widget.points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final polylinePoints =
        sortedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: widget.points.isNotEmpty ? 14.5 : 3.0,
            onTap: (tapPosition, point) {
              widget.onPointSelected(null);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.hasif.fdserver.fdserver',
            ),
            if (polylinePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    color: const Color(0xFF3B82F6),
                    strokeWidth: 4.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: widget.points.map((pt) {
                final isSelected = widget.selectedPoint?.id == pt.id;
                final isLatest = widget.points.first.id == pt.id;

                return Marker(
                  point: LatLng(pt.latitude, pt.longitude),
                  width: isSelected ? 48 : (isLatest ? 42 : 32),
                  height: isSelected ? 48 : (isLatest ? 42 : 32),
                  child: GestureDetector(
                    onTap: () {
                      widget.onPointSelected(pt);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEF4444)
                            : (isLatest
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6)),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isSelected
                            ? LucideIcons.mapPin
                            : (isLatest ? LucideIcons.navigation : LucideIcons.circle),
                        size: isSelected ? 22 : (isLatest ? 18 : 12),
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Map Control Floating Buttons (Fit Bounds, Center Latest, Zoom)
        PositionMatrixControl(
          onFitBounds: _fitBounds,
          onCenterLatest: _centerLatest,
          onZoomIn: () {
            _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom + 1,
            );
          },
          onZoomOut: () {
            _mapController.move(
              _mapController.camera.center,
              _mapController.camera.zoom - 1,
            );
          },
        ),

        // Selected Point Info Floating Card
        if (widget.selectedPoint != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _buildSelectedPointCard(
              context,
              widget.selectedPoint!,
              isDark,
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedPointCard(
    BuildContext context,
    TrailPoint point,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 16,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  point.address,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () => widget.onPointSelected(null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${point.coordsString} · ${point.dateTime.hour}:${point.dateTime.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ShadButton(
                  size: ShadButtonSize.sm,
                  onPressed: () => widget.onOpenMaps(point),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.externalLink, size: 14),
                      SizedBox(width: 6),
                      Text('Google Maps'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => widget.onShare(point),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.share2, size: 14),
                    SizedBox(width: 6),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PositionMatrixControl extends StatelessWidget {
  final VoidCallback onFitBounds;
  final VoidCallback onCenterLatest;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const PositionMatrixControl({
    super.key,
    required this.onFitBounds,
    required this.onCenterLatest,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildButton(IconData icon, String tooltip, VoidCallback onTap) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          onPressed: onTap,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
      );
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          buildButton(LucideIcons.maximize2, 'Fit trail bounds', onFitBounds),
          buildButton(LucideIcons.locateFixed, 'Center latest position', onCenterLatest),
          buildButton(LucideIcons.plus, 'Zoom in', onZoomIn),
          buildButton(LucideIcons.minus, 'Zoom out', onZoomOut),
        ],
      ),
    );
  }
}
