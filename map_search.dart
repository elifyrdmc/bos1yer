part of '../main.dart';

class _LocationUnavailable implements Exception {
  const _LocationUnavailable(this.message);

  final String message;
}

class _PlaceSearchResult {
  const _PlaceSearchResult({required this.name, required this.point});

  final String name;
  final LatLng point;
}

/// Public Nominatim is used for explicit, one-shot prototype searches only.
class _NominatimSearch {
  // Use an Istanbul-wide ranking area instead of the current camera bounds.
  // Nominatim treats `viewbox` as a ranking bias because `bounded` is omitted.
  static const _istanbulViewbox = '27.80000,41.75000,30.05000,40.65000';
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6);
  static DateTime? _lastRequestAt;
  static final Map<String, (DateTime savedAt, List<_PlaceSearchResult> results)>
  _recentResults = {};

  static Future<List<_PlaceSearchResult>> search(String query) async {
    final searchQuery = _canonicalizeDistrictQuery(query.trim());
    final cacheKey = searchQuery.toLowerCase();
    final cached = _recentResults[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 5)) {
      return cached.$2;
    }

    final lastRequestAt = _lastRequestAt;
    if (lastRequestAt != null) {
      final wait =
          const Duration(seconds: 1) - DateTime.now().difference(lastRequestAt);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequestAt = DateTime.now();

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$searchQuery, Istanbul, Turkey',
      'format': 'jsonv2',
      'countrycodes': 'tr',
      'limit': '5',
      // Keep search independent of the visible map area so places on either
      // side of Istanbul can be found from the same query.
      'viewbox': _istanbulViewbox,
    });
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 6));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'ParkIst/0.1 (Flutter prototype)',
    );
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('Place search failed: ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];

    final results = decoded
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final latitude = double.tryParse(item['lat']?.toString() ?? '');
          final longitude = double.tryParse(item['lon']?.toString() ?? '');
          final name = item['display_name']?.toString() ?? '';
          if (latitude == null || longitude == null || name.isEmpty) {
            return null;
          }
          return _PlaceSearchResult(
            name: name,
            point: LatLng(latitude, longitude),
          );
        })
        .whereType<_PlaceSearchResult>()
        .toList();
    if (_recentResults.length >= 24) {
      _recentResults.remove(_recentResults.keys.first);
    }
    _recentResults[cacheKey] = (DateTime.now(), results);
    return results;
  }

  static String _canonicalizeDistrictQuery(String query) {
    final normalized = _normalizeTurkish(query);
    for (final district in istanbulDistricts) {
      if (_normalizeTurkish(district.name) == normalized) {
        return district.name;
      }
    }
    return query;
  }

  static String _normalizeTurkish(String value) => value
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
}

/// Presents one-shot Nominatim results without owning the map camera state.
class _PlaceResultsSheet extends StatelessWidget {
  const _PlaceResultsSheet({required this.results});

  final List<_PlaceSearchResult> results;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: results.length + 2,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nereye gidelim?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${results.length} yer bulundu · haritada görmek için seç',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        if (index == results.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Arama: OpenStreetMap Nominatim · © OpenStreetMap contributors',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final result = results[index - 1];
        final colors = Theme.of(context).colorScheme;
        return Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).pop(result),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ParkIstPalette.cornflower.withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${result.point.latitude.toStringAsFixed(4)}, '
                          '${result.point.longitude.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.north_west_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
