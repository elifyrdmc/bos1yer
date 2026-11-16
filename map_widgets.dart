part of '../main.dart';

const _mapMuted = Color(0xFF9CA8BA);
const _mapGold = Color(0xFFF4A928);

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const BrandLockup(iconSize: 38, wordmarkHeight: 19, gap: 8);
  }
}

class _CompactNavigationDock extends StatelessWidget {
  const _CompactNavigationDock({
    required this.selectedIndex,
    required this.onSelected,
    this.pageTint,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? pageTint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const tabs = [
      (
        label: 'Harita',
        icon: Icons.map_outlined,
        selectedIcon: Icons.map_rounded,
      ),
      (
        label: 'Ödüller',
        icon: Icons.card_giftcard_outlined,
        selectedIcon: Icons.card_giftcard_rounded,
      ),
      (
        label: 'Profil',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                pageTint?.withValues(alpha: .86) ??
                colors.surface.withValues(
                  alpha: colors.brightness == Brightness.dark ? .72 : .60,
                ),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: pageTint == null
                  ? colors.surface.withValues(alpha: .68)
                  : colors.primary.withValues(alpha: .14),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.onSurface.withValues(alpha: .16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _CompactNavigationItem(
                    label: tabs[index].label,
                    icon: selectedIndex == index
                        ? tabs[index].selectedIcon
                        : tabs[index].icon,
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactNavigationItem extends StatelessWidget {
  const _CompactNavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: .17)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontSize: 11,
                      height: 1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapAddButton extends StatelessWidget {
  const _MapAddButton({required this.onTap, this.isOpen = false});

  final VoidCallback onTap;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: isOpen ? 'Bildirim seçeneklerini kapat' : 'Bildirim ekle',
      child: Material(
        color: ParkDesign.buttonGreen,
        shape: const CircleBorder(),
        elevation: 5,
        shadowColor: colors.onSurface.withValues(alpha: .24),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(
              isOpen ? Icons.close_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddActionTile extends StatelessWidget {
  const _AddActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: .68),
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 19,
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddActionsPanel extends StatelessWidget {
  const _AddActionsPanel({required this.onVacancy, required this.onLeaving});

  final VoidCallback onVacancy;
  final VoidCallback onLeaving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: .98),
      borderRadius: BorderRadius.circular(22),
      elevation: 12,
      shadowColor: colors.shadow.withValues(alpha: .22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ne paylaşmak istiyorsun?',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Yalnızca güvenli biçimde durduğunda paylaş.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            _AddActionTile(
              icon: Icons.add_location_alt_rounded,
              title: 'Boş yer gördüm',
              subtitle: 'Fotoğraf çek ve konumu doğrula',
              onTap: onVacancy,
            ),
            Divider(height: 1, color: colors.outlineVariant),
            _AddActionTile(
              icon: Icons.logout_rounded,
              title: 'Çıkıyorum',
              subtitle: 'Ayrılacağın yeri kısa süreli paylaş',
              onTap: onLeaving,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSearchInput extends StatelessWidget {
  const _MapSearchInput({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onSubmitted,
    required this.onSearch,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, color: colors.secondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: TextInputType.streetAddress,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              decoration: const InputDecoration(
                hintText: 'Adres veya semt ara',
                border: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Ara',
            onPressed: isSearching ? null : onSearch,
            visualDensity: VisualDensity.compact,
            icon: isSearching
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
          ),
          IconButton(
            tooltip: 'Aramayı kapat',
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.embedded = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: embedded
          ? Colors.transparent
          : colors.surface.withValues(alpha: .94),
      shape: embedded ? null : const CircleBorder(),
      child: InkWell(
        customBorder: embedded ? null : const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: embedded ? 42 : 44,
            height: 44,
            child: Icon(icon, color: colors.onSurfaceVariant, size: 21),
          ),
        ),
      ),
    );
  }
}

class _MapFilterTile extends StatelessWidget {
  const _MapFilterTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _DemoPinKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? ParkIstPalette.cornflower.withValues(alpha: .13)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? ParkIstPalette.cornflower
                  : colors.outlineVariant.withValues(alpha: .65),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(kind.icon, color: kind.color(context), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kind.filterLabel,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 18,
                color: selected ? ParkIstPalette.oceanTeal : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
