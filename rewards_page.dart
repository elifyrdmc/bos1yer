part of '../main.dart';

class _RewardsPage extends StatefulWidget {
  const _RewardsPage();

  @override
  State<_RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<_RewardsPage>
    with WidgetsBindingObserver {
  late final _DemoRewardsStore _demoStore;
  RewardsRedemptionRepository? _redemptionRepository;
  late final Future<_DemoRewardsState> _demoFuture;
  late Future<List<_RewardOffer>> _offersFuture;
  Future<PointsWallet>? _walletFuture;
  _DemoRewardsState? _demo;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstUseHints.showOnce(
        context,
        key: 'first_use_rewards_hint',
        title: 'Ödüller nasıl çalışır?',
        message: 'Puan bakiyeni, hareketlerini ve kullanılabilir kuponları bu ekrandan takip edebilirsin.',
        icon: Icons.card_giftcard_outlined,
      );
    });
    WidgetsBinding.instance.addObserver(this);
    final accountId = SupabaseConfig.isConfigured
        ? Supabase.instance.client.auth.currentUser?.id ?? 'signed-out'
        : 'local';
    _demoStore = _DemoRewardsStore(accountId);
    // A configured project is authoritative for coupons. Do not merge local
    // example coupons into a signed-in account's server results.
    if (SupabaseConfig.isConfigured) {
      _redemptionRepository = RewardsRedemptionRepository(
        Supabase.instance.client,
      );
      _demoFuture = _loadServerDemoState();
    } else {
      _demoFuture = _demoStore.load().then((state) {
        _demo = state;
        return state;
      });
    }
    _offersFuture = _loadOffers();
    _loadWallet();
  }

  Future<_DemoRewardsState> _loadServerDemoState() async {
    final repository = _redemptionRepository;
    if (repository == null) {
      throw StateError('Server rewards are not configured.');
    }
    final records = await repository.fetchMine();
    final coupons = records
        .map(
          (record) => _DemoCoupon(
            id: record.id,
            offerId: record.offerId,
            title: record.title,
            summary: record.summary,
            points: record.points,
            code: record.code,
            partnerName: record.partnerName,
            redemptionType: _RewardRedemptionType.fromJson(
              record.redemptionType,
            ),
            createdAt: record.createdAt,
            expiresAt: record.expiresAt,
            termsSnapshot: record.termsSnapshot,
            status: record.status,
          ),
        )
        .toList(growable: false);
    final state = _DemoRewardsState(
      balanceAdjustment: 0,
      coupons: List.unmodifiable(coupons),
      movements: const [],
    );
    _demo = state;
    return state;
  }

  Future<List<_RewardOffer>> _loadOffers() async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase ödül kataloğu yapılandırılmamış.');
    }
    final records = await RewardsCatalogRepository(Supabase.instance.client)
        .fetchActiveOffers();
    return List.unmodifiable(records.map(_RewardOffer.fromRecord));
  }

  void _loadWallet() {
    if (!SupabaseConfig.isConfigured) return;
    _walletFuture = PointsWalletRepository(Supabase.instance.client).fetch();
  }

  Future<PointsWallet?> _fetchWallet() async {
    if (!SupabaseConfig.isConfigured) return null;
    final future = PointsWalletRepository(Supabase.instance.client).fetch();
    setState(() {
      _walletFuture = future;
    });
    try {
      return await future;
    } catch (_) {
      // The content widget shows the wallet error and offers another refresh.
      return null;
    }
  }

  Future<void> _refreshWallet() async {
    await _fetchWallet();
  }

  void _refreshOffers() {
    setState(() {
      _offersFuture = _loadOffers();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWallet();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _redeem(_RewardOffer offer) async {
    final current = _demo;
    if (current == null || _redeeming) return;
    setState(() => _redeeming = true);
    try {
      final wallet = await _walletFuture;
      if (wallet == null) {
        throw StateError('Puan bakiyesi alınamadı. Yenileyip tekrar dene.');
      }
      final availableBalance = wallet.balance + current.balanceAdjustment;
      final next = SupabaseConfig.isConfigured
          ? await _redeemOnServer(offer, current, availableBalance)
          : await _demoStore.redeem(
              current,
              offer,
              availableBalance: availableBalance,
            );
      if (!mounted) return;
      setState(() {
        _demo = next;
        _redeeming = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${offer.title} Kuponlarım’a eklendi.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _redeeming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kupon oluşturulamadı: $error')));
    }
  }

  Future<_DemoRewardsState> _redeemOnServer(
    _RewardOffer offer,
    _DemoRewardsState current,
    int availableBalance,
  ) async {
    if (availableBalance < offer.examplePoints) {
      throw StateError('Bu ödül için yeterli puanın yok.');
    }
    final repository = _redemptionRepository;
    if (repository == null) {
      throw StateError('Server rewards are not configured.');
    }
    await repository.redeemDemo(offer.id);
    final next = await _loadServerDemoState();
    await _fetchWallet();
    return next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_RewardOffer>>(
      future: _offersFuture,
      builder: (context, offersSnapshot) {
        return FutureBuilder<_DemoRewardsState>(
          future: _demoFuture,
          builder: (context, demoSnapshot) {
            return FutureBuilder<PointsWallet>(
              future: _walletFuture,
              builder: (context, walletSnapshot) => _RewardsContent(
                offers: offersSnapshot.data ?? const [],
                offersLoading:
                    !offersSnapshot.hasData && !offersSnapshot.hasError,
                offersError: offersSnapshot.hasError,
                onRetryOffers: _refreshOffers,
                wallet: walletSnapshot.data,
                walletLoading:
                    _walletFuture != null &&
                    !walletSnapshot.hasData &&
                    !walletSnapshot.hasError,
                walletError:
                    walletSnapshot.hasError || !SupabaseConfig.isConfigured,
                demo: _demo ?? demoSnapshot.data,
                redeeming: _redeeming,
                onRefreshWallet: _refreshWallet,
                onLoadWallet: _fetchWallet,
                onRedeem: _redeem,
              ),
            );
          },
        );
      },
    );
  }
}

class _RewardsContent extends StatelessWidget {
  const _RewardsContent({
    required this.offers,
    required this.offersLoading,
    required this.offersError,
    required this.onRetryOffers,
    required this.wallet,
    required this.walletLoading,
    required this.walletError,
    required this.demo,
    required this.redeeming,
    required this.onRefreshWallet,
    required this.onLoadWallet,
    required this.onRedeem,
  });

  final List<_RewardOffer> offers;
  final bool offersLoading;
  final bool offersError;
  final VoidCallback onRetryOffers;
  final PointsWallet? wallet;
  final bool walletLoading;
  final bool walletError;
  final _DemoRewardsState? demo;
  final bool redeeming;
  final Future<void> Function() onRefreshWallet;
  final Future<PointsWallet?> Function() onLoadWallet;
  final ValueChanged<_RewardOffer> onRedeem;

  int get balance => (wallet?.balance ?? 0) + (demo?.balanceAdjustment ?? 0);

  void _openMovements(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _RewardsWalletPage(
          wallet: wallet,
          balanceAdjustment: demo?.balanceAdjustment ?? 0,
          testMovements: demo?.movements ?? const [],
          loadWallet: onLoadWallet,
        ),
      ),
    );
  }

  void _openCoupons(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MyCouponsPage(coupons: demo?.coupons ?? const []),
      ),
    );
  }

  void _showOfferDetails(BuildContext context, _RewardOffer offer) {
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: offer.color.withValues(alpha: .12),
                    child: Icon(offer.icon, color: offer.color, size: 27),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    offer.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.partnerName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(offer.summary),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(offer.icon, size: 16, color: offer.color),
                    label: Text(offer.redemptionType.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.stars_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text('${_formatPoints(offer.examplePoints)} puan'),
                    subtitle: Text(
                      walletLoading
                          ? 'Bakiye yükleniyor…'
                          : walletError
                          ? 'Bakiye alınamadı. Cüzdanı yenile.'
                          : 'Bakiyen: ${_formatPoints(balance)} puan',
                    ),
                  ),
                  _OfferTerms(offer: offer),
                  const SizedBox(height: 10),
                  Text(
                    offer.isDemo
                        ? 'Demo kayıt: bu kupon gerçek işletmede kullanılamaz. İşletme kullanımı uygulama tarafından doğrulanmıyor.'
                        : 'Kupon kullanımının doğrulaması işletme tarafından yapılır.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  if (!walletLoading &&
                      !walletError &&
                      balance < offer.examplePoints) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Bu ödül için ${_formatPoints(offer.examplePoints - balance)} puan daha gerekiyor.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ParkDesign.primaryButton(
                          Theme.of(context).brightness,
                        ),
                        foregroundColor: ParkDesign.primaryButtonForeground(
                          Theme.of(context).brightness,
                        ),
                      ),
                      onPressed:
                          !offer.isDemo ||
                              redeeming ||
                              demo == null ||
                              walletLoading ||
                              walletError ||
                              balance < offer.examplePoints
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onRedeem(offer);
                            },
                      child: Text(
                        demo == null
                            ? 'Kuponlar yükleniyor'
                            : walletLoading
                            ? 'Bakiye yükleniyor…'
                            : walletError
                            ? 'Bakiye kullanılamıyor'
                            : balance < offer.examplePoints
                            ? 'Yetersiz puan'
                            : !offer.isDemo
                            ? 'Kullanım henüz bağlanmadı'
                            : redeeming
                            ? 'Kupon ekleniyor…'
                            : 'Test kuponunu al',
                      ),
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
    final availableOffers = offers
        .where((offer) {
          final previous =
              demo?.coupons
                  .where((coupon) => coupon.offerId == offer.id)
                  .toList(growable: false) ??
              const <_DemoCoupon>[];
          if (previous.isEmpty) return true;
          if (!offer.allowRepeatPurchase) return false;
          return !previous.any((coupon) => coupon.effectiveStatus == 'active');
        })
        .toList(growable: false);
    return ListView(
      // Let the list move under the glass dock; retain enough scroll range so
      // the last offer can still be brought fully into view.
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 148),
      children: [
        const SizedBox(height: 14),
        _RewardsWalletCard(
          balance: wallet?.balance == null ? null : balance,
          loading: walletLoading,
          error: walletError,
          onTapMovements: () => _openMovements(context),
          onRefresh: onRefreshWallet,
        ),
        const SizedBox(height: 12),
        _MyCouponsButton(
          count: demo?.coupons.length ?? 0,
          onTap: () => _openCoupons(context),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ödül kataloğu',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Ödüller nasıl işler?',
              onPressed: () => _showRewardInfo(context),
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ],
        ),
        if (offersLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (offersError)
          _RewardsCatalogError(onRetry: onRetryOffers)
        else if (availableOffers.isEmpty)
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * .38).clamp(
              220.0,
              400.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.card_giftcard_outlined,
                  size: 58,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                Text(
                  offers.isEmpty
                      ? 'Şu anda ödül yok'
                      : 'Alınabilecek ödül kalmadı',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  offers.isEmpty
                      ? 'Yeni ödüller eklendiğinde burada görünecek.'
                      : 'Aldığın kuponları Kuponlarım’da görebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Material(
            color: Theme.of(context).colorScheme.brightness == Brightness.dark
                ? ParkDesign.darkCardSurface
                : ParkDesign.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ParkDesign.radius),
              side: BorderSide(
                color:
                    Theme.of(context).colorScheme.brightness == Brightness.dark
                    ? ParkDesign.darkGroupOutline
                    : ParkDesign.groupOutline,
              ),
            ),
            elevation: 1,
            shadowColor: Theme.of(context).colorScheme.shadow
                .withValues(alpha: .08),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < availableOffers.length;
                  index++
                ) ...[
                  _RewardCard(
                    offer: availableOffers[index],
                    balance: balance,
                    onTap: () =>
                        _showOfferDetails(context, availableOffers[index]),
                  ),
                  if (index < availableOffers.length - 1)
                    Divider(
                      height: 1,
                      indent: 66,
                      endIndent: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        const _RewardsTestNotice(),
      ],
    );
  }

  void _showRewardInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Puanlar nasıl kazanılır?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 14),
              Text(
                'Fotoğraflı boş yer bildirimi +10 puan kazandırır. Çıkıyorum bildiriminde bu puan fotoğraf eklendiğinde verilir.',
              ),
              SizedBox(height: 10),
              Text(
                'Başka bir sürücü bildiriminle park ettiğinde bildirimin sahibi +20 puan alır.',
              ),
              SizedBox(height: 10),
              Text('“Park ettim” onayını veren sürücü +10 puan alır.'),
              SizedBox(height: 10),
              Text(
                '“Yer doluydu” ve “Bulamadım” geri bildirimleri puan eklemez veya düşürmez.',
              ),
              SizedBox(height: 14),
              Text(
                'Ödül kartları örnektir. Gerçek kupon kullanımı işletme anlaşmalarından sonra açılacak.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
