part of '../main.dart';

class _PhotoStepPage extends StatefulWidget {
  const _PhotoStepPage({required this.reportType});

  final String reportType;

  @override
  State<_PhotoStepPage> createState() => _PhotoStepPageState();
}

class _PhotoStepPageState extends State<_PhotoStepPage> {
  final ImagePicker _picker = ImagePicker();
  final _descriptionController = TextEditingController();
  final _hoursController = TextEditingController();
  final _restrictionTimeController = TextEditingController();
  XFile? _photo;
  bool _choosingPhoto = false;
  LatLng? _captureLocation;
  LatLng? _deviceLocation;
  LatLng? _reportLocation;
  String _feeStatus = 'Belirtilmedi';
  String _vehicleFit = 'Bilinmiyor';
  int _leavingDurationMinutes = 5;
  LeavingReportPresence _leavingPresence = LeavingReportPresence.atLocation;

  String get _continueLabel => 'Bildirimi önizle';

  @override
  void dispose() {
    _descriptionController.dispose();
    _hoursController.dispose();
    _restrictionTimeController.dispose();
    super.dispose();
  }

  Widget _buildVehicleFitField() {
    final colors = Theme.of(context).colorScheme;
    const choices = <(String, String)>[
      ('Bilinmiyor', 'Bilmiyorum'),
      ('Uygun görünüyor', 'Uygun'),
      ('Uygun görünmüyor', 'Uygun değil'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Büyük araca uygun mu?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Gözlemine göre seç',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in choices)
              ChoiceChip(
                label: Text(choice.$2),
                selected: _vehicleFit == choice.$1,
                showCheckmark: false,
                backgroundColor: colors.surface,
                selectedColor: colors.primaryContainer,
                side: BorderSide(
                  color: _vehicleFit == choice.$1
                      ? colors.primary
                      : colors.outlineVariant,
                ),
                labelStyle: TextStyle(
                  color: _vehicleFit == choice.$1
                      ? colors.primary
                      : colors.onSurface,
                  fontWeight: _vehicleFit == choice.$1
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _vehicleFit = choice.$1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationStatus() {
    final colors = Theme.of(context).colorScheme;
    final nearby =
        widget.reportType == 'Çıkıyorum' &&
        _leavingPresence == LeavingReportPresence.nearby;
    final verified = _captureLocation != null;
    return Row(
      children: [
        Icon(
          verified
              ? Icons.check_circle_outline_rounded
              : Icons.my_location_rounded,
          size: 21,
          color: verified ? colors.primary : colors.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            verified
                ? 'Çekim konumu doğrulandı'
                : nearby && _reportLocation != null
                ? 'Araç konumu seçildi · gönderirken doğrulanacak'
                : nearby
                ? 'Konum gönderirken doğrulanacak'
                : 'Konum fotoğraf çekilirken doğrulanacak',
            style: TextStyle(
              color: verified ? colors.onSurface : colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: verified ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<LatLng> _readAccurateLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _LocationUnavailable('Cihaz konum servisi kapalı.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const _LocationUnavailable('Konum izni gerekli.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 15));
    if (position.accuracy > 30) {
      throw const _LocationUnavailable(
        'Konum doğruluğu 30 metre içinde değil. Daha açık bir alanda tekrar dene.',
      );
    }
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _takePhoto() async {
    setState(() => _choosingPhoto = true);
    try {
      final before = await _readAccurateLocation();
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (photo == null || !mounted) return;
      final after = await _readAccurateLocation();
      final moved = const Distance().as(LengthUnit.Meter, before, after);
      if (moved > 30) {
        throw const _LocationUnavailable(
          'Fotoğraf sırasında 30 metreden fazla hareket ettin. Yerinde durup tekrar çek.',
        );
      }
      final selectedReportLocation = _reportLocation;
      if (widget.reportType == 'Çıkıyorum' &&
          _leavingPresence == LeavingReportPresence.nearby &&
          selectedReportLocation != null &&
          const Distance().as(LengthUnit.Meter, selectedReportLocation, after) >
              30) {
        throw const _LocationUnavailable(
          'Fotoğrafı seçtiğin araç konumunun 30 metre yakınında çekmelisin.',
        );
      }
      final privacyResult = await PhotoPrivacyService.sanitize(
        File(photo.path),
      );
      _captureLocation = after;
      _deviceLocation = after;
      setState(() => _photo = XFile(privacyResult.file.path));
      if (privacyResult.needsPreviewWarning && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fotoğrafta yüz/plaka bulanıklaştırılmamış olabilir. Paylaşmadan önce önizlemede kontrol et.',
            ),
          ),
        );
      }
    } on _LocationUnavailable catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf alınamadı. Tekrar deneyebilirsin.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _choosingPhoto = false);
    }
  }

  Future<void> _continueToDetails() async {
    final isLeaving = widget.reportType == 'Çıkıyorum';
    final maySkipPhoto =
        isLeaving && _leavingPresence == LeavingReportPresence.nearby;
    if (_photo == null && !maySkipPhoto) return;
    var deviceLocation = _captureLocation ?? _deviceLocation;
    if (deviceLocation == null || (maySkipPhoto && _photo == null)) {
      if (!maySkipPhoto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğrafla birlikte konum doğrulanmalı.'),
          ),
        );
        return;
      }
      setState(() => _choosingPhoto = true);
      try {
        deviceLocation = await _readAccurateLocation();
        _deviceLocation = deviceLocation;
        _reportLocation ??= deviceLocation;
      } on _LocationUnavailable catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      } finally {
        if (mounted) setState(() => _choosingPhoto = false);
      }
    }
    if (!mounted) return;
    final verifiedDeviceLocation = deviceLocation;
    final reportLocation =
        isLeaving && _leavingPresence == LeavingReportPresence.nearby
        ? (_reportLocation ?? verifiedDeviceLocation)
        : (_captureLocation ?? verifiedDeviceLocation);
    if (isLeaving &&
        _leavingPresence == LeavingReportPresence.nearby &&
        _photo == null) {
      final maxDistance = _leavingDurationMinutes == 5 ? 300.0 : 500.0;
      final distance = const Distance().as(
        LengthUnit.Meter,
        verifiedDeviceLocation,
        reportLocation,
      );
      if (distance > maxDistance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Araç konumu mevcut GPS konumundan en fazla ${maxDistance.round()} metre uzakta olabilir.',
            ),
          ),
        );
        return;
      }
    }
    if (isLeaving && _photo != null) {
      final distance = const Distance().as(
        LengthUnit.Meter,
        reportLocation,
        verifiedDeviceLocation,
      );
      if (distance > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fotoğraf, bildirim konumunun 30 metre yakınında çekilmiş olmalı.',
            ),
          ),
        );
        return;
      }
    }
    final report = await Navigator.of(context).push<ParkingReportRecord>(
      MaterialPageRoute<ParkingReportRecord>(
        builder: (context) => _ReportReviewPage(
          reportType: widget.reportType,
          photo: _photo,
          location: reportLocation,
          description: _descriptionController.text.trim(),
          feeStatus: _feeStatus,
          permittedHours: _hoursController.text.trim(),
          restrictionTime: _restrictionTimeController.text.trim(),
          vehicleFit: _vehicleFit,
          leavingDurationMinutes: _leavingDurationMinutes,
          leavingPresence: isLeaving ? _leavingPresence : null,
          onSubmit: () =>
              ParkingReportRepository(Supabase.instance.client).createReport(
                kind: widget.reportType == 'Çıkıyorum'
                    ? ParkingReportKind.leaving
                    : ParkingReportKind.vacancy,
                location: reportLocation,
                deviceLocation: verifiedDeviceLocation,
                photo: _photo == null ? null : File(_photo!.path),
                note: _descriptionController.text.trim(),
                estimatedDepartureMinutes: widget.reportType == 'Çıkıyorum'
                    ? _leavingDurationMinutes
                    : null,
                leavingPresence: isLeaving ? _leavingPresence : null,
              ),
        ),
      ),
    );
    if (!mounted || report == null) return;
    final reportIsLeaving = report.kind == ParkingReportKind.leaving;
    Navigator.of(context).pop(
      _DemoMapPin(
        point: LatLng(report.latitude, report.longitude),
        label: reportIsLeaving ? 'Çıkıyorum' : 'Boş yer bildirimi',
        description: report.note?.isNotEmpty == true
            ? report.note!
            : 'Topluluk bildirimi; boş yer garantisi değildir.',
        kind: reportIsLeaving ? _DemoPinKind.leaving : _DemoPinKind.vacancy,
        estimatedDepartureMinutes: report.estimatedDepartureMinutes,
        createdAt: report.createdAt,
        remotePhotoUrl: report.signedPhotoUrl,
        photoPath: _photo?.path,
        hasPhoto: report.photoObjectPath != null,
        canUploadPhoto: report.canUploadPhoto,
        leavingPresence: report.leavingPresence,
        isLocalDemo: false,
        reportId: report.id,
        isLiveReport: true,
        district:
            report.district ??
            _approximateDistrictForPoint(
              LatLng(report.latitude, report.longitude),
            ),
      ),
    );
  }

  Future<void> _chooseVehicleLocation() async {
    setState(() => _choosingPhoto = true);
    try {
      final currentLocation = _deviceLocation ?? await _readAccurateLocation();
      if (!mounted) return;
      final maxDistance = _leavingDurationMinutes == 5 ? 300.0 : 500.0;
      final initialSelection = _reportLocation ?? currentLocation;
      final selected = await showDialog<LatLng>(
        context: context,
        builder: (context) => _VehicleLocationPickerDialog(
          currentLocation: currentLocation,
          initialSelection: initialSelection,
          maxDistanceMeters: maxDistance,
        ),
      );
      if (!mounted) return;
      setState(() {
        _deviceLocation = currentLocation;
        _reportLocation = selected ?? _reportLocation ?? currentLocation;
      });
    } on _LocationUnavailable catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _choosingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Geri',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.reportType,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '1 / 2',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: .5,
                  minHeight: 4,
                  backgroundColor: colors.outlineVariant,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  if (widget.reportType == 'Çıkıyorum') ...[
                    Text(
                      'Şu an neredesin?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<LeavingReportPresence>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: ParkDesign.green.withValues(
                            alpha: .10,
                          ),
                          selectedForegroundColor: colors.onSurface,
                          minimumSize: const Size(0, 48),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: LeavingReportPresence.atLocation,
                            label: Text('Konumdayım'),
                          ),
                          ButtonSegment(
                            value: LeavingReportPresence.nearby,
                            label: Text('Yakındayım'),
                          ),
                        ],
                        selected: {_leavingPresence},
                        onSelectionChanged: (selection) {
                          if (selection.first == _leavingPresence) return;
                          setState(() {
                            _leavingPresence = selection.first;
                            _captureLocation = null;
                            _deviceLocation = null;
                            _reportLocation = null;
                            _photo = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _leavingPresence == LeavingReportPresence.atLocation
                          ? 'Fotoğrafı şimdi ekle.'
                          : 'Fotoğrafı seçtiğin süre içinde ekle.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ne zaman ayrılacaksın?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (final minutes in [5, 10])
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _leavingDurationMinutes = minutes;
                              _reportLocation = null;
                            }),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(88, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              backgroundColor:
                                  _leavingDurationMinutes == minutes
                                  ? ParkDesign.green.withValues(alpha: .10)
                                  : colors.surface,
                              foregroundColor: colors.onSurface,
                              side: BorderSide(
                                color: _leavingDurationMinutes == minutes
                                    ? colors.primary
                                    : colors.outlineVariant,
                              ),
                            ),
                            child: Text('$minutes dk'),
                          ),
                      ],
                    ),
                    if (_leavingPresence == LeavingReportPresence.nearby) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Aracının konumu',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _choosingPhoto
                            ? null
                            : _chooseVehicleLocation,
                        icon: const Icon(Icons.location_on_outlined),
                        label: Text(
                          _reportLocation == null
                              ? 'Aracın konumunu haritadan seç'
                              : 'Araç konumunu değiştir',
                        ),
                      ),
                      Text(
                        _reportLocation == null
                            ? 'Seçmezsen mevcut konumun kullanılır.'
                            : 'Fotoğrafı bu noktanın 30 m yakınında çekmelisin.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 22),
                  Text(
                    widget.reportType == 'Çıkıyorum' &&
                            _leavingPresence == LeavingReportPresence.nearby
                        ? 'Fotoğraf · $_leavingDurationMinutes dk içinde'
                        : 'Fotoğraf · zorunlu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 160,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(ParkDesign.radius),
                      border: Border.all(
                        color: _photo == null
                            ? colors.outlineVariant
                            : colors.primary,
                        width: 1.3,
                      ),
                    ),
                    child: _photo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 34,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                widget.reportType == 'Çıkıyorum' &&
                                        _leavingPresence ==
                                            LeavingReportPresence.nearby
                                    ? 'Aracına vardığında fotoğraf ekle'
                                    : widget.reportType == 'Çıkıyorum'
                                    ? 'Aracını ve park yerini göster'
                                    : 'Boşluğu ve çevresini göster',
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(_photo!.path), fit: BoxFit.cover),
                              Positioned(
                                left: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surface.withValues(
                                      alpha: .92,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_outlined,
                                        color: colors.primary,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Kamera fotoğrafı',
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _choosingPhoto ? null : _takePhoto,
                      icon: _choosingPhoto
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        _photo == null ? 'Fotoğraf çek' : 'Yeniden çek',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Konum', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _buildLocationStatus(),
                  const SizedBox(height: 22),
                  Text(
                    'Kısa açıklama · isteğe bağlı',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      hintText: 'Yerle ilgili bir ayrıntı ekle',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                    ),
                  ),
                  if (widget.reportType == 'Park alanı ekle') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _feeStatus,
                      decoration: const InputDecoration(
                        labelText: 'Ücret durumu',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Belirtilmedi',
                          child: Text('Bilmiyorum'),
                        ),
                        DropdownMenuItem(
                          value: 'Ücretsiz',
                          child: Text('Ücretsiz'),
                        ),
                        DropdownMenuItem(
                          value: 'Ücretli',
                          child: Text('Ücretli'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _feeStatus = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hoursController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'İzin verilen saatler (isteğe bağlı)',
                        hintText: 'Örn. hafta içi 09.00–18.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildVehicleFitField(),
                  ],
                  if (widget.reportType == 'Boş yer bildir' ||
                      widget.reportType == 'Dolu yer bildir' ||
                      widget.reportType == 'Çıkıyorum') ...[
                    const SizedBox(height: 12),
                    _buildVehicleFitField(),
                  ],
                  if (widget.reportType == 'Kısıtlama bildir') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _restrictionTimeController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Geçerli olduğu zaman (isteğe bağlı)',
                        hintText: 'Örn. bugün 18.00’e kadar',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: _mapGold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Fotoğraf park iznini doğrulamaz. Kuralları yerinde kontrol et.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ParkDesign.primaryButton(
                      Theme.of(context).brightness,
                    ),
                    foregroundColor: ParkDesign.primaryButtonForeground(
                      Theme.of(context).brightness,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ParkDesign.radius),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  onPressed:
                      _choosingPhoto ||
                          (_photo == null &&
                              !(widget.reportType == 'Çıkıyorum' &&
                                  _leavingPresence ==
                                      LeavingReportPresence.nearby))
                      ? null
                      : _continueToDetails,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(_continueLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
