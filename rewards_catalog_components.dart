part of '../main.dart';

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.offer,
    required this.balance,
    required this.onTap,
  });

  final _RewardOffer offer;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final affordable = balance >= offer.examplePoints;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.brightness == Brightness.dark
                      ? ParkDesign.darkRaised
                      : ParkDesign.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.brightness == Brightness.dark
                        ? ParkDesign.darkGroupOutline
                        : ParkDesign.groupOutline,
                  ),
                ),
                child: Icon(offer.icon, color: colors.onSurface, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${offer.redemptionType.shortLabel} · örnek',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_formatPoints(offer.examplePoints)} puan',
                    style: TextStyle(
                      color: affordable
                          ? colors.tertiary
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (!affordable) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: .10)
                            : const Color(0xFFEFF1EE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Yetersiz',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardsCatalogError extends StatelessWidget {
  const _RewardsCatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? ParkDesign.darkCardSurface
            : ParkDesign.white,
        borderRadius: BorderRadius.circular(ParkDesign.radius),
        border: Border.all(
          color: colors.brightness == Brightness.dark
              ? ParkDesign.darkGroupOutline
              : ParkDesign.groupOutline,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.error),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ödüller yüklenemedi. Bağlantını kontrol edip tekrar dene.',
            ),
          ),
          IconButton(
            tooltip: 'Tekrar dene',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _CouponEmptyState extends StatelessWidget {
  const _CouponEmptyState({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = switch (selected) {
      'Süresi doldu' => 'Süresi dolmuş kupon yok',
      'Kullanıldı' => 'Kullanılmış kupon yok',
      _ => 'Henüz aktif kuponun yok',
    };
    final description = switch (selected) {
      'Aktif' => 'Ödüller bölümünden puanlarınla bir kupon alabilirsin.',
      'Kullanıldı' =>
        'İşletme tarafından doğrulanan kullanımlar burada listelenir.',
      _ => 'Bu duruma ait kuponlar burada listelenir.',
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (selected) {
                'Kullanıldı' => Icons.task_alt_rounded,
                'Süresi doldu' => Icons.schedule_rounded,
                _ => Icons.confirmation_number_outlined,
              },
              size: 48,
              color: colors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardsTestNotice extends StatelessWidget {
  const _RewardsTestNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.brightness == Brightness.dark
                ? ParkDesign.darkLine
                : ParkDesign.line,
          ),
        ),
      ),
      child: Text(
        'Ödül listesi ve kuponlar test içeriğidir.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }
}

String _formatPoints(int value) {
  final digits = value.abs().toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write('.');
    grouped.write(digits[index]);
  }
  return '${value < 0 ? '−' : ''}$grouped';
}

String _formatPointsDelta(int value) =>
    '${value > 0
        ? '+'
        : value < 0
        ? '−'
        : ''}${_formatPoints(value.abs())}';

String _formatTransactionDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} · $hour:$minute';
}
