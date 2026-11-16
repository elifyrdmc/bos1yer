part of '../main.dart';

class _VehicleLocationPickerDialog extends StatefulWidget {
  const _VehicleLocationPickerDialog({
    required this.currentLocation,
    required this.initialSelection,
    required this.maxDistanceMeters,
  });

  final LatLng currentLocation;
  final LatLng initialSelection;
  final double maxDistanceMeters;

  @override
  State<_VehicleLocationPickerDialog> createState() =>
      _VehicleLocationPickerDialogState();
}

class _VehicleLocationPickerDialogState
    extends State<_VehicleLocationPickerDialog> {
  late LatLng _selection = widget.initialSelection;

  double get _distanceMeters =>
      const Distance().as(LengthUnit.Meter, widget.currentLocation, _selection);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final withinRange = _distanceMeters <= widget.maxDistanceMeters;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aracın konumunu seç',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _selection,
                      initialZoom: 17,
                      minZoom: 5,
                      maxZoom: 19,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (_, point) => setState(() => _selection = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.parkist',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.currentLocation,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: ParkIstPalette.cornflower,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x44000000),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Marker(
                            point: _selection,
                            width: 42,
                            height: 42,
                            // flutter_map anchors the opposite edge: topCenter
                            // puts the icon tip on the tapped coordinate.
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on,
                              color: colors.primary,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: SimpleAttributionWidget(
                          source: Text('© OpenStreetMap'),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Material(
                      color: colors.surface.withValues(alpha: .95),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Haritada aracının bulunduğu noktaya dokun.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'GPS konumundan ${_distanceMeters.round()} m · sınır ${widget.maxDistanceMeters.round()} m',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: withinRange
                          ? colors.onSurfaceVariant
                          : colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: withinRange
                        ? () => Navigator.of(context).pop(_selection)
                        : null,
                    child: const Text('Bu konumu kullan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
