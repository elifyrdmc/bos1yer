part of '../main.dart';

class _AvailabilityDrawer extends StatelessWidget {
  const _AvailabilityDrawer({
    required this.isExpanded,
    required this.isLiveMode,
    required this.elapsed,
    required this.subtitle,
    required this.onTap,
    required this.onHelp,
    required this.pins,
    required this.onPinSelected,
  });
  final bool isExpanded;
  final bool isLiveMode;
  final Duration elapsed;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onHelp;
  final List<_DemoMapPin> pins;
  final ValueChanged<_DemoMapPin> onPinSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final countLabel = !isLiveMode
        ? 'örnek bildirim'
        : pins.isNotEmpty && pins.every((pin) => pin.isLiveReport)
        ? 'anlık bildirim'
        : 'bildirim';
    final vacancyCount = pins
        .where((pin) => pin.kind == _DemoPinKind.vacancy)
        .length;
    final leavingCount = pins
        .where((pin) => pin.kind == _DemoPinKind.leaving)
        .length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: isExpanded ? 338 : (pins.isEmpty ? 104 : 150),
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  pins.length.toString(),
                  style: TextStyle(
                    color: colors.secondary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    countLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Harita işaretleri',
                  onPressed: onHelp,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  icon: const Icon(Icons.help_outline_rounded, size: 19),
                  color: colors.onSurfaceVariant,
                ),
                Text(
                  isExpanded ? 'Kapat' : 'Listeyi aç',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (!isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 1),
              child: Text(
                pins.isEmpty ? subtitle : 'Yakındaki yerler · $subtitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ),
          if (!isExpanded && pins.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (vacancyCount > 0) ...[
                    Icon(
                      _DemoPinKind.vacancy.icon,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Boş yer · $vacancyCount',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (vacancyCount > 0 && leavingCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: 1,
                        height: 20,
                        color: colors.outlineVariant,
                      ),
                    ),
                  if (leavingCount > 0) ...[
                    Icon(
                      _DemoPinKind.leaving.icon,
                      size: 16,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Çıkıyorum · $leavingCount',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (isExpanded) ...[
            const SizedBox(height: 10),
            Expanded(
              child: pins.isEmpty
                  ? Center(
                      child: Text(
                        'Bu yakınlıkta gösterilecek bildirim yok.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: pins.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: colors.outlineVariant),
                      itemBuilder: (context, i) => Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 3,
                          ),
                          onTap: () => onPinSelected(pins[i]),
                          leading: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pins[i].mapColor(context, elapsed),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pins[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (pins[i].isOwnReport) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Senin bildirimin',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pins[i].kind == _DemoPinKind.leaving &&
                                        pins[i].remainingDepartureEstimate(
                                              elapsed,
                                            ) !=
                                            Duration.zero
                                    ? '${pins[i].remainingDepartureEstimate(elapsed).inMinutes} dk sonra çıkacak · ${_publishedAgeLabel(pins[i].reportAge(elapsed))}'
                                    : pins[i].isLiveReport
                                    ? _publishedAgeLabel(
                                        pins[i].reportAge(elapsed),
                                      )
                                    : pins[i].isLocalDemo
                                    ? 'Bu oturumda paylaşıldı'
                                    : 'Örnek bildirim',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _MapInfoChip(
                                    label: _pinStatusLabel(pins[i], elapsed),
                                    color: _pinStatusColor(
                                      context,
                                      pins[i],
                                      elapsed,
                                    ),
                                  ),
                                  if (pins[i].isLiveReport)
                                    _MapInfoChip(
                                      label: _pinTrustLabel(pins[i]),
                                      color: _authorTrustColor(
                                        context,
                                        pins[i].authorTrustScore,
                                        pins[i].authorTrustOutcomeCount,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: _mapMuted,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapInfoChip extends StatelessWidget {
  const _MapInfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _pinStatusLabel(_DemoMapPin pin, Duration elapsed) {
  if (pin.awaitsLeavingPhoto) return 'Fotoğraf bekleniyor';
  if (pin.kind == _DemoPinKind.leaving &&
      pin.remainingDepartureEstimate(elapsed) > Duration.zero) {
    return 'Çıkış bekleniyor';
  }
  if (pin.isStale(elapsed)) return 'Güncelliği azaldı';
  return 'Aktif';
}

Color _pinStatusColor(BuildContext context, _DemoMapPin pin, Duration elapsed) {
  final colors = Theme.of(context).colorScheme;
  if (pin.awaitsLeavingPhoto || pin.isStale(elapsed)) return colors.tertiary;
  if (pin.kind == _DemoPinKind.leaving &&
      pin.remainingDepartureEstimate(elapsed) > Duration.zero) {
    return _mapGold;
  }
  return colors.primary;
}

String _pinTrustLabel(_DemoMapPin pin) {
  final formatted = visibleTrustScore(
    pin.authorTrustScore,
    pin.authorTrustOutcomeCount,
  );
  return formatted == null ? 'Güven hesaplanıyor' : 'Güven $formatted';
}

Color _authorTrustColor(
  BuildContext context,
  double? score,
  int? outcomeCount,
) {
  final colors = Theme.of(context).colorScheme;
  if (visibleTrustScore(score, outcomeCount) == null) {
    return colors.onSurfaceVariant;
  }
  if (score! < 3) return colors.error;
  if (score < 4) {
    return Theme.of(context).brightness == Brightness.dark
        ? ParkIstPalette.darkReview
        : const Color(0xFF8C5F1E);
  }
  return colors.primary;
}

class _SelectedMapCard extends StatelessWidget {
  const _SelectedMapCard({
    required this.pin,
    required this.isUnavailable,
    required this.locationName,
    required this.point,
    required this.elapsed,
    required this.onClose,
    required this.onTap,
  });
  final _DemoMapPin? pin;
  final bool isUnavailable;
  final String? locationName;
  final LatLng point;
  final Duration elapsed;
  final VoidCallback onClose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedPin = pin;
    final colors = Theme.of(context).colorScheme;
    final leaving = selectedPin?.kind == _DemoPinKind.leaving;
    final expired =
        isUnavailable ||
        (selectedPin != null &&
            selectedPin.reportAge(elapsed) >= selectedPin.expirationAge);
    final departureWaiting =
        !expired &&
        leaving &&
        selectedPin!.remainingDepartureEstimate(elapsed) != Duration.zero;
    final statusColor = expired
        ? colors.onSurfaceVariant
        : selectedPin?.mapColor(context, elapsed) ?? colors.onSurfaceVariant;
    final status = expired
        ? 'Aktif değil'
        : departureWaiting
        ? 'Çıkış bekleniyor'
        : selectedPin?.isStale(elapsed) == true
        ? 'Güncelliği azaldı'
        : 'Aktif';
    final trustLabel = selectedPin == null
        ? null
        : !selectedPin.isLiveReport
        ? 'Örnek bildirim'
        : visibleTrustScore(
                selectedPin.authorTrustScore,
                selectedPin.authorTrustOutcomeCount,
              ) ??
              'hesaplanıyor';
    final trustColor = selectedPin == null || !selectedPin.isLiveReport
        ? colors.onSurfaceVariant
        : _authorTrustColor(
            context,
            selectedPin.authorTrustScore,
            selectedPin.authorTrustOutcomeCount,
          );
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(ParkDesign.radius),
      elevation: 5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ParkDesign.radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedPin?.label ?? locationName ?? 'Park yeri',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kartı kapat',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              if (selectedPin != null) ...[
                const SizedBox(height: 3),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _MapStatusChip(
                      icon: Icons.circle,
                      label: status,
                      color: statusColor,
                    ),
                    _MapStatusChip(
                      icon: Icons.schedule_outlined,
                      label: _publishedAgeLabel(selectedPin.reportAge(elapsed)),
                      color: colors.onSurfaceVariant,
                    ),
                    if (selectedPin.isOwnReport)
                      _MapStatusChip(
                        icon: Icons.person_outline,
                        label: 'Senin bildirimin',
                        color: colors.primary,
                      ),
                    if (trustLabel != null)
                      _MapStatusChip(
                        icon: Icons.verified_user_outlined,
                        label: 'Güven: $trustLabel',
                        color: trustColor,
                      ),
                  ],
                ),
                if (departureWaiting) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Yaklaşık ${selectedPin.remainingDepartureEstimate(elapsed).inMinutes} dk içinde çıkacak',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.near_me_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    'Detaylar',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapStatusChip extends StatelessWidget {
  const _MapStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ReportAuthorTrustCard extends StatelessWidget {
  const _ReportAuthorTrustCard({
    required this.isLiveReport,
    this.score,
    this.outcomeCount,
  });

  final bool isLiveReport;
  final double? score;
  final int? outcomeCount;

  String get _scoreLabel {
    if (!isLiveReport) return 'Demo verisi yok';
    return visibleTrustScore(score, outcomeCount) ?? 'Güven hesaplanıyor';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scoreColor = isLiveReport
        ? _authorTrustColor(context, score, outcomeCount)
        : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: scoreColor, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bildirim sahibinin güveni',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _scoreLabel,
              style: TextStyle(
                color: scoreColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
