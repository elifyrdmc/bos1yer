part of '../main.dart';

class _MyCouponsPage extends StatefulWidget {
  const _MyCouponsPage({required this.coupons});

  final List<_DemoCoupon> coupons;

  @override
  State<_MyCouponsPage> createState() => _MyCouponsPageState();
}

class _OfferTerms extends StatelessWidget {
  const _OfferTerms({required this.offer});

  final _RewardOffer offer;

  @override
  Widget build(BuildContext context) {
    final validity = offer.validityIsUnlimited
        ? 'Süresiz'
        : offer.validityDays != null
        ? '${offer.validityDays} gün'
        : '${offer.validityMonths} ay';
    final usage = offer.usageKind == 'single_use'
        ? 'Tek kullanımlık'
        : offer.usageLimitIsUnlimited
        ? 'Çok kullanımlı · sınırsız kullanım'
        : 'Çok kullanımlı · en fazla ${offer.usageLimit} kullanım';
    final branches = switch (offer.branchScope) {
      'all_branches' => 'Tüm şubelerde',
      'selected_branches' =>
        'Seçili şubelerde: ${offer.validBranches.join(', ')}',
      _ => 'Şube uygulanmaz',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kupon koşulları', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        _CouponTermLine(label: 'Geçerlilik', value: validity),
        _CouponTermLine(label: 'Kullanım', value: usage),
        if (offer.usageKind == 'multi_use')
          const _CouponTermLine(
            label: 'Kullanım takibi',
            value: 'İşletme takip eder; uygulama doğrulamaz.',
          ),
        _CouponTermLine(
          label: 'Yeniden satın alma',
          value: offer.allowRepeatPurchase ? 'Açık' : 'Kapalı',
        ),
        if (!offer.agreementIsOpenEnded && offer.agreementEndsAt != null)
          _CouponTermLine(
            label: 'Yeni alım sonu',
            value: _formatLocalDateTime(context, offer.agreementEndsAt!),
          ),
        if (!offer.agreementIsOpenEnded)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Sözleşme bitince yeni alım durur; alınan kuponlar kendi süresini korur.',
            ),
          ),
        _CouponTermLine(label: 'Şube kapsamı', value: branches),
        _CouponTermLine(label: 'Talimat', value: offer.instructions),
      ],
    );
  }
}

class _CouponTerms extends StatelessWidget {
  const _CouponTerms({required this.coupon, required this.terms});

  final _DemoCoupon coupon;
  final Map<String, dynamic> terms;

  @override
  Widget build(BuildContext context) {
    final unlimited = terms['validity_is_unlimited'] != false;
    final months = terms['validity_months'];
    final days = terms['validity_days'];
    final usageKind = terms['usage_kind'] as String? ?? 'single_use';
    final unlimitedUses = terms['usage_limit_is_unlimited'] == true;
    final usageLimit = terms['usage_limit'];
    final branchScope = terms['branch_scope'] as String? ?? 'not_applicable';
    final branches = (terms['valid_branches'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final instructions =
        terms['instructions'] as String? ??
        'Bu eski kupon için kullanım talimatı kaydedilmemiş.';
    final usage = usageKind == 'single_use'
        ? 'Tek kullanımlık'
        : unlimitedUses
        ? 'Çok kullanımlı · sınırsız kullanım'
        : 'Çok kullanımlı · en fazla $usageLimit kullanım';
    final branchLabel = switch (branchScope) {
      'all_branches' => 'Tüm şubelerde',
      'selected_branches' => 'Seçili şubelerde: ${branches.join(', ')}',
      _ => 'Şube uygulanmaz',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Satın alma anındaki koşullar',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        _CouponTermLine(
          label: 'Geçerlilik',
          value: unlimited
              ? 'Süresiz'
              : days != null
              ? '$days gün'
              : '$months ay',
        ),
        _CouponTermLine(label: 'Kullanım', value: usage),
        if (usageKind == 'multi_use')
          const _CouponTermLine(
            label: 'Kullanım takibi',
            value: 'İşletme takip eder; uygulama doğrulamaz.',
          ),
        _CouponTermLine(
          label: 'Yeniden satın alma',
          value: terms['allow_repeat_purchase'] == true ? 'Açık' : 'Kapalı',
        ),
        if (terms['agreement_is_open_ended'] == false &&
            terms['agreement_ends_at'] is String)
          _CouponTermLine(
            label: 'Sözleşme bitişi',
            value: _formatLocalDateTime(
              context,
              DateTime.parse(terms['agreement_ends_at'] as String),
            ),
          ),
        if (terms['agreement_is_open_ended'] == false)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Sözleşme bitişi yeni alımları durdurur; bu kuponun kendi geçerliliği korunur.',
            ),
          ),
        _CouponTermLine(label: 'Şube kapsamı', value: branchLabel),
        _CouponTermLine(label: 'Talimat', value: instructions),
        if (coupon.expiresAt != null)
          _CouponTermLine(
            label: 'Son kullanım',
            value: MaterialLocalizations.of(context)
                .formatMediumDate(coupon.expiresAt!.toLocal()),
          ),
      ],
    );
  }
}

class _CouponTermLine extends StatelessWidget {
  const _CouponTermLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _MyCouponsPageState extends State<_MyCouponsPage> {
  String _selected = 'Aktif';

  void _showCoupon(_DemoCoupon coupon) {
    final terms = coupon.termsSnapshot;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'TEST KUPONU · GERÇEK DEĞİL',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    coupon.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    coupon.partnerName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Chip(
                    avatar: Icon(
                      coupon.redemptionType == _RewardRedemptionType.storeQr
                          ? Icons.qr_code_2_rounded
                          : coupon.redemptionType ==
                                _RewardRedemptionType.onlineCode
                          ? Icons.shopping_bag_outlined
                          : Icons.open_in_new_rounded,
                      size: 16,
                    ),
                    label: Text(coupon.redemptionType.label),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        if (coupon.redemptionType ==
                            _RewardRedemptionType.storeQr)
                          const Icon(Icons.qr_code_2_rounded, size: 54)
                        else
                          Icon(
                            coupon.redemptionType ==
                                    _RewardRedemptionType.onlineCode
                                ? Icons.confirmation_number_outlined
                                : Icons.link_rounded,
                            size: 42,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          coupon.redemptionType == _RewardRedemptionType.storeQr
                              ? 'QR görünüm örneği'
                              : coupon.code,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${coupon.redemptionType.explanation} Gerçek işletmede kullanılamaz; anlaşma, koşul ve geçerli kod/bağlantı tanımlı değildir.',
                  ),
                  const SizedBox(height: 16),
                  _CouponTerms(coupon: coupon, terms: terms),
                  const SizedBox(height: 12),
                  Text(
                    'Bu kuponun kullanımı işletme tarafından doğrulanmadı. Uygulamada kullanıldı olarak işaretlenemez.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
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

  @override
  Widget build(BuildContext context) {
    final visible = widget.coupons
        .where(
          (coupon) => switch (_selected) {
            'Kullanıldı' => coupon.effectiveStatus == 'used',
            'Süresi doldu' => coupon.effectiveStatus == 'expired',
            _ => coupon.effectiveStatus == 'active',
          },
        )
        .toList(growable: false);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kuponlarım')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: ParkDesign.green.withValues(
                    alpha: .10,
                  ),
                  selectedForegroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface,
                  minimumSize: const Size(0, 48),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'Aktif',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Aktif'),
                    ),
                  ),
                  ButtonSegment(
                    value: 'Süresi doldu',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Süresi doldu'),
                    ),
                  ),
                  ButtonSegment(
                    value: 'Kullanıldı',
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Kullanıldı'),
                    ),
                  ),
                ],
                selected: {_selected},
                onSelectionChanged: (selection) =>
                    setState(() => _selected = selection.first),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? _CouponEmptyState(selected: _selected)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final coupon = visible[index];
                        return Card(
                          color: colors.brightness == Brightness.dark
                              ? ParkDesign.darkCardSurface
                              : ParkDesign.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ParkDesign.radius,
                            ),
                            side: BorderSide(
                              color: colors.brightness == Brightness.dark
                                  ? ParkDesign.darkGroupOutline
                                  : ParkDesign.groupOutline,
                            ),
                          ),
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: () => _showCoupon(coupon),
                            leading: const Icon(Icons.local_activity_outlined),
                            title: Text(coupon.title),
                            subtitle: Text(
                              '${coupon.redemptionType.shortLabel} · ${_formatPoints(coupon.points)} test puanı',
                            ),
                            trailing: Text(
                              switch (coupon.effectiveStatus) {
                                'used' => 'Kullanıldı',
                                'expired' => 'Süresi doldu',
                                _ => 'Aktif',
                              },
                              style: TextStyle(
                                color: coupon.effectiveStatus == 'active'
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const _RewardsTestNotice(),
          ],
        ),
      ),
    );
  }
}
