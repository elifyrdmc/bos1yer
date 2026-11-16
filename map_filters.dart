part of '../main.dart';

/// Owns draft filter choices until the user applies them to the map.
void _showMapFiltersSheet({
  required BuildContext context,
  required Set<_DemoPinKind> selectedFilters,
  required String selectedDistrict,
  required Future<String?> Function(String) chooseDistrict,
  required Future<void> Function(String) focusDistrict,
  required void Function(Set<_DemoPinKind>) applyFilters,
}) {
  final draftFilters = Set<_DemoPinKind>.from(selectedFilters);
  var draftDistrict = selectedDistrict;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ParkIstPalette.cornflower.withValues(alpha: .16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtreler',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Haritada görmek istediklerini seç',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ParkIstPalette.cornflower.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${draftFilters.length}/${_DemoPinKind.values.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final kind in _DemoPinKind.values)
                        SizedBox(
                          width: (constraints.maxWidth - 10) / 2,
                          child: _MapFilterTile(
                            kind: kind,
                            selected: draftFilters.contains(kind),
                            onTap: () => setSheetState(() {
                              if (draftFilters.contains(kind)) {
                                draftFilters.remove(kind);
                              } else {
                                draftFilters.add(kind);
                              }
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  key: const ValueKey('district-filter'),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final chosenDistrict = await chooseDistrict(
                        draftDistrict,
                      );
                      if (chosenDistrict != null && sheetContext.mounted) {
                        setSheetState(() => draftDistrict = chosenDistrict);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city_outlined,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'İlçe',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  draftDistrict,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() {
                          draftFilters
                            ..clear()
                            ..addAll(_DemoPinKind.values);
                          draftDistrict = allIstanbulDistrictLabel;
                        }),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: const StadiumBorder(),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Filtreleri sıfırla'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          if (draftDistrict != selectedDistrict) {
                            await focusDistrict(draftDistrict);
                          }
                          applyFilters(Set.from(draftFilters));
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: const StadiumBorder(),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Sonuçları göster'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
