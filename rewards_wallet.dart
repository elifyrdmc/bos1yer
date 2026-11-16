part of '../main.dart';

class _RewardsWalletCard extends StatelessWidget {
  const _RewardsWalletCard({
    required this.balance,
    required this.loading,
    required this.error,
    required this.onTapMovements,
    required this.onRefresh,
  });

  final int? balance;
  final bool loading;
  final bool error;
  final VoidCallback onTapMovements;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: BoxDecoration(
        color: dark ? ParkDesign.darkLavender : ParkDesign.lavender,
        borderRadius: BorderRadius.circular(ParkDesign.radius),
        border: Border.all(
          color: dark
              ? const Color(0xFF54485D)
              : ParkDesign.plum.withValues(alpha: .14),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: dark ? .12 : .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CÜZDANIM',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: dark ? ParkDesign.darkInk : ParkDesign.plum,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bakiyeyi yenile',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            loading
                ? '…'
                : error
                ? '—'
                : _formatPoints(balance ?? 0),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 36,
              color: dark ? ParkDesign.darkInk : ParkDesign.plum,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ödül puanı',
            style: TextStyle(
              color: dark ? ParkDesign.darkMuted : ParkDesign.plum,
            ),
          ),
          if (error) ...[
            const SizedBox(height: 8),
            Text(
              'Bakiye yüklenemedi. Yenilemeyi dene.',
              style: TextStyle(color: colors.error),
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            color: (dark ? ParkDesign.darkInk : ParkDesign.plum).withValues(
              alpha: .2,
            ),
            height: 1,
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onTapMovements,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                foregroundColor: dark ? ParkDesign.darkInk : ParkDesign.plum,
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hareketlerim',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyCouponsButton extends StatelessWidget {
  const _MyCouponsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.brightness == Brightness.dark
          ? ParkDesign.darkCardSurface
          : ParkDesign.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colors.brightness == Brightness.dark
              ? ParkDesign.darkGroupOutline
              : ParkDesign.groupOutline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(Icons.confirmation_number_outlined, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kuponlarım',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$count kupon',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletMovementView {
  const _WalletMovementView({
    required this.description,
    required this.pointsDelta,
    required this.createdAt,
    required this.isTest,
    required this.balanceAfter,
  });

  final String description;
  final int pointsDelta;
  final DateTime createdAt;
  final bool isTest;
  final int balanceAfter;
}

class _RewardsWalletPage extends StatefulWidget {
  const _RewardsWalletPage({
    required this.wallet,
    required this.balanceAdjustment,
    required this.testMovements,
    required this.loadWallet,
  });

  final PointsWallet? wallet;
  final int balanceAdjustment;
  final List<_DemoMovement> testMovements;
  final Future<PointsWallet?> Function() loadWallet;

  @override
  State<_RewardsWalletPage> createState() => _RewardsWalletPageState();
}

class _RewardsWalletPageState extends State<_RewardsWalletPage> {
  late PointsWallet? _wallet = widget.wallet;
  bool _loading = false;
  String _movementFilter = 'Tümü';

  int get _balance => (_wallet?.balance ?? 0) + widget.balanceAdjustment;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final refreshed = await widget.loadWallet();
    if (!mounted) return;
    setState(() {
      _wallet = refreshed;
      _loading = false;
    });
  }

  List<_WalletMovementView> _movementRows() {
    final rows = <_WalletMovementView>[
      for (final item in _wallet?.transactions ?? const <PointsTransaction>[])
        _WalletMovementView(
          description: item.description,
          pointsDelta: item.pointsDelta,
          createdAt: item.createdAt,
          isTest: false,
          balanceAfter: 0,
        ),
      for (final item in widget.testMovements)
        _WalletMovementView(
          description: item.description,
          pointsDelta: item.pointsDelta,
          createdAt: item.createdAt,
          isTest: true,
          balanceAfter: 0,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    var runningBalance = _balance;
    return [
      for (final row in rows)
        () {
          final withBalance = _WalletMovementView(
            description: row.description,
            pointsDelta: row.pointsDelta,
            createdAt: row.createdAt,
            isTest: row.isTest,
            balanceAfter: runningBalance,
          );
          runningBalance -= row.pointsDelta;
          return withBalance;
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _movementRows();
    final visibleRows = rows
        .where((movement) {
          return switch (_movementFilter) {
            'Kazandıklarım' => movement.pointsDelta > 0,
            'Harcadıklarım' => movement.pointsDelta < 0,
            _ => true,
          };
        })
        .toList(growable: false);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hareketlerim'),
        actions: [
          IconButton(
            tooltip: 'Hareketleri yenile',
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Text(
            'Puan bakiyesi: ${_wallet == null ? '—' : _formatPoints(_balance)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: ParkDesign.green.withValues(
                  alpha: .12,
                ),
                selectedForegroundColor: colors.onSurface,
                minimumSize: const Size(0, 44),
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(
                  value: 'Tümü',
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Tümü')),
                ),
                ButtonSegment(
                  value: 'Kazandıklarım',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Kazandıklarım'),
                  ),
                ),
                ButtonSegment(
                  value: 'Harcadıklarım',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Harcadıklarım'),
                  ),
                ),
              ],
              selected: {_movementFilter},
              onSelectionChanged: (selection) =>
                  setState(() => _movementFilter = selection.first),
            ),
          ],
          const SizedBox(height: 12),
          if (_wallet == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Puan hareketleri alınamadı. Yenilemek için üstteki simgeye dokun.',
              ),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Henüz puan hareketi yok.'),
            )
          else if (visibleRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _movementFilter == 'Kazandıklarım'
                    ? 'Henüz kazanılan puan hareketi yok.'
                    : 'Henüz harcanan puan hareketi yok.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
              child: Column(
                children: [
                  for (final movement in visibleRows)
                    _WalletMovementTile(movement: movement),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const _RewardsTestNotice(),
        ],
      ),
    );
  }
}

class _WalletMovementTile extends StatelessWidget {
  const _WalletMovementTile({required this.movement});

  final _WalletMovementView movement;

  @override
  Widget build(BuildContext context) {
    final positive = movement.pointsDelta > 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: positive
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          positive ? Icons.add_rounded : Icons.remove_rounded,
          color: positive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      ),
      title: Text(movement.description),
      subtitle: Text(
        '${movement.isTest ? 'TEST · ' : ''}${_formatTransactionDate(movement.createdAt)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatPointsDelta(movement.pointsDelta),
            style: TextStyle(
              color: positive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Bakiye ${_formatPoints(movement.balanceAfter)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
