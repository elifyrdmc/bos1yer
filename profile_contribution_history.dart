part of '../profile_settings_page.dart';

class _ContributionHistoryPage extends StatefulWidget {
  const _ContributionHistoryPage({required this.reportType});

  final String reportType;

  @override
  State<_ContributionHistoryPage> createState() =>
      _ContributionHistoryPageState();
}

class _ContributionHistoryPageState extends State<_ContributionHistoryPage> {
  late Future<List<ParkingReportHistoryEntry>> _history;

  bool get _isEmptySpot => widget.reportType.contains('Boş yer');

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  Future<List<ParkingReportHistoryEntry>> _loadHistory() {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentUser == null) {
      return Future.error(StateError('Hesap bağlantısı bulunamadı.'));
    }
    return ContributionHistoryRepository(Supabase.instance.client)
        .fetch(limit: 100);
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} · '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _statusLabel(String status) => switch (status) {
    'active' => 'Aktif',
    'parked' => 'Park edildi',
    'occupied' => 'Yer doluydu',
    'feedback' => 'Yanıt alındı',
    'cancelled' => 'İptal edildi',
    _ => 'Süresi doldu',
  };

  Color _statusColor(String status) {
    final colors = Theme.of(context).colorScheme;
    return switch (status) {
      'active' => colors.onSurface,
      'parked' => colors.primary,
      'occupied' =>
        colors.brightness == Brightness.dark
            ? const Color(0xFFFFD576)
            : const Color(0xFFB87508),
      'feedback' =>
        colors.brightness == Brightness.dark
            ? const Color(0xFF9CCBFA)
            : const Color(0xFF477AA8),
      'cancelled' => colors.onSurfaceVariant,
      _ => colors.onSurfaceVariant,
    };
  }

  Future<void> _showEntryDetails(ParkingReportHistoryEntry entry) async {
    final isVacancy = entry.kind == 'vacancy';
    final colors = Theme.of(context).colorScheme;
    final responseCount =
        entry.parkedCount + entry.occupiedCount + entry.notFoundCount;
    final note = entry.note?.trim();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isVacancy
                        ? Icons.local_parking_rounded
                        : Icons.logout_rounded,
                    color: isVacancy
                        ? colors.primary
                        : colors.brightness == Brightness.dark
                        ? const Color(0xFFFFD576)
                        : const Color(0xFFB87508),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVacancy
                              ? 'Boş yer bildirimi'
                              : 'Çıkıyorum bildirimi',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _ContributionStatus(
                          label: _statusLabel(entry.status),
                          color: _statusColor(entry.status),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!entry.photoPathIncluded)
                const _ContributionPhotoUnavailable(
                  message: 'Fotoğraf bilgisi şu anda alınamıyor.',
                )
              else if (entry.photoObjectPath == null)
                const _ContributionPhotoUnavailable(
                  message: 'Bu bildirime fotoğraf eklenmemiş.',
                )
              else
                _ContributionPhoto(photoPath: entry.photoObjectPath!),
              const SizedBox(height: 24),
              _ContributionDetailLine(
                icon: Icons.schedule_rounded,
                label: 'Bildirim zamanı',
                value: _formatDate(entry.createdAt),
              ),
              if (entry.estimatedDepartureMinutes != null) ...[
                const SizedBox(height: 18),
                _ContributionDetailLine(
                  icon: Icons.timelapse_rounded,
                  label: 'Tahmini çıkış süresi',
                  value: '${entry.estimatedDepartureMinutes} dakika',
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'Topluluk geri bildirimi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (responseCount > 0)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeedbackCount(
                      label: 'Park edildi',
                      count: entry.parkedCount,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    _FeedbackCount(
                      label: 'Yer doluydu',
                      count: entry.occupiedCount,
                      icon: Icons.event_busy_outlined,
                    ),
                    _FeedbackCount(
                      label: 'Bulunamadı',
                      count: entry.notFoundCount,
                      icon: Icons.search_off_rounded,
                    ),
                  ],
                )
              else ...[
                Text(
                  'Bu bildirime henüz geri bildirim gelmedi.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 22),
                _ContributionDetailLine(
                  icon: Icons.notes_rounded,
                  label: 'Notun',
                  value: note,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(List<ParkingReportHistoryEntry> entries) {
    final filtered = entries
        .where((entry) => entry.kind == (_isEmptySpot ? 'vacancy' : 'leaving'))
        .toList(growable: false);
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            _isEmptySpot
                ? 'Henüz boş yer bildirimin yok.'
                : 'Henüz Çıkıyorum bildirimin yok.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final colors = Theme.of(context).colorScheme;
        return Material(
          color: colors.brightness == Brightness.dark
              ? ParkDesign.darkCardSurface
              : ParkDesign.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ParkDesign.radius),
            side: BorderSide(
              color: colors.brightness == Brightness.dark
                  ? ParkDesign.darkGroupOutline
                  : ParkDesign.groupOutline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showEntryDetails(entry),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isEmptySpot
                        ? Icons.local_parking_rounded
                        : Icons.logout_rounded,
                    color: _isEmptySpot
                        ? colors.primary
                        : colors.brightness == Brightness.dark
                        ? const Color(0xFFFFD576)
                        : const Color(0xFFB87508),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEmptySpot
                              ? 'Boş yer bildirimi'
                              : 'Çıkıyorum bildirimi',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(entry.createdAt),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        if ((entry.note?.trim().isNotEmpty ?? false) ||
                            entry.estimatedDepartureMinutes != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            entry.note?.trim().isNotEmpty ?? false
                                ? entry.note!.trim()
                                : 'Tahmini çıkış ${entry.estimatedDepartureMinutes} dk',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ContributionStatus(
                        label: _statusLabel(entry.status),
                        color: _statusColor(entry.status),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.reportType)),
      body: FutureBuilder<List<ParkingReportHistoryEntry>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Katkı geçmişi yüklenemedi. Bağlantını kontrol edip tekrar dene.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _history = _loadHistory()),
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildHistory(snapshot.data ?? const []);
        },
      ),
    );
  }
}

class _ContributionStatus extends StatelessWidget {
  const _ContributionStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color:
              colors.brightness == Brightness.dark && color == colors.onSurface
              ? colors.onSurface
              : color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeedbackCount extends StatelessWidget {
  const _FeedbackCount({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 7),
          Text('$count $label', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _ContributionDetailLine extends StatelessWidget {
  const _ContributionDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContributionPhoto extends StatefulWidget {
  const _ContributionPhoto({required this.photoPath});

  final String photoPath;

  @override
  State<_ContributionPhoto> createState() => _ContributionPhotoState();
}

class _ContributionPhotoState extends State<_ContributionPhoto> {
  late final Future<String?> _signedUrl = _loadSignedUrl();

  Future<String?> _loadSignedUrl() async {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentUser == null) {
      return null;
    }
    try {
      return await Supabase.instance.client.storage
          .from('parking-report-photos')
          .createSignedUrl(widget.photoPath, 300);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<String?>(
      future: _signedUrl,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 196,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(ParkDesign.radius),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (url == null) {
          return const _ContributionPhotoUnavailable(
            message: 'Fotoğraf şu anda görüntülenemiyor.',
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(ParkDesign.radius),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: colors.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stackTrace) =>
                  const _ContributionPhotoUnavailable(
                    message: 'Fotoğraf şu anda görüntülenemiyor.',
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _ContributionPhotoUnavailable extends StatelessWidget {
  const _ContributionPhotoUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ParkDesign.radius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
