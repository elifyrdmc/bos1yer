import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend/parking_report_repository.dart';
import 'backend/parking_report_feedback_repository.dart';

/// Lets a signed-in driver submit one nearby outcome for a live report.
class ParkingReportFeedbackPanel extends StatefulWidget {
  const ParkingReportFeedbackPanel({
    super.key,
    required this.reportId,
    required this.reportKind,
    this.awaitingPhoto = false,
    required this.onReportResolved,
  });

  final String reportId;
  final ParkingReportKind reportKind;
  final bool awaitingPhoto;
  final VoidCallback onReportResolved;

  @override
  State<ParkingReportFeedbackPanel> createState() =>
      _ParkingReportFeedbackPanelState();
}

class _ParkingReportFeedbackPanelState
    extends State<ParkingReportFeedbackPanel> {
  late final ParkingReportFeedbackRepository _repository;
  late Future<ParkingReportFeedbackSummary> _summaryFuture;
  ParkingReportFeedbackSummary? _summary;
  ParkingReportOutcome? _selectedOutcome;
  bool _isSubmitting = false;
  bool _isCheckingLocation = false;
  String? _submitError;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _repository = ParkingReportFeedbackRepository(Supabase.instance.client);
    _summaryFuture = _repository.fetch(widget.reportId);
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Konum servisi kapalı.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Yakınlığı doğrulamak için konum izni gerekli.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 15));
    if (position.accuracy > 30) {
      throw StateError('Konum doğruluğu 30 metre içinde değil.');
    }
    return position;
  }

  Future<void> _checkProximity() async {
    if (_isCheckingLocation) return;
    setState(() {
      _isCheckingLocation = true;
      _locationError = null;
    });
    try {
      final position = await _currentPosition();
      final summary = await _repository.fetch(
        widget.reportId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _locationError = summary.isNearby
            ? null
            : 'Yanıt göndermek için bildirimin 30 metre içinde olmalısın.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error is StateError
            ? error.message
            : 'Konum doğrulanamadı. Tekrar deneyebilirsin.';
      });
    } finally {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  Future<void> _submit() async {
    final outcome = _selectedOutcome;
    final summary = _summary;
    final canChangeNotFound =
        summary?.canUpdate == true &&
        summary?.myOutcome == ParkingReportOutcome.notFound &&
        outcome != ParkingReportOutcome.notFound;
    if (outcome == null ||
        _isSubmitting ||
        !(summary?.canSubmit == true || canChangeNotFound)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      // Re-read location at submission time; the server also rechecks distance.
      final position = await _currentPosition();
      final summary = await _repository.submit(
        reportId: widget.reportId,
        outcome: outcome,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _selectedOutcome = null;
      });
      if (summary.isResolved) widget.onReportResolved();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error is StateError ? error.message : 'Sonuç kaydedilemedi. Yakınlığını, bildirim süresini ve yanıt durumunu kontrol et.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<ParkingReportFeedbackSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final summary = _summary ?? snapshot.data;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Geri bildirim',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (summary?.isAuthor != true)
                Text(
                  'Yanıt vermek için bildirime 30 metre yakın olmalısın.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  summary == null)
                const LinearProgressIndicator(minHeight: 2)
              else if (snapshot.hasError && summary == null)
                Text(
                  'Sonuçlar şu an alınamıyor.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.error),
                )
              else if (summary != null) ...[
                Builder(
                  builder: (context) {
                    final canRespond =
                        summary.feedbackOpen &&
                        summary.isNearby &&
                        (summary.canSubmit || summary.canUpdate) &&
                        !summary.isAuthor &&
                        !summary.isResolved;
                    final statusMessage = summary.isResolved
                        ? 'Bildirim sonuçlandı.'
                        : summary.isAuthor
                        ? 'Kendi bildirimin için yanıt veremezsin.'
                        : summary.canUpdate &&
                              summary.myOutcome == ParkingReportOutcome.notFound
                        ? '“Bulamadım” yanıtını bir kez düzeltebilirsin.'
                        : summary.myOutcome != null
                        ? 'Yanıtın onaylandı; bu yanıt değiştirilemez.'
                        : !summary.feedbackOpen
                        ? widget.awaitingPhoto
                              ? 'Fotoğraf ve çıkış tahmini bekleniyor.'
                              : widget.reportKind == ParkingReportKind.leaving
                              ? 'Çıkış tahmini geldiğinde yanıt verebilirsin.'
                              : 'Yanıt süresi sona erdi.'
                        : !summary.isNearby
                        ? 'Konumunu doğrulayınca yanıt verebilirsin.'
                        : 'Bu bildirim için yanıtın zaten kaydedilmiş.';

                    if (summary.isAuthor) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu bildirim senin.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (summary.notFoundCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Bulamadım · ${summary.notFoundCount}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _outcomeChip(
                              ParkingReportOutcome.parked,
                              'Park ettim',
                              summary.parkedCount,
                              enabled:
                                  canRespond &&
                                  (summary.canSubmit ||
                                      ParkingReportOutcome.parked !=
                                          summary.myOutcome),
                            ),
                            _outcomeChip(
                              ParkingReportOutcome.occupied,
                              'Yer doluydu',
                              summary.occupiedCount,
                              enabled:
                                  canRespond &&
                                  (summary.canSubmit ||
                                      ParkingReportOutcome.occupied !=
                                          summary.myOutcome),
                            ),
                            _outcomeChip(
                              ParkingReportOutcome.notFound,
                              'Bulamadım',
                              summary.notFoundCount,
                              enabled: canRespond && summary.canSubmit,
                            ),
                          ],
                        ),
                        if (canRespond && summary.canUpdate) ...[
                          const SizedBox(height: 8),
                          Text(
                            '“Bulamadım” yanıtını bu bildirimde yalnızca bir kez düzeltebilirsin.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                        if (!canRespond) ...[
                          const SizedBox(height: 8),
                          Text(
                            _locationError ?? statusMessage,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _locationError == null
                                      ? colors.onSurfaceVariant
                                      : colors.error,
                                ),
                          ),
                        ],
                        if (summary.feedbackOpen &&
                            !summary.isNearby &&
                            !summary.isAuthor &&
                            (summary.myOutcome == null || summary.canUpdate) &&
                            !summary.isResolved) ...[
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: _isCheckingLocation
                                ? null
                                : _checkProximity,
                            icon: _isCheckingLocation
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded),
                            label: Text(
                              _isCheckingLocation
                                  ? 'Konum kontrol ediliyor…'
                                  : 'Yakınlığımı doğrula',
                            ),
                          ),
                        ],
                        if (canRespond) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  _selectedOutcome == null || _isSubmitting
                                  ? null
                                  : _submit,
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                              label: Text(
                                summary.canUpdate
                                    ? 'Yanıtımı güncelle'
                                    : _selectedOutcome ==
                                          ParkingReportOutcome.parked
                                    ? 'Park ettim yanıtını onayla'
                                    : 'Yanıtı onayla',
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (_isSubmitting) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submitError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.error),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _outcomeChip(
    ParkingReportOutcome outcome,
    String label,
    int count, {
    bool enabled = true,
  }) {
    final selected = (_selectedOutcome ?? _summary?.myOutcome) == outcome;
    return ActionChip(
      avatar: selected ? const Icon(Icons.check_rounded, size: 18) : null,
      label: Text('$label · $count'),
      onPressed: !enabled || _isSubmitting
          ? null
          : () => setState(() {
              _selectedOutcome = outcome;
              _submitError = null;
            }),
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: .14),
      ),
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
