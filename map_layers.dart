part of '../main.dart';

class _ParkInformationLayer extends StatelessWidget {
  const _ParkInformationLayer({
    required this.pins,
    required this.highlightedReportId,
    required this.activeFilters,
    required this.elapsed,
    required this.onPinSelected,
  });

  final List<_DemoMapPin> pins;
  final String? highlightedReportId;
  final ValueListenable<Set<_DemoPinKind>> activeFilters;
  final Duration elapsed;
  final ValueChanged<({_DemoMapPin pin, Offset position})>? onPinSelected;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return ValueListenableBuilder<Set<_DemoPinKind>>(
      valueListenable: activeFilters,
      builder: (context, filters, child) {
        if (pins.isEmpty) return const SizedBox.shrink();
        final visiblePins = pins
            .where(
              (pin) =>
                  filters.contains(pin.kind) &&
                  camera.visibleBounds.contains(pin.point),
            )
            .toList(growable: false);
        if (visiblePins.isEmpty) return const SizedBox.shrink();
        return MarkerLayer(
          rotate: true,
          markers: [
            for (final pin in visiblePins) _singleMarker(context, pin, camera),
          ],
        );
      },
    );
  }

  Marker _singleMarker(
    BuildContext context,
    _DemoMapPin pin,
    MapCamera camera,
  ) {
    final stale = pin.isStale(elapsed);
    final highlighted =
        highlightedReportId != null && _pinFocusKey(pin) == highlightedReportId;
    final pinColor = highlighted
        ? Theme.of(context).colorScheme.tertiary
        : pin.mapColor(context, elapsed);
    final pinAge = pin.mapAge(elapsed);
    const pinSize = 24.0;
    return Marker(
      point: pin.point,
      width: 46,
      height: 40,
      // The pin graphic sits at the bottom of its widget. Anchor that tip
      // to the coordinate, with the widget extending upward from the point.
      alignment: Alignment.topCenter,
      child: Tooltip(
        message: stale
            ? '${pin.isLiveReport ? 'Bildirim' : 'Örnek bildirim'}: ${pinAge.inMinutes} dk · güncelliği doğrulanmalı'
            : '${pin.isLiveReport ? 'Bildirim' : 'Örnek bildirim'}: ${pinAge.inMinutes} dk',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPinSelected == null
              ? null
              : () => onPinSelected!((
                  pin: pin,
                  position: camera.latLngToScreenOffset(pin.point),
                )),
          child: SizedBox(
            width: 46,
            height: 40,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: pinSize,
                  height: pinSize + 7,
                  child: CustomPaint(
                    key: highlighted
                        ? const ValueKey('focused-report-pin')
                        : null,
                    painter: _SolidMapPinPainter(pinColor),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: pin.kind == _DemoPinKind.vacancy
                      ? const Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        )
                      : Icon(
                          pin.kind.icon,
                          size: pinSize * .5,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 2),
                          ],
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: stale
                          ? ParkIstPalette.staleReport
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: stale ? Colors.white : pinColor,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        '${pinAge.inMinutes} dk',
                        style: TextStyle(
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: stale
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _pinFocusKey(_DemoMapPin pin) =>
    pin.reportId ?? 'local-${identityHashCode(pin)}';

class _SolidMapPinPainter extends CustomPainter {
  const _SolidMapPinPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    const inset = .6;
    final path = ui.Path()
      // A short rounded foot makes the marker feel softer than a sharp pin.
      ..moveTo(width * .43, height - inset - 1)
      ..cubicTo(
        width * .36,
        height * .76,
        width * .08,
        height * .52,
        width * .08,
        height * .34,
      )
      ..cubicTo(width * .08, height * .15, width * .27, inset, width / 2, inset)
      ..cubicTo(
        width * .73,
        inset,
        width * .92,
        height * .15,
        width * .92,
        height * .34,
      )
      ..cubicTo(
        width * .92,
        height * .52,
        width * .65,
        height * .76,
        width * .57,
        height - inset - 1,
      )
      ..quadraticBezierTo(
        width / 2,
        height - inset + .2,
        width * .43,
        height - inset - 1,
      )
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      )
      ..drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
  }

  @override
  bool shouldRepaint(_SolidMapPinPainter oldDelegate) =>
      oldDelegate.color != color;
}
