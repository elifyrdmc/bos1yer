part of '../main.dart';

class _IstanbulMap extends StatefulWidget {
  const _IstanbulMap({
    super.key,
    this.onPointSelected,
    this.onDemoPinSelected,
    this.selectedPoint,
    this.searchCenter,
    this.userPosition,
    this.onUserPositionTap,
    this.cameraRequestId = 0,
    this.cameraTargetZoom = 16,
    this.demoPins = const [],
    required this.activeDemoFilters,
    this.demoElapsed = Duration.zero,
    this.highlightedReportId,
    this.highlightedDistrict,
    this.hasSearchOverlay = false,
    this.onVisibleBoundsChanged,
  });

  final ValueChanged<({LatLng point, Offset position})>? onPointSelected;
  final ValueChanged<({_DemoMapPin pin, Offset position})>? onDemoPinSelected;
  final LatLng? selectedPoint;
  final LatLng? searchCenter;
  final Position? userPosition;
  final VoidCallback? onUserPositionTap;
  final int cameraRequestId;
  final double cameraTargetZoom;
  final List<_DemoMapPin> demoPins;
  final ValueListenable<Set<_DemoPinKind>> activeDemoFilters;
  final Duration demoElapsed;
  final String? highlightedReportId;
  final String? highlightedDistrict;
  final bool hasSearchOverlay;
  final void Function(LatLngBounds bounds, bool hasGesture)?
  onVisibleBoundsChanged;

  @override
  State<_IstanbulMap> createState() => _IstanbulMapState();
}

class _IstanbulMapState extends State<_IstanbulMap>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _cameraAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..addListener(_updateAnimatedCamera);
  LatLng? _cameraStart;
  LatLng? _cameraTarget;
  double _cameraStartZoom = 12;
  double _cameraAnimationTargetZoom = 12;
  Map<String, DistrictBoundary> _districtBoundaries = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadDistrictBoundaries());
  }

  Future<void> _loadDistrictBoundaries() async {
    try {
      final boundaries = await IstanbulDistrictBoundaryStore.load();
      if (mounted) setState(() => _districtBoundaries = boundaries);
    } catch (_) {
      // Keep map interactions available if the optional outline asset fails.
    }
  }

  void _updateAnimatedCamera() {
    final start = _cameraStart;
    final target = _cameraTarget;
    if (start == null || target == null) return;
    final progress = Curves.easeInOutCubic.transform(_cameraAnimation.value);
    _mapController.move(
      LatLng(
        start.latitude + (target.latitude - start.latitude) * progress,
        start.longitude + (target.longitude - start.longitude) * progress,
      ),
      _cameraStartZoom +
          (_cameraAnimationTargetZoom - _cameraStartZoom) * progress,
    );
  }

  void _animateTo(LatLng target, {double? targetZoom}) {
    _cameraAnimation.stop();
    _cameraStart = _mapController.camera.center;
    _cameraStartZoom = _mapController.camera.zoom;
    _cameraAnimationTargetZoom = targetZoom ?? widget.cameraTargetZoom;
    _cameraTarget = target;
    _cameraAnimation.forward(from: 0);
  }

  void zoomBy(double delta) {
    try {
      final camera = _mapController.camera;
      final targetZoom = (camera.zoom + delta).clamp(5.0, 19.0).toDouble();
      _animateTo(camera.center, targetZoom: targetZoom);
    } catch (_) {
      // The map controller is not ready until the first frame has mounted.
    }
  }

  @override
  void didUpdateWidget(covariant _IstanbulMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final searchCenter = widget.searchCenter;
    if (searchCenter != null &&
        widget.cameraRequestId != oldWidget.cameraRequestId) {
      final requestId = widget.cameraRequestId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.cameraRequestId == requestId) {
          _animateTo(searchCenter);
        }
      });
    }
  }

  @override
  void dispose() {
    _cameraAnimation.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final attribution = SimpleAttributionWidget(
      source: const Text('© OpenStreetMap · İlçe sınırları: OCHA/HDX'),
      backgroundColor: colors.surface.withValues(alpha: .88),
    );
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            widget.searchCenter ??
            widget.selectedPoint ??
            const LatLng(41.0082, 28.9784),
        initialZoom: 12,
        minZoom: 5,
        maxZoom: 19,
        // Raster OSM tiles carry labels inside the image. Locking rotation
        // keeps those labels and the map pins upright until vector tiles are used.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: widget.onPointSelected == null
            ? null
            : (tapPosition, point) => widget.onPointSelected!((
                point: point,
                position:
                    tapPosition.relative ??
                    _mapController.camera.latLngToScreenOffset(point),
              )),
        onLongPress: widget.onPointSelected == null
            ? null
            : (tapPosition, point) => widget.onPointSelected!((
                point: point,
                position:
                    tapPosition.relative ??
                    _mapController.camera.latLngToScreenOffset(point),
              )),
        onMapReady: () => widget.onVisibleBoundsChanged?.call(
          _mapController.camera.visibleBounds,
          false,
        ),
        onPositionChanged: (camera, hasGesture) => widget.onVisibleBoundsChanged
            ?.call(camera.visibleBounds, hasGesture),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.parkist',
        ),
        if (widget.highlightedDistrict != null &&
            _districtBoundaries[widget.highlightedDistrict] != null)
          PolygonLayer(
            polygons: [
              for (final ring
                  in _districtBoundaries[widget.highlightedDistrict]!.rings)
                Polygon(
                  points: ring,
                  color: colors.primary.withValues(alpha: .055),
                  borderColor: colors.primary.withValues(alpha: .72),
                  borderStrokeWidth: 2.2,
                  disableHolesBorder: true,
                ),
            ],
          ),
        if (widget.demoPins.isNotEmpty)
          _ParkInformationLayer(
            pins: widget.demoPins,
            highlightedReportId: widget.highlightedReportId,
            activeFilters: widget.activeDemoFilters,
            elapsed: widget.demoElapsed,
            onPinSelected: widget.onDemoPinSelected,
          ),
        if (widget.userPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  widget.userPosition!.latitude,
                  widget.userPosition!.longitude,
                ),
                width: 32,
                height: 32,
                child: Tooltip(
                  message:
                      'Konumun · ±${widget.userPosition!.accuracy.round()} m',
                  child: GestureDetector(
                    onTap: widget.onUserPositionTap,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: ParkIstPalette.cornflower,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (widget.hasSearchOverlay)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 82, right: 8),
              child: FittedBox(fit: BoxFit.scaleDown, child: attribution),
            ),
          )
        else
          attribution,
      ],
    );
  }
}

// Read the camera inside a map child so zooming, panning and rotation rebuild
// the groups without rebuilding the search field or changing its state.
