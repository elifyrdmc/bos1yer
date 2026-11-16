import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

Uri parkingDirectionsUrl(LatLng point) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.latitude},${point.longitude}',
      'travelmode': 'driving',
    });

Uri appleDirectionsUrl(LatLng point) => Uri.https('maps.apple.com', '/', {
  'daddr': '${point.latitude},${point.longitude}',
  'dirflg': 'd',
});

Uri yandexDirectionsUrl(LatLng point) => Uri.https('yandex.com', '/maps/', {
  'rtext': '~${point.latitude},${point.longitude}',
  'rtt': 'auto',
});

class ParkingDirectionsAction extends StatefulWidget {
  const ParkingDirectionsAction({
    super.key,
    required this.point,
    required this.isDemo,
  });

  final LatLng point;
  final bool isDemo;

  @override
  State<ParkingDirectionsAction> createState() =>
      _ParkingDirectionsActionState();
}

class _ParkingDirectionsActionState extends State<ParkingDirectionsAction> {
  bool _opening = false;

  Future<void> _openDirections(Uri selectedUrl) async {
    if (_opening) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await launchUrl(
        selectedUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Show a recoverable message for missing handlers or platform errors.
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Harita açılamadı. Tekrar deneyebilirsin.')),
    );
  }

  Future<void> _chooseDirectionsProvider() async {
    if (_opening) return;
    final isApplePlatform = Theme.of(context).platform == TargetPlatform.iOS;
    final selected = await showModalBottomSheet<_DirectionsProvider>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Harita uygulaması seç',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Google Haritalar'),
              onTap: () =>
                  Navigator.pop(sheetContext, _DirectionsProvider.google),
            ),
            if (isApplePlatform)
              ListTile(
                leading: const Icon(Icons.navigation_outlined),
                title: const Text('Apple Haritalar'),
                onTap: () =>
                    Navigator.pop(sheetContext, _DirectionsProvider.apple),
              ),
            ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text('Yandex Haritalar'),
              onTap: () =>
                  Navigator.pop(sheetContext, _DirectionsProvider.yandex),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final url = switch (selected) {
      _DirectionsProvider.google => parkingDirectionsUrl(widget.point),
      _DirectionsProvider.apple => appleDirectionsUrl(widget.point),
      _DirectionsProvider.yandex => yandexDirectionsUrl(widget.point),
    };
    await _openDirections(url);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _opening ? null : _chooseDirectionsProvider,
                icon: _opening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions_outlined),
                label: Text(_opening ? 'Harita açılıyor…' : 'Yol tarifi al'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

enum _DirectionsProvider { google, apple, yandex }
