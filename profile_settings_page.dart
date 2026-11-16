import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';
import 'app_appearance.dart';
import 'design_system.dart';
import 'first_use_hints.dart';
import 'favorite_district_store.dart';
import 'trust_score_format.dart';
import 'istanbul_districts.dart';
import 'backend/auth_repository.dart';
import 'backend/contribution_history_repository.dart';
import 'backend/contribution_summary_repository.dart';
import 'backend/points_wallet_repository.dart';
import 'backend/supabase_config.dart';
import 'backend/trust_score_repository.dart';

part 'src/profile_contribution_history.dart';
part 'src/profile_local_store.dart';
part 'src/profile_components.dart';
part 'src/profile_editor.dart';
part 'src/profile_settings_sections.dart';
part 'src/profile_account_deletion.dart';
part 'src/profile_notification_settings.dart';

/// Profile settings and presentation metrics for the signed-in account.
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}
class _ProfileSettingsPageState extends State<ProfileSettingsPage>
    with WidgetsBindingObserver {
  final _preview = _ProfilePreview();
  Future<PointsWallet>? _pointsWallet;
  Future<ContributionCounts>? _contributionCounts;
  Future<TrustScoreSummary>? _trustScore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_preview.load());
    _refreshMetrics();
  }

  void _refreshMetrics() {
    if (SupabaseConfig.isConfigured) {
      final client = Supabase.instance.client;
      setState(() {
        _pointsWallet = PointsWalletRepository(client).fetch();
        _contributionCounts = ContributionSummaryRepository(client).fetch();
        _trustScore = TrustScoreRepository(client).fetch();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshMetrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _preview,
    builder: (context, _) => _preview.isLoading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _refreshMetrics();
                      try {
                        await _trustScore;
                      } catch (_) {
                        // The metric itself presents a retryable error state.
                      }
                    },
                    child: ListView(
                      // Keep enough scroll range for the final card to pass above
                      // the translucent dock without reserving a blank footer.
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 148),
                      children: [
                        _ProfileIdentityCard(
                          preview: _preview,
                          onEdit: () => _editProfile(context, _preview),
                          onSettings: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => _SettingsPage(preview: _preview),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _trustHeading(context),
                        _pointsAndTrustMetrics(),
                        const _SectionHeading(title: 'Katkı özeti'),
                        _buildContributionSummary(context),
                        const SizedBox(height: 12),
                        const _SectionHeading(title: 'Harita tercihleri'),
                        const _FavoriteAreasCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
  );

  Widget _buildContributionSummary(BuildContext context) {
    final future = _contributionCounts;
    if (future == null) {
      return _contributionCard(context, null);
    }
    return FutureBuilder<ContributionCounts>(
      future: future,
      builder: (context, snapshot) => _contributionCard(context, snapshot.data),
    );
  }

  Widget _trustHeading(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Puan ve güven',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Güven puanı nasıl hesaplanır?',
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => const SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParkHelpStep(
                      icon: Icons.verified_user_outlined,
                      title: 'Güven puanı',
                      description: 'İlk hesaplama mevcut başlangıç kuralını izler. Sonrasında doğrulanmış “Park ettim” sonucu +0,5, fotoğrafsız süresi dolan “Yakındayım” bildirimi −0,2 etkiler. Diğer bildirim ve yanıtlar puanı değiştirmez. Puan 0–5 arasındadır.',
                    ),
                    ParkHelpStep(
                      icon: Icons.stars_outlined,
                      title: 'Ödül puanı',
                      description: 'Ödül puanı kuponlar için kullanılır; güven puanından ayrıdır.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.help_outline_rounded, size: 20),
        ),
      ],
    ),
  );

  Widget _contributionCard(BuildContext context, ContributionCounts? counts) =>
      _ContributionSummaryCard(
        vacancyCount: counts?.vacancyCount,
        leavingCount: counts?.leavingCount,
        onOpenVacancy: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const _ContributionHistoryPage(
              reportType: 'Boş yer bildirimleri',
            ),
          ),
        ),
        onOpenLeaving: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const _ContributionHistoryPage(
              reportType: 'Çıkıyorum bildirimleri',
            ),
          ),
        ),
      );

  Widget _pointsAndTrustMetrics() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _pointsMetric()),
      const SizedBox(width: 10),
      Expanded(child: _trustMetric()),
    ],
  );

  Widget _trustMetric() {
    final future = _trustScore;
    if (future == null) {
      return _ProfileMetric(
        icon: Icons.verified_user_rounded,
        label: 'Güven durumu',
        value: '— / 5',
        detail: 'Supabase bağlantısı yok',
        color: Theme.of(context).colorScheme.onSurface,
      );
    }
    return FutureBuilder<TrustScoreSummary>(
      future: future,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final score = summary?.score;
        final formattedScore = visibleTrustScore(
          score,
          summary?.qualifyingOutcomeCount,
        );
        final value = snapshot.hasError
            ? '— / 5'
            : summary == null
            ? '…'
            : formattedScore ?? '— / 5';
        final detail = snapshot.hasError
            ? 'Puan alınamadı'
            : summary == null
            ? 'Yükleniyor'
            : formattedScore != null
            ? '0–5 arası güven puanı'
            : 'Güven hesaplanıyor';
        return _ProfileMetric(
          icon: Icons.verified_user_rounded,
          label: 'Güven durumu',
          value: value,
          detail: detail,
          color: Theme.of(context).colorScheme.onSurface,
        );
      },
    );
  }

  Widget _pointsMetric() {
    final future = _pointsWallet;
    if (future == null) {
      return const _ProfileMetric(
        icon: Icons.stars_rounded,
        label: 'Ödül puanı',
        value: '—',
        detail: 'Supabase bağlantısı yok',
        color: Color(0xFF73549A),
      );
    }
    return FutureBuilder<PointsWallet>(
      future: future,
      builder: (context, snapshot) {
        final value = snapshot.hasData
            ? _formatProfilePoints(snapshot.data!.balance)
            : snapshot.hasError
            ? '—'
            : '…';
        final detail = snapshot.hasData
            ? 'Kullanılabilir puan'
            : snapshot.hasError
            ? 'Cüzdan alınamadı'
            : 'Yükleniyor';
        return _ProfileMetric(
          icon: Icons.stars_rounded,
          label: 'Ödül puanı',
          value: value,
          detail: detail,
          color: const Color(0xFF73549A),
        );
      },
    );
  }

  String _formatProfilePoints(int points) {
    final digits = points.abs().toString();
    final grouped = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(digits[index]);
    }
    return '${points < 0 ? '−' : ''}$grouped';
  }
}

class _FavoriteAreasCard extends StatefulWidget {
  const _FavoriteAreasCard();

  @override
  State<_FavoriteAreasCard> createState() => _FavoriteAreasCardState();
}

class _FavoriteAreasCardState extends State<_FavoriteAreasCard> {
  final _districts = <String>{};
  StreamSubscription<AuthState>? _authSubscription;
  String? _loadedOwnerId;
  String? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (SupabaseConfig.isConfigured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) => unawaited(_load()));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstUseHints.showOnce(
        context,
        key: 'first_use_favorite_areas_hint',
        title: 'Favori bölgelerini takip et',
        message: 'Sık baktığın ilçeleri kaydedebilirsin. Hesabına giriş yaptığında favorilerin cihazların arasında eşitlenir.',
        icon: Icons.favorite_border_rounded,
      );
    });
  }

  Future<void> _load() async {
    final ownerId = FavoriteDistrictStore.currentOwnerId;
    if (mounted && _loadedOwnerId != ownerId) {
      setState(() {
        _districts.clear();
        _isLoading = true;
        _loadError = null;
        _isSaving = false;
      });
    }
    List<String> saved;
    try {
      saved = await FavoriteDistrictStore.load(ownerId);
    } catch (_) {
      if (!mounted || FavoriteDistrictStore.currentOwnerId != ownerId) return;
      setState(() {
        _loadedOwnerId = ownerId;
        _isLoading = false;
        _loadError = 'Favori bölgeler yüklenemedi. Yeniden deneyebilirsin.';
      });
      return;
    }
    if (!mounted || FavoriteDistrictStore.currentOwnerId != ownerId) return;
    setState(() {
      _districts
        ..clear()
        ..addAll(saved);
      _loadedOwnerId = ownerId;
      _isLoading = false;
      _loadError = null;
    });
  }

  Future<bool> _save() async {
    if (FavoriteDistrictStore.currentOwnerId != _loadedOwnerId) return false;
    try {
      await FavoriteDistrictStore.save(_loadedOwnerId, _districts);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggle(String district) async {
    if (_isLoading ||
        _isSaving ||
        FavoriteDistrictStore.currentOwnerId != _loadedOwnerId) {
      await _load();
      return;
    }
    final ownerId = _loadedOwnerId;
    if (_districts.contains(district)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Favori bölgeyi kaldır?'),
          content: Text('$district favorilerinden kaldırılacak.'),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(minimumSize: const Size(112, 48)),
              child: const Text('Vazgeç'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: ParkDesign.destructiveAction(
                  Theme.of(dialogContext).brightness,
                ),
                minimumSize: const Size(112, 48),
              ),
              child: const Text('Kaldır'),
            ),
          ],
        ),
      );
      if (!mounted ||
          confirmed != true ||
          FavoriteDistrictStore.currentOwnerId != ownerId) {
        return;
      }
    }
    final previous = Set<String>.from(_districts);
    setState(() {
      _isSaving = true;
      if (previous.contains(district)) {
        _districts.remove(district);
      } else {
        _districts.add(district);
      }
    });
    final saved = await _save();
    if (!mounted || FavoriteDistrictStore.currentOwnerId != ownerId) return;
    setState(() {
      _isSaving = false;
      if (!saved) {
        _districts
          ..clear()
          ..addAll(previous);
      }
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favori değişikliği kaydedilemedi. Tekrar dene.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _addDistrict() async {
    final available = istanbulDistricts
        .map((district) => district.name)
        .where((name) => !_districts.contains(name))
        .toList(growable: false);
    if (available.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: available.length,
          itemBuilder: (context, index) => ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(available[index]),
            onTap: () => Navigator.of(context).pop(available[index]),
          ),
        ),
      ),
    );
    if (selected != null) await _toggle(selected);
  }

  @override
  Widget build(BuildContext context) {
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
      elevation: 1.2,
      shadowColor: colors.shadow.withValues(alpha: .06),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Favori bölgelerim',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              _isLoading
                                  ? 'Bölgeler yükleniyor…'
                                  : '${_districts.length} kayıtlı bölge',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _loadError!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadError == null ? null : _load,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadError == null) ...[
                for (final district in _districts.toList()..sort())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: colors.primary.withValues(alpha: .10),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 19,
                        color: colors.primary,
                      ),
                    ),
                    title: Text(district),
                    trailing: IconButton(
                      tooltip: '$district favorilerimden kaldır',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _isSaving ? null : () => _toggle(district),
                    ),
                  ),
                if (_districts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Henüz favori bölge eklenmedi.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _addDistrict,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_isSaving ? 'Kaydediliyor…' : 'Bölge ekle'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
