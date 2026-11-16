part of '../main.dart';

class _ReportReviewPage extends StatefulWidget {
  const _ReportReviewPage({
    required this.reportType,
    required this.photo,
    required this.location,
    required this.description,
    required this.feeStatus,
    required this.permittedHours,
    required this.restrictionTime,
    required this.vehicleFit,
    required this.leavingDurationMinutes,
    this.leavingPresence,
    required this.onSubmit,
  });

  final String reportType;
  final XFile? photo;
  final LatLng location;
  final String description;
  final String feeStatus;
  final String permittedHours;
  final String restrictionTime;
  final String vehicleFit;
  final int leavingDurationMinutes;
  final LeavingReportPresence? leavingPresence;
  final Future<ParkingReportRecord> Function() onSubmit;

  @override
  State<_ReportReviewPage> createState() => _ReportReviewPageState();
}

class _ReportReviewPageState extends State<_ReportReviewPage> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final report = await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(report);
    } catch (error) {
      debugPrint('Parking report submission failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bildirim kaydedilemedi. Bağlantıyı kontrol edip tekrar dene.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportType = widget.reportType;
    final photo = widget.photo;
    final location = widget.location;
    final description = widget.description;
    final feeStatus = widget.feeStatus;
    final permittedHours = widget.permittedHours;
    final restrictionTime = widget.restrictionTime;
    final vehicleFit = widget.vehicleFit;
    final leavingDurationMinutes = widget.leavingDurationMinutes;
    final leavingPresence = widget.leavingPresence;
    final visibilityMessage = reportType == 'Çıkıyorum'
        ? leavingPresence == LeavingReportPresence.nearby && photo == null
              ? 'Fotoğrafı seçtiğin $leavingDurationMinutes dakika içinde ekle. Zamanında eklenmezse bildirim kalkar.'
              : 'Tahmini çıkış süresi $leavingDurationMinutes dk. Bildirim bu süreden sonra 10 dakika daha haritada kalır.'
        : 'Bildirimin hesabınla kaydedilir ve en fazla 10 dakika etkin kalır.';
    final canSubmit =
        reportType == 'Boş yer bildir' || reportType == 'Çıkıyorum';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Material(
            color: ParkIstPalette.cornflower.withValues(alpha: .16),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Geri',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        title: Text(reportType),
        actions: [
          Center(
            child: Text(
              '2 / 2',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 1,
                    minHeight: 4,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Son kontrol',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ParkDesign.radius),
                    child: Stack(
                      children: [
                        Image.file(
                          File(photo.path),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface
                                  .withValues(alpha: .92),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kamera fotoğrafı',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 160,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(ParkDesign.radius),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Fotoğraf bildirimi oluşturduktan sonra eklenecek',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.campaign_outlined),
                        title: const Text('Bildirim türü'),
                        subtitle: Text(reportType),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                          reportType == 'Boş yer bildir' ||
                                  reportType == 'Dolu yer bildir' ||
                                  reportType == 'Çıkıyorum'
                              ? 'Çekim konumu'
                              : 'Seçilen konum',
                        ),
                        subtitle: Text(
                          '${location.latitude.toStringAsFixed(5)}, '
                          '${location.longitude.toStringAsFixed(5)}',
                        ),
                      ),
                      if (reportType == 'Çıkıyorum')
                        ListTile(
                          leading: const Icon(Icons.my_location_outlined),
                          title: const Text('Bildirim durumu'),
                          subtitle: Text(
                            leavingPresence == LeavingReportPresence.nearby
                                ? 'Yakındayım · ${photo == null ? 'Fotoğraf $leavingDurationMinutes dakika içinde beklenecek' : 'Fotoğraf yüklü'}'
                                : 'Konumdayım · fotoğraf eklendi',
                          ),
                        ),
                      if (reportType == 'Çıkıyorum')
                        ListTile(
                          leading: const Icon(Icons.timer_outlined),
                          title: const Text('Tahmini ayrılma süresi'),
                          subtitle: Text(
                            '$leavingDurationMinutes dakika · kesinlik garantisi yok',
                          ),
                        ),
                      if (description.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.notes_outlined),
                          title: const Text('Açıklama'),
                          subtitle: Text(description),
                        ),
                      if (reportType == 'Park alanı ekle') ...[
                        ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: const Text('Ücret durumu'),
                          subtitle: Text(feeStatus),
                        ),
                        if (permittedHours.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.schedule_outlined),
                            title: const Text('İzin verilen saatler'),
                            subtitle: Text(permittedHours),
                          ),
                      ],
                      if (reportType == 'Kısıtlama bildir' &&
                          restrictionTime.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.schedule_outlined),
                          title: const Text('Geçerli olduğu zaman'),
                          subtitle: Text(restrictionTime),
                        ),
                      if (reportType == 'Park alanı ekle' ||
                          reportType == 'Boş yer bildir' ||
                          reportType == 'Dolu yer bildir' ||
                          reportType == 'Çıkıyorum')
                        ListTile(
                          leading: const Icon(Icons.directions_car_outlined),
                          title: const Text('Büyük araca uygunluk · tahmin'),
                          subtitle: Text(
                            '$vehicleFit · doğrulanmış ölçü veya garanti değildir',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('$visibilityMessage Park kurallarını yerinde kontrol et.'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Ayrıntıları düzenle'),
                ),
                const SizedBox(height: 8),
                if (!canSubmit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Şu an yalnızca boş yer ve Çıkıyorum bildirimleri sunucuya kaydediliyor.',
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting || !canSubmit ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _isSubmitting
                        ? 'Kaydediliyor…'
                        : canSubmit
                        ? 'Bildirimi gönder'
                        : 'Bu bildirim türü henüz kaydedilemiyor',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
