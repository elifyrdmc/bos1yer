part of '../main.dart';

class _AddPage extends StatefulWidget {
  const _AddPage({this.initialTypeIndex = 0});

  final int initialTypeIndex;

  @override
  State<_AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<_AddPage> {
  late int _selected = widget.initialTypeIndex.clamp(0, _types.length - 1);
  static const _types = [
    ('Boş yer bildir', Icons.event_available_outlined),
    ('Çıkıyorum', Icons.logout_rounded),
    ('Park alanı ekle', Icons.add_location_alt_outlined),
    ('Dolu yer bildir', Icons.directions_car_filled_outlined),
    ('Kısıtlama bildir', Icons.block_outlined),
    ('Eski/yanlış bilgiyi bildir', Icons.report_outlined),
  ];
  static const _descriptions = [
    'Yeni gördüğün boş yeri fotoğraf ve konumla paylaş.',
    'Ayrıldığın yeri kısa süreliğine sürücülere haber ver.',
    'Genel park bilgisini ekle; boş yer garantisi değildir.',
    'Daha önce boş görünen yerin artık dolu olduğunu bildir.',
    'Geçici engel veya park kısıtlamasını paylaş.',
    'Haritadaki eski ya da yanlış bilgiyi işaretle.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstUseHints.showOnce(
        context,
        key: 'first_use_add_report_hint',
        title: 'İlk bildirimin nasıl eklenir?',
        message: 'Boş yer veya Çıkıyorum seç. Fotoğraf ve konum adımlarında bilgiyi kontrol edip bildirimi paylaşabilirsin.',
        icon: Icons.lightbulb_outline_rounded,
      );
    });
  }

  Future<void> _continueToPhoto() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _PhotoStepPage(reportType: _types[_selected].$1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 21),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer
                .withValues(alpha: .72),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOPLULUĞA KATKI',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: .72),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ne gördün?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Park bilgisini seç; fotoğraf ve konum adımlarında birlikte doğrulayalım.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: .76),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < _types.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: _selected == i ? ParkIstPalette.oceanTeal : colors.surface,
              borderRadius: BorderRadius.circular(25),
              child: InkWell(
                onTap: () => setState(() => _selected = i),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: _selected == i
                          ? Colors.transparent
                          : ParkIstPalette.oceanTeal.withValues(alpha: .1),
                    ),
                    boxShadow: _selected == i
                        ? const [
                            BoxShadow(
                              color: Color(0x2232495D),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : const [],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _selected == i
                              ? Colors.white.withValues(alpha: .15)
                              : ParkIstPalette.cornflower.withValues(
                                  alpha: .17,
                                ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _types[i].$2,
                          color: _selected == i
                              ? Colors.white
                              : ParkIstPalette.oceanTeal,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _types[i].$1,
                              style: TextStyle(
                                color: _selected == i
                                    ? Colors.white
                                    : ParkIstPalette.oceanTeal,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _descriptions[i],
                              style: TextStyle(
                                color: _selected == i
                                    ? Colors.white.withValues(alpha: .76)
                                    : ParkIstPalette.oceanTeal.withValues(
                                        alpha: .67,
                                      ),
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _selected == i
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: _selected == i
                            ? Colors.white
                            : ParkIstPalette.cornflower,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _continueToPhoto,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Fotoğraf adımına geç'),
          style: FilledButton.styleFrom(
            backgroundColor: ParkDesign.primaryButton(
              Theme.of(context).brightness,
            ),
            foregroundColor: ParkDesign.primaryButtonForeground(
              Theme.of(context).brightness,
            ),
            minimumSize: const Size.fromHeight(58),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
