part of '../profile_settings_page.dart';

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({this.preview});

  final _ProfilePreview? preview;

  @override
  Widget build(BuildContext context) {
    final preview = this.preview;
    if (preview == null) return _notice(context, true);
    return AnimatedBuilder(
      animation: preview,
      builder: (context, _) => _notice(context, preview.storageAvailable),
    );
  }

  Widget _notice(BuildContext context, bool storageAvailable) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        storageAvailable
            ? SupabaseConfig.isConfigured &&
                      Supabase.instance.client.auth.currentUser != null
                  ? 'Adın hesabınla eşitlenir. Profil fotoğrafın ve bildirim tercihlerin bu cihazda saklanır.'
                  : 'Hesap bağlantısı olmadığında profil bilgileri ve tercihler bu cihazda saklanır.'
            : 'Bu cihazda profil fotoğrafı veya tercihleri kaydedilemiyor. Hesabınla eşitlenen ad bilgisi korunur.',
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      ParkListSection(title: title, children: children);
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.preview,
    required this.onEdit,
    required this.onSettings,
  });

  final _ProfilePreview preview;
  final VoidCallback onEdit;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _ProfileAvatar(path: preview.photoPath),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  SupabaseConfig.isConfigured
                      ? Supabase.instance.client.auth.currentUser?.email ??
                            'Hesabın'
                      : 'Hesabın',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Profili düzenle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettings,
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _ContributionSummaryCard extends StatelessWidget {
  const _ContributionSummaryCard({
    required this.vacancyCount,
    required this.leavingCount,
    required this.onOpenVacancy,
    required this.onOpenLeaving,
  });

  final int? vacancyCount;
  final int? leavingCount;
  final VoidCallback onOpenVacancy;
  final VoidCallback onOpenLeaving;

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
      child: Column(
        children: [
          ListTile(
            onTap: onOpenVacancy,
            leading: Icon(Icons.local_parking_outlined, color: colors.primary),
            title: const Text('Boş yer bildirimleri'),
            trailing: _ContributionCount(
              value: vacancyCount?.toString() ?? '—',
            ),
          ),
          Divider(height: 1, indent: 56, color: colors.outline),
          ListTile(
            onTap: onOpenLeaving,
            leading: Icon(
              Icons.logout_rounded,
              color: colors.brightness == Brightness.dark
                  ? const Color(0xFFFFD576)
                  : const Color(0xFFB87508),
            ),
            title: const Text('Çıkıyorum bildirimleri'),
            trailing: _ContributionCount(
              value: leavingCount?.toString() ?? '—',
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionCount extends StatelessWidget {
  const _ContributionCount({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(width: 4),
      Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.2),
    ),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(ParkDesign.radius),
        border: Border.all(color: ParkDesign.line.withValues(alpha: .9)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .045),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 2,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 36,
    child: path == null
        ? const Icon(Icons.person_outline, size: 36)
        : ClipOval(
            child: Image.file(
              File(path!),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person_outline, size: 36),
            ),
          ),
  );
}

Future<void> _editProfile(BuildContext context, _ProfilePreview preview) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _ProfileEditor(preview: preview)),
    );
