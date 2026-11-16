part of '../main.dart';

enum _ExplorePlaceType { freeParking, needsReview, parkingFacility }

class _ExplorePlace {
  const _ExplorePlace({
    required this.name,
    required this.description,
    required this.type,
  });

  final String name;
  final String description;
  final _ExplorePlaceType type;
}

class _ExplorePage extends StatefulWidget {
  const _ExplorePage();

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  int _selectedFilter = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _filters = ['Tümü', 'Ücretsiz', 'Otopark'];
  static const _places = [
    _ExplorePlace(
      name: 'Sultanahmet çevresi',
      description: 'Sokak parkı bilgisi örneği',
      type: _ExplorePlaceType.freeParking,
    ),
    _ExplorePlace(
      name: 'Gülhane çevresi',
      description: 'Park bilgisi doğrulanmalı',
      type: _ExplorePlaceType.needsReview,
    ),
    _ExplorePlace(
      name: 'Örnek otopark',
      description: 'Ücretli otopark örneği',
      type: _ExplorePlaceType.parkingFacility,
    ),
  ];

  List<_ExplorePlace> get _visiblePlaces => _places.where((place) {
    final matchesFilter = switch (_selectedFilter) {
      1 => place.type == _ExplorePlaceType.freeParking,
      2 => place.type == _ExplorePlaceType.parkingFacility,
      _ => true,
    };
    final query = _searchQuery.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        place.name.toLowerCase().contains(query) ||
        place.description.toLowerCase().contains(query);
    return matchesFilter && matchesQuery;
  }).toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Yakınında keşfet',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text('İstanbul’daki park bilgilerini tek yerde keşfet.'),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Örnek alanlarda ara',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = _selectedFilter == index;
              return Material(
                color: selected
                    ? ParkIstPalette.oceanTeal
                    : ParkIstPalette.cornflower.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => _selectedFilter = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : ParkIstPalette.oceanTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${_visiblePlaces.length} örnek alan',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_visiblePlaces.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('Bu aramayla eşleşen örnek alan yok.')),
          )
        else
          for (final place in _visiblePlaces) _ExplorePlaceCard(place: place),
        const SizedBox(height: 8),
        const _ExploreStatusNote(),
      ],
    );
  }
}

class _ExploreStatusNote extends StatelessWidget {
  const _ExploreStatusNote();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Bu listedeki alanlar örnektir; canlı park verisi değildir. Güncel topluluk bildirimleri için Harita sekmesini kullan.',
      ),
    ),
  );
}

class _ExplorePlaceCard extends StatelessWidget {
  const _ExplorePlaceCard({required this.place});

  final _ExplorePlace place;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, label, color) = switch (place.type) {
      _ExplorePlaceType.freeParking => (
        Icons.local_parking_outlined,
        'Ücretsiz · örnek',
        isDark ? ParkIstPalette.darkAvailable : ParkIstPalette.available,
      ),
      _ExplorePlaceType.needsReview => (
        Icons.update_outlined,
        'Doğrulama gerekli · örnek',
        isDark ? ParkIstPalette.darkReview : ParkIstPalette.review,
      ),
      _ExplorePlaceType.parkingFacility => (
        Icons.garage_outlined,
        'Ücretli otopark · örnek',
        Colors.blueGrey,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: .2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B035063),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    place.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}
