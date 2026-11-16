part of '../main.dart';

Widget _reportPhotoUnavailable() => Builder(
  builder: (context) => Container(
    height: 190,
    width: double.infinity,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
    alignment: Alignment.center,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined, size: 34),
        SizedBox(height: 8),
        Text('Fotoğraf şu anda açılamıyor.'),
      ],
    ),
  ),
);

class _MapIntroduction extends StatefulWidget {
  const _MapIntroduction({
    required this.onStartReport,
    required this.isActive,
    required this.onOpenProfile,
  });

  final Future<_DemoMapPin?> Function(({LatLng point, int typeIndex}) request)
  onStartReport;
  final bool isActive;
  final VoidCallback onOpenProfile;

  @override
  State<_MapIntroduction> createState() => _MapIntroductionState();
}

class _MapIntroductionState extends State<_MapIntroduction>
    with WidgetsBindingObserver {
  final _demoElapsed = ValueNotifier<Duration>(Duration.zero);
  final _visibleMapBounds = ValueNotifier<LatLngBounds?>(null);
  final _elapsedClock = Stopwatch();
  Timer? _demoTimer;
  List<_DemoMapPin> _liveMapPins = const [];
  bool _isLiveDataLoading = false;
  bool _liveDataFailed = false;
  DateTime? _lastLiveRefreshAt;
  bool _reloadAfterCurrent = false;
  bool _selectedReportUnavailable = false;
  String? _justCreatedReportId;
  String? _focusedReportId;
  Timer? _focusTimer;
  StreamSubscription<AuthState>? _authSubscription;
  String? _mapOwnerId;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  LatLng? _selectedPoint;
  Offset? _selectedScreenPoint;
  String? _selectedPlaceName;
  _DemoMapPin? _selectedDemoPin;
  LatLng? _searchCenter;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  final ValueNotifier<bool> _showSearch = ValueNotifier(false);
  bool _isLocating = false;
  bool _isPlacesExpanded = false;
  bool _isAddMenuOpen = false;
  String _selectedDistrict = 'Tüm ilçeler';
  int _cameraRequestId = 0;
  double _cameraTargetZoom = 16;
  final ValueNotifier<Set<_DemoPinKind>> _activeDemoFilters = ValueNotifier(
    Set<_DemoPinKind>.from(_DemoPinKind.values),
  );
  final List<_DemoMapPin> _userDemoPins = [];
  final GlobalKey<_IstanbulMapState> _mapWidgetKey =
      GlobalKey<_IstanbulMapState>();

  List<_DemoMapPin> _availableMapPins(Duration elapsed) =>
      (SupabaseConfig.isConfigured
              ? [..._liveMapPins, ..._userDemoPins]
              : [..._demoMapPins, ..._userDemoPins])
          .where(
            (pin) =>
                _selectedDistrict == allIstanbulDistrictLabel ||
                pin.district == _selectedDistrict,
          )
          .where((pin) => pin.reportAge(elapsed) < pin.expirationAge)
          .toList(growable: false);

  List<_DemoMapPin> _visibleDemoPins(
    Set<_DemoPinKind> activeFilters,
    Duration elapsed,
  ) =>
      _availableMapPins(elapsed)
          .where((pin) => activeFilters.contains(pin.kind))
          .toList(growable: false);

  Future<void> _startReport(LatLng point, int typeIndex) async {
    final report = await widget.onStartReport((
      point: point,
      typeIndex: typeIndex,
    ));
    if (!mounted || report == null) return;
    final districtFilterWasHidingReport =
        _selectedDistrict != allIstanbulDistrictLabel &&
        report.district != _selectedDistrict;
    setState(() {
      if (report.isLiveReport) {
        _liveMapPins = [
          report,
          ..._liveMapPins.where((pin) => pin.reportId != report.reportId),
        ];
      } else {
        _userDemoPins.insert(0, report);
      }
      _selectedDemoPin = report;
      _selectedReportUnavailable = false;
      _justCreatedReportId = report.isLiveReport ? report.reportId : null;
      _selectedPoint = report.point;
      _selectedScreenPoint = null;
      _selectedPlaceName = null;
      _isPlacesExpanded = false;
      _searchCenter = report.point;
      _cameraTargetZoom = 14;
      _cameraRequestId++;
      if (districtFilterWasHidingReport) {
        _selectedDistrict = allIstanbulDistrictLabel;
      }
    });
    _activeDemoFilters.value = {..._activeDemoFilters.value, report.kind};
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          report.isLiveReport
              ? districtFilterWasHidingReport
                    ? 'Bildirim kaydedildi. Bölge filtresi kaldırılıp harita yenileniyor.'
                    : 'Bildirim kaydedildi; harita yenileniyor.'
              : 'Bildirim bu demo oturumunda haritaya eklendi.',
        ),
      ),
    );
    if (report.isLiveReport) {
      unawaited(_loadLiveReports(reloadAfterCurrent: true));
    }
  }

  void _updateVisibleMapBounds(LatLngBounds bounds) {
    final current = _visibleMapBounds.value;
    if (current != null &&
        (current.northEast.latitude - bounds.northEast.latitude).abs() < .001 &&
        (current.northEast.longitude - bounds.northEast.longitude).abs() <
            .001 &&
        (current.southWest.latitude - bounds.southWest.latitude).abs() < .001 &&
        (current.southWest.longitude - bounds.southWest.longitude).abs() <
            .001) {
      return;
    }
    _visibleMapBounds.value = bounds;
  }

  @override
  void initState() {
    super.initState();
    _mapOwnerId = FavoriteDistrictStore.currentOwnerId;
    if (SupabaseConfig.isConfigured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) {
            final ownerId = FavoriteDistrictStore.currentOwnerId;
            if (!mounted || ownerId == _mapOwnerId) return;
            _mapOwnerId = ownerId;
            _clearActiveMapFilters();
          });
    }
    WidgetsBinding.instance.addObserver(this);
    _elapsedClock.start();
    _demoTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final elapsed = _elapsedClock.elapsed;
      _demoElapsed.value = elapsed;
      // Keep open maps in sync with reports resolved by another driver.
      if (widget.isActive && SupabaseConfig.isConfigured) {
        unawaited(_loadLiveReports());
      }
      // Keep an open detail readable after expiry, with an explicit expired
      // state. The active map and list still filter the report out.
    });
    if (SupabaseConfig.isConfigured) unawaited(_loadLiveReports());
  }

  @override
  void didUpdateWidget(covariant _MapIntroduction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_loadLiveReports());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && SupabaseConfig.isConfigured) {
      unawaited(_loadLiveReports());
    }
  }

  String _availabilitySubtitle(List<_DemoMapPin> visiblePins) {
    late final String status;
    if (!SupabaseConfig.isConfigured) {
      status = visiblePins.isEmpty
          ? 'Canlı veri bağlı değil · yakınında örnek bildirim yok'
          : 'Örnek işaretler · canlı veri bağlı değil';
    } else if (_isLiveDataLoading && _liveMapPins.isEmpty) {
      status = 'Canlı bildirimler yükleniyor';
    } else if (_liveDataFailed) {
      status = 'Canlı bildirimler alınamadı';
    } else {
      final liveCount = visiblePins.where((pin) => pin.isLiveReport).length;
      final localCount = visiblePins.where((pin) => pin.isLocalDemo).length;
      if (liveCount == 0 && localCount > 0) {
        status = 'Bu oturumdaki demo katkısı sunucuya gönderilmedi';
      } else if (liveCount == 0) {
        status = 'Bu bölgede aktif bildirim yok';
      } else if (localCount > 0) {
        status = 'Canlı ve örnek bildirimler gösteriliyor';
      } else {
        status = 'Bildirimler boş yer garantisi vermez';
      }
    }
    final refreshedAt = _lastLiveRefreshAt;
    if (refreshedAt == null || !SupabaseConfig.isConfigured) return status;
    final hour = refreshedAt.hour.toString().padLeft(2, '0');
    final minute = refreshedAt.minute.toString().padLeft(2, '0');
    return '$status · Son kontrol $hour:$minute';
  }

  Future<void> _loadLiveReports({bool reloadAfterCurrent = false}) async {
    if (!SupabaseConfig.isConfigured) return;
    if (_isLiveDataLoading) {
      _reloadAfterCurrent = _reloadAfterCurrent || reloadAfterCurrent;
      return;
    }
    setState(() {
      _isLiveDataLoading = true;
      _liveDataFailed = false;
    });

    try {
      final records = await ParkingReportRepository(Supabase.instance.client)
          .fetchActiveReports();
      if (!mounted) return;

      final ageClockBase = _elapsedClock.elapsed;
      _demoElapsed.value = ageClockBase;
      final localPhotoPaths = <String, String>{
        for (final pin in _liveMapPins)
          if (pin.reportId != null && pin.photoPath != null)
            pin.reportId!: pin.photoPath!,
      };
      final pins = records
          .map(
            (record) => _pinFromRecord(
              record,
              ageClockBase: ageClockBase,
              localPhotoPath: localPhotoPaths[record.id],
            ),
          )
          .toList(growable: false);

      setState(() {
        _liveMapPins = pins;
        _liveDataFailed = false;
        _lastLiveRefreshAt = DateTime.now();
        final createdId = _justCreatedReportId;
        _justCreatedReportId = null;
        if (createdId != null &&
            !pins.any((pin) => pin.reportId == createdId) &&
            widget.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Bildirim kaydedildi ancak aktif bildirimler arasında görünmüyor. Süresini ve konumunu kontrol et.',
                ),
              ),
            );
          });
        }
        final selectedId = _selectedDemoPin?.reportId;
        if (selectedId != null) {
          final refreshed = pins.where((pin) => pin.reportId == selectedId);
          if (refreshed.isEmpty) {
            _selectedReportUnavailable = true;
          } else {
            _selectedDemoPin = refreshed.first;
            _selectedReportUnavailable = false;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveDataFailed = true;
      });
      if (widget.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bildirimler yenilenemedi. Son alınan kayıtlar gösteriliyor.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLiveDataLoading = false);
      if (_reloadAfterCurrent && mounted) {
        _reloadAfterCurrent = false;
        unawaited(_loadLiveReports());
      }
    }
  }

  _DemoMapPin _pinFromRecord(
    ParkingReportRecord record, {
    Duration? ageClockBase,
    String? localPhotoPath,
  }) => _DemoMapPin(
    point: LatLng(record.latitude, record.longitude),
    label: record.kind == ParkingReportKind.vacancy
        ? 'Boş yer bildirimi'
        : 'Çıkıyorum',
    description: record.note?.isNotEmpty == true
        ? record.note!
        : 'Boş yer garantisi değildir.',
    kind: record.kind == ParkingReportKind.vacancy
        ? _DemoPinKind.vacancy
        : _DemoPinKind.leaving,
    estimatedDepartureMinutes: record.estimatedDepartureMinutes,
    ageAtFetch: record.ageAtFetch,
    ageClockBase: ageClockBase ?? _elapsedClock.elapsed,
    reportId: record.id,
    remotePhotoUrl: record.signedPhotoUrl,
    photoPath: record.photoObjectPath == null ? null : localPhotoPath,
    hasPhoto: record.photoObjectPath != null,
    canUploadPhoto: record.canUploadPhoto,
    isOwnReport: record.isAuthor,
    leavingPresence: record.leavingPresence,
    isLocalDemo: false,
    isLiveReport: true,
    district:
        record.district ??
        _approximateDistrictForPoint(LatLng(record.latitude, record.longitude)),
    authorTrustScore: record.authorTrustScore,
    authorTrustOutcomeCount: record.authorTrustOutcomeCount,
  );

  Future<void> _searchPlaces(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _isSearching.value) return;
    FocusScope.of(context).unfocus();
    _isSearching.value = true;
    try {
      final results = await _NominatimSearch.search(query);
      if (!mounted || !widget.isActive) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu aramayla eşleşen yer bulunamadı.')),
        );
        return;
      }
      final selected = await showModalBottomSheet<_PlaceSearchResult>(
        context: context,
        showDragHandle: true,
        builder: (context) => _PlaceResultsSheet(results: results),
      );
      if (!mounted || selected == null) return;
      setState(() {
        _searchCenter = selected.point;
        _cameraTargetZoom = 16;
        _cameraRequestId++;
        // Arama yalnızca haritayı taşır. Sonuç noktasına ait bir bildirim
        // kartını, kullanıcı pine dokunana kadar otomatik açma.
        _selectedPoint = null;
        _selectedScreenPoint = null;
        _selectedPlaceName = null;
        _selectedDemoPin = null;
      });
      _showSearch.value = false;
    } on SocketException {
      if (mounted && widget.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arama için internet bağlantısı gerekli.'),
          ),
        );
      }
    } on TimeoutException {
      if (mounted && widget.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arama zaman aşımına uğradı. Tekrar deneyebilirsin.'),
          ),
        );
      }
    } catch (_) {
      if (mounted && widget.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yer araması şu anda kullanılamıyor.')),
        );
      }
    } finally {
      if (mounted) _isSearching.value = false;
    }
  }

  void _onVisibleMapBoundsChanged(LatLngBounds bounds, bool hasGesture) {
    _updateVisibleMapBounds(bounds);
    if (!hasGesture) return;
    if (_selectedDistrict != allIstanbulDistrictLabel) {
      final selected = istanbulDistricts.where(
        (district) => district.name == _selectedDistrict,
      );
      if (selected.isNotEmpty) {
        final districtCenter = LatLng(
          selected.first.latitude,
          selected.first.longitude,
        );
        if (hasLeftFilteredDistrictView(bounds, districtCenter)) {
          setState(() => _selectedDistrict = allIstanbulDistrictLabel);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bölge filtresi kaldırıldı. Tüm bildirimler gösteriliyor.',
              ),
            ),
          );
        }
      }
    }
    if (_selectedPoint == null) return;
    setState(() {
      _selectedPoint = null;
      _selectedScreenPoint = null;
      _selectedPlaceName = null;
      _selectedDemoPin = null;
    });
  }

  void _openSearch() {
    _showSearch.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _showSearch.value = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _demoTimer?.cancel();
    _focusTimer?.cancel();
    _authSubscription?.cancel();
    _elapsedClock.stop();
    _positionSubscription?.cancel();
    _demoElapsed.dispose();
    _visibleMapBounds.dispose();
    _activeDemoFilters.dispose();
    _isSearching.dispose();
    _showSearch.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationUnavailable('Cihaz konum servisi kapalı.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationUnavailable(
          'Konum izni verilmedi. İstersen adres aramasını kullanabilirsin.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedDistrict = allIstanbulDistrictLabel;
        _currentPosition = position;
        _searchCenter = point;
        _cameraTargetZoom = 16;
        _cameraRequestId++;
        _selectedPoint = null;
        _selectedScreenPoint = null;
        _selectedPlaceName = null;
        _selectedDemoPin = null;
      });
      _activeDemoFilters.value = Set<_DemoPinKind>.from(_DemoPinKind.values);
      _startLocationTracking();
    } on _LocationUnavailable catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum alınamadı; tekrar deneyebilirsin.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Konuma erişilemedi. Adres aramasını kullanabilirsin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (!mounted || !widget.isActive) return;
          setState(() => _currentPosition = position);
        }, onError: (_) {});
  }

  void _showSelectedPointDetails() {
    final point = _selectedPoint;
    if (point == null) return;
    final openedPin = _selectedDemoPin;

    var isCancellingReport = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => ValueListenableBuilder<Duration>(
          valueListenable: _demoElapsed,
          builder: (context, elapsed, _) {
            final currentPin = _selectedDemoPin;
            final unavailable =
                openedPin != null &&
                (_selectedReportUnavailable ||
                    currentPin?.reportId != openedPin.reportId ||
                    openedPin.reportAge(elapsed) >= openedPin.expirationAge);
            return SafeArea(
              child: unavailable
                  ? SizedBox(
                      width: double.infinity,
                      height: 300,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Bu bildirim artık aktif değil',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Haritadan kaldırıldı. Güncel bildirimlere bakabilirsin.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Kapat'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color:
                                      _selectedDemoPin?.kind ==
                                          _DemoPinKind.leaving
                                      ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF433D2D)
                                            : const Color(0xFFFFF9E9))
                                      : ParkIstPalette.cornflower.withValues(
                                          alpha: .16,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _selectedDemoPin?.icon ??
                                      Icons.near_me_rounded,
                                  color:
                                      _selectedDemoPin?.mapColor(
                                        context,
                                        _demoElapsed.value,
                                      ) ??
                                      ParkIstPalette.oceanTeal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedDemoPin?.label ??
                                          _selectedPlaceName ??
                                          'Seçilen konum',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (_selectedDemoPin?.isLiveReport == true)
                                      Text(
                                        '${_selectedDemoPin!.mapAge(elapsed).inMinutes} dk önce paylaşıldı',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      )
                                    else
                                      Text(
                                        _selectedDemoPin == null
                                            ? 'Konum bilgisi'
                                            : 'Örnek bildirim',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              letterSpacing: .35,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Detayı kapat',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          if (_selectedDemoPin?.isOwnReport == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Senin bildirimin',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (_selectedDemoPin == null) ...[
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.info_outline),
                              title: Text('BOŞ1YER kaydı yok'),
                              subtitle: Text(
                                'Bu koordinat yalnızca haritada seçildi; burada park alanı '
                                'veya park kuralı doğrulanmış değil.',
                              ),
                            ),
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.hourglass_empty),
                              title: Text('Anlık durum: bilinmiyor'),
                              subtitle: Text(
                                'Bu konum için doğrulanmış park bilgisi yok.',
                              ),
                            ),
                          ] else ...[
                            if (_selectedDemoPin!.kind ==
                                _DemoPinKind.leaving) ...[
                              Text(
                                'Çıkış durumu',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<Duration>(
                                valueListenable: _demoElapsed,
                                builder: (context, elapsed, child) {
                                  if (_selectedReportUnavailable ||
                                      _selectedDemoPin!.reportAge(elapsed) >=
                                          _selectedDemoPin!.expirationAge) {
                                    return const SizedBox.shrink();
                                  }
                                  final remaining = _selectedDemoPin!
                                      .remainingDepartureEstimate(elapsed);
                                  final expired = remaining == Duration.zero;
                                  final statusColor = expired
                                      ? ParkIstPalette.available
                                      : ParkIstPalette.unconfirmedLeaving;
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.logout_rounded,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                expired
                                                    ? 'Tahmini çıkış zamanı geldi'
                                                    : 'Yaklaşık ${remaining.inMinutes + (remaining.inSeconds % 60 == 0 ? 0 : 1)} dk içinde çıkacak',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                expired
                                                    ? 'Pin yeşil; yerin boş olduğu doğrulanmış değil.'
                                                    : 'Tahmindir; araç henüz ayrılmamış olabilir.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                            if (_selectedDemoPin!.hasPhoto ||
                                _selectedDemoPin!.remotePhotoUrl != null ||
                                _selectedDemoPin!.photoPath != null ||
                                (_selectedDemoPin!.kind ==
                                        _DemoPinKind.vacancy &&
                                    !_selectedDemoPin!.isLiveReport)) ...[
                              if (_selectedDemoPin!.kind ==
                                  _DemoPinKind.leaving)
                                const SizedBox(height: 16),
                              Text(
                                'Fotoğraf',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  ParkDesign.radius,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (_selectedDemoPin!.remotePhotoUrl !=
                                          null)
                                        Image.network(
                                          _selectedDemoPin!.remotePhotoUrl!,
                                          height: 190,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            final localPath =
                                                _selectedDemoPin?.photoPath;
                                            return localPath == null
                                                ? _reportPhotoUnavailable()
                                                : Image.file(
                                                    File(localPath),
                                                    height: 190,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        _reportPhotoUnavailable(),
                                                  );
                                          },
                                        )
                                      else if (_selectedDemoPin!.photoPath !=
                                          null)
                                        Image.file(
                                          File(_selectedDemoPin!.photoPath!),
                                          height: 190,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              _reportPhotoUnavailable(),
                                        )
                                      else if (!_selectedDemoPin!.isLiveReport)
                                        Image.asset(
                                          'assets/demo/parking-spot-sample.jpg',
                                          height: 190,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      else
                                        _reportPhotoUnavailable(),
                                      if (!_selectedDemoPin!.isLiveReport)
                                        Positioned(
                                          left: 12,
                                          bottom: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withValues(alpha: .94),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              'ÖRNEK FOTOĞRAF',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: .25,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (_selectedDemoPin!.isLiveReport &&
                                _selectedDemoPin!.reportId != null &&
                                _selectedDemoPin!.awaitsLeavingPhoto) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Fotoğraf bekleniyor',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<Duration>(
                                valueListenable: _demoElapsed,
                                builder: (context, elapsed, child) {
                                  final remaining = _selectedDemoPin!
                                      .photoUploadRemaining(elapsed);
                                  if (remaining <= Duration.zero) {
                                    return const Padding(
                                      padding: EdgeInsets.only(top: 12),
                                      child: Text(
                                        'Fotoğraf yükleme süresi doldu.',
                                      ),
                                    );
                                  }
                                  final colors = Theme.of(context).colorScheme;
                                  final minutes =
                                      remaining.inMinutes +
                                      (remaining.inSeconds % 60 == 0 ? 0 : 1);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          border: Border.all(
                                            color: colors.outlineVariant,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.add_a_photo_outlined,
                                              color: colors.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Yükleme süresi',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  Text(
                                                    'Fotoğraf eklenmezse bildirim kalkar',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colors
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$minutes dk',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_selectedDemoPin!.canUploadPhoto)
                                        ParkingReportPhotoUploadPanel(
                                          reportId: _selectedDemoPin!.reportId!,
                                          reportPoint: _selectedDemoPin!.point,
                                          onUploaded: (record) {
                                            if (!mounted) return;
                                            setState(() {
                                              final replacement =
                                                  _pinFromRecord(record);
                                              _liveMapPins = _liveMapPins
                                                  .map(
                                                    (pin) =>
                                                        pin.reportId ==
                                                            record.id
                                                        ? replacement
                                                        : pin,
                                                  )
                                                  .toList(growable: false);
                                              _selectedDemoPin = replacement;
                                            });
                                            // The modal sheet has its own route and does not
                                            // rebuild when the parent map state changes.
                                            setSheetState(() {});
                                          },
                                        )
                                      else
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Fotoğrafı bildirimi oluşturan kişi ekleyebilir.',
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 20),
                            _ReportAuthorTrustCard(
                              isLiveReport: _selectedDemoPin!.isLiveReport,
                              score: _selectedDemoPin!.authorTrustScore,
                              outcomeCount:
                                  _selectedDemoPin!.authorTrustOutcomeCount,
                            ),
                            const SizedBox(height: 16),
                            if (_selectedDemoPin!.isLiveReport &&
                                _selectedDemoPin!.reportId != null) ...[
                              ValueListenableBuilder<Duration>(
                                valueListenable: _demoElapsed,
                                builder: (context, elapsed, _) =>
                                    _selectedReportUnavailable ||
                                        _selectedDemoPin!.reportAge(elapsed) >=
                                            _selectedDemoPin!.expirationAge
                                    ? const SizedBox.shrink()
                                    : ParkingReportFeedbackPanel(
                                        reportId: _selectedDemoPin!.reportId!,
                                        reportKind:
                                            _selectedDemoPin!.kind ==
                                                _DemoPinKind.vacancy
                                            ? ParkingReportKind.vacancy
                                            : ParkingReportKind.leaving,
                                        awaitingPhoto: _selectedDemoPin!
                                            .awaitsLeavingPhoto,
                                        onReportResolved: () {
                                          final reportId =
                                              _selectedDemoPin?.reportId;
                                          if (!mounted || reportId == null) {
                                            return;
                                          }
                                          setState(() {
                                            _liveMapPins = _liveMapPins
                                                .where(
                                                  (pin) =>
                                                      pin.reportId != reportId,
                                                )
                                                .toList(growable: false);
                                            _selectedReportUnavailable = true;
                                            _selectedPoint = null;
                                            _selectedScreenPoint = null;
                                            _selectedPlaceName = null;
                                            _selectedDemoPin = null;
                                          });
                                          setSheetState(() {});
                                        },
                                      ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 8),
                          if (_selectedDemoPin != null) ...[
                            Text(
                              'Konum ve yol tarifi',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'İşaret 8 sn mor vurgulanır.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showSelectedReportOnMap(context),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Haritada göster'),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          ValueListenableBuilder<Duration>(
                            valueListenable: _demoElapsed,
                            builder: (context, elapsed, _) {
                              final pin = _selectedDemoPin;
                              if (pin != null &&
                                  (_selectedReportUnavailable ||
                                      pin.reportAge(elapsed) >=
                                          pin.expirationAge)) {
                                return const SizedBox.shrink();
                              }
                              return ParkingDirectionsAction(
                                point: point,
                                isDemo: pin?.isLiveReport != true,
                              );
                            },
                          ),
                          if (_selectedDemoPin != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _selectedDemoPin!.isLiveReport
                                  ? 'Boş yer ve park hakkı garanti değildir; levhaları yerinde kontrol et.'
                                  : 'Örnek bildirim; gerçek park koşulunu göstermez.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                          if (_selectedDemoPin?.isOwnReport == true) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Bildirimi yönet',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: isCancellingReport
                                  ? null
                                  : () async {
                                      final shouldCancel = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text(
                                            'Bildirimi iptal et?',
                                          ),
                                          content: const Text(
                                            'Bildirim herkesin haritasından kalkar. Güven puanın etkilenmez.',
                                          ),
                                          actionsAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          actions: [
                                            OutlinedButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(false),
                                              style: OutlinedButton.styleFrom(
                                                minimumSize: const Size(
                                                  112,
                                                  48,
                                                ),
                                              ),
                                              child: const Text('Vazgeç'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(true),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Theme.of(
                                                  dialogContext,
                                                ).colorScheme.error,
                                                minimumSize: const Size(
                                                  112,
                                                  48,
                                                ),
                                              ),
                                              child: const Text('İptal et'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (shouldCancel != true) return;
                                      final reportId =
                                          _selectedDemoPin?.reportId;
                                      if (reportId == null) return;
                                      setSheetState(
                                        () => isCancellingReport = true,
                                      );
                                      try {
                                        await ParkingReportRepository(
                                          Supabase.instance.client,
                                        ).cancelReport(reportId);
                                        if (!mounted) return;
                                        setState(() {
                                          _liveMapPins = _liveMapPins
                                              .where(
                                                (pin) =>
                                                    pin.reportId != reportId,
                                              )
                                              .toList(growable: false);
                                          _selectedPoint = null;
                                          _selectedScreenPoint = null;
                                          _selectedPlaceName = null;
                                          _selectedDemoPin = null;
                                        });
                                        Navigator.of(this.context).pop();
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Bildirimin iptal edildi.',
                                                ),
                                              ),
                                            );
                                      } catch (error) {
                                        if (!mounted) return;
                                        setSheetState(
                                          () => isCancellingReport = false,
                                        );
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Bildirim iptal edilemedi: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: isCancellingReport
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cancel_outlined),
                              label: Text(
                                isCancellingReport
                                    ? 'İptal ediliyor…'
                                    : 'Bildirimi iptal et',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .error,
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  void _showSelectedReportOnMap(BuildContext sheetContext) {
    final pin = _selectedDemoPin;
    if (pin == null) return;
    Navigator.of(sheetContext).pop();
    final resetDistrict =
        _selectedDistrict != allIstanbulDistrictLabel &&
        pin.district != _selectedDistrict;
    setState(() {
      if (resetDistrict) _selectedDistrict = allIstanbulDistrictLabel;
      // Keep the selected report attached to the map card while the camera moves.
      _selectedPoint = pin.point;
      _selectedScreenPoint = null;
      _selectedDemoPin = pin;
      _selectedPlaceName = pin.label;
      _searchCenter = pin.point;
      _cameraTargetZoom = 16;
      _cameraRequestId++;
      _focusedReportId = _pinFocusKey(pin);
      _isPlacesExpanded = false;
    });
    _activeDemoFilters.value = {..._activeDemoFilters.value, pin.kind};
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _focusedReportId = null);
    });
  }

  void _showMapLegend() {
    const explanations = <_DemoPinKind, String>{
      _DemoPinKind.vacancy: 'İlk 5 dakika yeşil, sonraki 5 dakika turuncu görünür; 10. dakikada haritadan kalkar.',
      _DemoPinKind.leaving: 'Çıkış tahminine kadar sarı, tahmin sonunda yeşil; 5 dakika sonra turuncu görünür. Süre dolunca kalkar.',
    };

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Harita işaretleri',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Renkler bildirimin güncel durumunu gösterir. Haritadaki bildirimler boş yer garantisi değildir.',
              ),
              const SizedBox(height: 12),
              for (final kind in _DemoPinKind.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(kind.icon, color: kind.color(context)),
                  title: Text(kind.filterLabel),
                  subtitle: Text(explanations[kind]!),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Yakındayım bildiriminde fotoğraf seçilen süre içinde eklenmelidir.',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilters() => _showMapFiltersSheet(
    context: context,
    selectedFilters: _activeDemoFilters.value,
    selectedDistrict: _selectedDistrict,
    chooseDistrict: (value) => _showDistricts(selectedDistrict: value),
    focusDistrict: _focusDistrict,
    applyFilters: (filters) {
      if (mounted) _activeDemoFilters.value = filters;
    },
  );

  void _showAllMapFilters() {
    setState(() {
      _selectedDistrict = allIstanbulDistrictLabel;
      _searchCenter = const LatLng(41.0082, 28.9784);
      _cameraTargetZoom = 12;
      _cameraRequestId++;
      _selectedPoint = null;
      _selectedScreenPoint = null;
      _selectedPlaceName = null;
      _selectedDemoPin = null;
      _isPlacesExpanded = false;
    });
    _activeDemoFilters.value = Set<_DemoPinKind>.from(_DemoPinKind.values);
  }

  void _clearActiveMapFilters() => _showAllMapFilters();

  Future<void> _showFavoriteAreas() async {
    final ownerId = FavoriteDistrictStore.currentOwnerId;
    List<String> favorites;
    try {
      favorites = await FavoriteDistrictStore.load(ownerId);
    } catch (_) {
      if (!mounted || FavoriteDistrictStore.currentOwnerId != ownerId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favori bölgeler yüklenemedi. Daha sonra tekrar dene.'),
        ),
      );
      return;
    }
    if (!mounted || FavoriteDistrictStore.currentOwnerId != ownerId) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: favorites.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 36,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Henüz favori bölgen yok',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Profilindeki “Favori bölgelerim” bölümünden ilçe ekleyebilirsin.',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        widget.onOpenProfile();
                      },
                      child: const Text('Profilde düzenle'),
                    ),
                  ],
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Text(
                    'Favori bölgelerim',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final name in favorites)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.favorite_rounded,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      ),
                      title: Text(name),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                      ),
                      onTap: () {
                        if (FavoriteDistrictStore.currentOwnerId != ownerId) {
                          Navigator.of(sheetContext).pop();
                          return;
                        }
                        Navigator.of(sheetContext).pop();
                        unawaited(_focusDistrict(name));
                      },
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: _demoElapsed,
    builder: (context, elapsed, child) => _buildMap(context, elapsed),
  );

  Widget _buildMap(BuildContext context, Duration elapsed) {
    return Stack(
      children: [
        Positioned.fill(
          child: _IstanbulMap(
            key: _mapWidgetKey,
            selectedPoint: _selectedPoint,
            searchCenter: _searchCenter,
            userPosition: _currentPosition,
            onUserPositionTap: _goToCurrentLocation,
            cameraRequestId: _cameraRequestId,
            cameraTargetZoom: _cameraTargetZoom,
            demoPins: _availableMapPins(elapsed),
            activeDemoFilters: _activeDemoFilters,
            demoElapsed: elapsed,
            highlightedReportId: _focusedReportId,
            highlightedDistrict: _selectedDistrict == allIstanbulDistrictLabel
                ? null
                : _selectedDistrict,
            onVisibleBoundsChanged: _onVisibleMapBoundsChanged,
            hasSearchOverlay: true,
            // Blank map taps are not verified parking reports.
            onPointSelected: null,
            onDemoPinSelected: (selection) => setState(() {
              _selectedPoint = selection.pin.point;
              _selectedScreenPoint = selection.position;
              _selectedPlaceName = null;
              _selectedDemoPin = selection.pin;
            }),
          ),
        ),
        Positioned(
          top: 214,
          left: 30,
          right: 30,
          child: ValueListenableBuilder<Set<_DemoPinKind>>(
            valueListenable: _activeDemoFilters,
            builder: (context, activeFilters, child) {
              if (activeFilters.isNotEmpty) return const SizedBox.shrink();
              return Center(
                child: Material(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(20),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt_off_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text('Bu filtrelerde işaret yok'),
                        ),
                        TextButton(
                          onPressed: _showAllMapFilters,
                          child: const Text('Tümünü göster'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 10,
          left: 16,
          right: 16,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showSearch,
            builder: (context, isSearchOpen, _) => Material(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: .97),
              borderRadius: BorderRadius.circular(22),
              elevation: 3,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 54,
                child: Row(
                  children: [
                    if (isSearchOpen)
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _isSearching,
                          builder: (context, isSearching, _) => _MapSearchInput(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            isSearching: isSearching,
                            onSubmitted: _searchPlaces,
                            onSearch: () =>
                                _searchPlaces(_searchController.text),
                            onClose: _closeSearch,
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(width: 10),
                      const _BrandHeader(),
                      const Spacer(),
                      _MapRoundButton(
                        icon: Icons.search_rounded,
                        tooltip: 'Adres veya semt ara',
                        onTap: _openSearch,
                        embedded: true,
                      ),
                    ],
                    _MapRoundButton(
                      icon: Icons.layers_outlined,
                      tooltip: 'Harita katmanları ve filtreler',
                      onTap: _showFilters,
                      embedded: true,
                    ),
                    _MapRoundButton(
                      icon: Icons.favorite_border_rounded,
                      tooltip: 'Favori bölgelerim',
                      onTap: _showFavoriteAreas,
                      embedded: true,
                    ),
                    if (!isSearchOpen) const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 158,
          right: 16,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(22),
            elevation: 3,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapRoundButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Yakınlaştır',
                  onTap: () => _mapWidgetKey.currentState?.zoomBy(1),
                  embedded: true,
                ),
                Divider(
                  height: 1,
                  indent: 10,
                  endIndent: 10,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                _MapRoundButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Uzaklaştır',
                  onTap: () => _mapWidgetKey.currentState?.zoomBy(-1),
                  embedded: true,
                ),
                Divider(
                  height: 1,
                  indent: 10,
                  endIndent: 10,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                _MapRoundButton(
                  icon: _isLocating ? Icons.hourglass_top : Icons.my_location,
                  tooltip: 'Konumuma git',
                  onTap: _isLocating ? null : _goToCurrentLocation,
                  embedded: true,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 72,
          left: 16,
          right: 16,
          child: ValueListenableBuilder<Set<_DemoPinKind>>(
            valueListenable: _activeDemoFilters,
            builder: (context, filters, _) {
              final districtActive =
                  _selectedDistrict != allIstanbulDistrictLabel;
              final typeActive = filters.length != _DemoPinKind.values.length;
              if (!districtActive && !typeActive) {
                return const SizedBox.shrink();
              }
              final typeLabel = filters.isEmpty
                  ? 'Hiçbiri'
                  : filters.length == 1
                  ? filters.first == _DemoPinKind.vacancy
                        ? 'Boş yer'
                        : 'Çıkıyorum'
                  : null;
              return Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              [
                                if (districtActive) _selectedDistrict,
                                ?typeLabel,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tüm filtreleri temizle',
                            onPressed: _clearActiveMapFilters,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_selectedPoint != null && !_showSearch.value)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth - 32;
                final cardWidth = maxWidth < 344 ? maxWidth : 344.0;
                final maxLeft = constraints.maxWidth - cardWidth - 16;
                final selectedPosition =
                    _selectedScreenPoint ??
                    Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                final left = (selectedPosition.dx - cardWidth / 2)
                    .clamp(16.0, maxLeft)
                    .toDouble();
                final maxTop = (constraints.maxHeight - 360)
                    .clamp(120.0, constraints.maxHeight)
                    .toDouble();
                final top = (selectedPosition.dy - 132)
                    .clamp(maxTop < 210 ? maxTop : 210.0, maxTop)
                    .toDouble();
                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: top,
                      width: cardWidth,
                      child: _SelectedMapCard(
                        pin: _selectedDemoPin,
                        isUnavailable: _selectedReportUnavailable,
                        locationName: _selectedPlaceName,
                        point: _selectedPoint!,
                        elapsed: elapsed,
                        onClose: () => setState(() {
                          _selectedPoint = null;
                          _selectedScreenPoint = null;
                          _selectedPlaceName = null;
                          _selectedDemoPin = null;
                        }),
                        onTap: _showSelectedPointDetails,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Positioned.fill(
          child: ValueListenableBuilder<Set<_DemoPinKind>>(
            valueListenable: _activeDemoFilters,
            builder: (context, activeFilters, child) =>
                ValueListenableBuilder<LatLngBounds?>(
                  valueListenable: _visibleMapBounds,
                  builder: (context, bounds, child) {
                    final visiblePins = _visibleDemoPins(activeFilters, elapsed)
                        .where(
                          (pin) => bounds == null || bounds.contains(pin.point),
                        )
                        .toList(growable: false);
                    final drawerHeight = _isPlacesExpanded
                        ? 338.0
                        : visiblePins.isEmpty
                        ? 104.0
                        : 150.0;
                    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
                    return Stack(
                      children: [
                        if (_isAddMenuOpen)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  setState(() => _isAddMenuOpen = false),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 86 + safeBottom,
                          child: _AvailabilityDrawer(
                            isExpanded: _isPlacesExpanded,
                            isLiveMode: SupabaseConfig.isConfigured,
                            elapsed: elapsed,
                            subtitle: _availabilitySubtitle(visiblePins),
                            onTap: () => setState(
                              () => _isPlacesExpanded = !_isPlacesExpanded,
                            ),
                            onHelp: _showMapLegend,
                            pins: visiblePins,
                            onPinSelected: (pin) => setState(() {
                              _selectedDemoPin = pin;
                              _selectedPoint = pin.point;
                              _selectedScreenPoint = null;
                              _selectedPlaceName = null;
                              _searchCenter = pin.point;
                              _cameraTargetZoom = 16;
                              _cameraRequestId++;
                              _isPlacesExpanded = false;
                            }),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          right: 20,
                          bottom: 86 + safeBottom + drawerHeight + 10,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedSize(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.bottomRight,
                                child: _isAddMenuOpen
                                    ? SizedBox(
                                        width:
                                            MediaQuery.sizeOf(context).width <
                                                340
                                            ? MediaQuery.sizeOf(context).width -
                                                  40
                                            : 300,
                                        child: _AddActionsPanel(
                                          onVacancy: () =>
                                              _startReportFromAddMenu(0),
                                          onLeaving: () =>
                                              _startReportFromAddMenu(1),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (_isAddMenuOpen) const SizedBox(height: 10),
                              _MapAddButton(
                                isOpen: _isAddMenuOpen,
                                onTap: () => setState(() {
                                  _isAddMenuOpen = !_isAddMenuOpen;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }

  void _startReportFromAddMenu(int typeIndex) {
    final point = _selectedPoint ?? const LatLng(41.0082, 28.9784);
    setState(() => _isAddMenuOpen = false);
    unawaited(_startReport(point, typeIndex));
  }

  Future<void> _focusDistrict(String districtName) async {
    final isAllDistricts = districtName == allIstanbulDistrictLabel;
    final district = isAllDistricts
        ? null
        : istanbulDistricts.firstWhere((item) => item.name == districtName);
    final boundary = isAllDistricts
        ? null
        : await IstanbulDistrictBoundaryStore.forName(districtName);
    if (!mounted) return;

    final mapSize = MediaQuery.sizeOf(context);
    setState(() {
      _selectedDistrict = districtName;
      _searchCenter =
          boundary?.bounds.center ??
          (district == null
              ? const LatLng(41.0082, 28.9784)
              : LatLng(district.latitude, district.longitude));
      _cameraTargetZoom = boundary == null
          ? 12
          : IstanbulDistrictBoundaryStore.zoomToFit(boundary.bounds, mapSize);
      _cameraRequestId++;
      _selectedPoint = null;
      _selectedScreenPoint = null;
      _selectedPlaceName = null;
      _selectedDemoPin = null;
      _isPlacesExpanded = false;
    });
  }

  Future<String?> _showDistricts({required String selectedDistrict}) {
    final districts = <String>[
      allIstanbulDistrictLabel,
      ...istanbulDistricts.map((district) => district.name),
    ];
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text('İlçe seç', style: Theme.of(context).textTheme.titleLarge),
            Text(
              'Seçtiğin ilçenin sınırı haritada vurgulanır; liste o bölgeye göre süzülür.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final district in districts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(district),
                trailing: selectedDistrict == district
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(district),
              ),
          ],
        ),
      ),
    );
  }
}
