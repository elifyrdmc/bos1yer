part of '../main.dart';

/// Marka ve park durumu renklerini tek yerden ayarlamak için renk tokenları.
class ParkIstPalette {
  static const cornflower = ParkDesign.green;
  static const oceanTeal = ParkDesign.green;
  static const forestGreen = ParkDesign.greenBright;
  static const actionGreen = ParkDesign.green;
  static const lightGreen = ParkDesign.greenSoft;
  static const navigationBlue = ParkDesign.green;
  static const rewardPurple = ParkDesign.plum;
  static const paleRose = ParkDesign.lavender;
  static const lightBackground = ParkDesign.paper;
  static const darkBackground = ParkDesign.darkPage;
  static const lightSurface = Colors.white;
  static const darkSurface = ParkDesign.darkSurface;
  static const darkCornflower = ParkDesign.buttonGreenDark;

  // Durum renkleri haritada ve bilgi kartlarında kullanılacak.
  static const available = Color(0xFF438A62); // ücretsiz / boş durum
  static const darkAvailable = Color(0xFF72BE8F);
  static const review = Color(0xFFAA7625); // yumuşak kehribar
  static const restricted = Color(0xFFB65C55); // kiremit-koral
  static const staleReport = Color(
    0xFFFF7029,
  ); // eski bildirim · mango turuncusu
  static const unconfirmedLeaving = Color(0xFFFFD576); // ayçiçeği sarısı
  static const darkReview = Color(0xFFE2B85F);
  static const darkRestricted = Color(0xFFE58B82);
}

class ParkIstApp extends StatelessWidget {
  const ParkIstApp({super.key, this.bootstrapError});

  final Object? bootstrapError;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: AppAppearance.mode,
    builder: (context, mode, _) => MaterialApp(
      title: 'BOŞ1YER',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ParkDesign.theme(Brightness.light),
      darkTheme: ParkDesign.theme(Brightness.dark),
      home: _AuthGate(bootstrapError: bootstrapError),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
  }

  void _openPage(String title, Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: false,
            toolbarHeight: 70,
            title: Text(title),
            titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
            leadingWidth: 62,
            leading: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Material(
                color: ParkIstPalette.cornflower.withValues(alpha: .16),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Geri',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final navBackground =
        Theme.of(context).colorScheme.brightness == Brightness.dark
        ? const Color(0xFF252B27)
        : const Color(0xFFEFF7F1);

    return Scaffold(
      // Keep the map, availability drawer and dock anchored when the native
      // system keyboard opens for the inline map search field.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                SafeArea(
                  bottom: false,
                  child: _MapIntroduction(
                    isActive: _selectedTab == 0,
                    onOpenProfile: () => _selectTab(2),
                    onStartReport: (request) async {
                      if (request.typeIndex < 2) {
                        final reportType = request.typeIndex == 0
                            ? 'Boş yer bildir'
                            : 'Çıkıyorum';
                        return Navigator.of(context).push<_DemoMapPin>(
                          MaterialPageRoute<_DemoMapPin>(
                            builder: (context) =>
                                _PhotoStepPage(reportType: reportType),
                          ),
                        );
                      } else {
                        _openPage(
                          'Bildirim ekle',
                          _AddPage(initialTypeIndex: request.typeIndex - 2),
                        );
                        return null;
                      }
                    },
                  ),
                ),
                Scaffold(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? ParkDesign.darkPage
                      : ParkDesign.white,
                  appBar: _tabAppBar(context, 'Ödüller'),
                  body: const _RewardsPage(),
                ),
                Scaffold(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? ParkDesign.darkPage
                      : ParkDesign.white,
                  appBar: _tabAppBar(context, 'Profil'),
                  body: const ProfileSettingsPage(),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: bottomInset + 6,
            child: _CompactNavigationDock(
              selectedIndex: _selectedTab,
              onSelected: _selectTab,
              pageTint: _selectedTab == 0 ? null : navBackground,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _tabAppBar(BuildContext context, String title) => AppBar(
    automaticallyImplyLeading: false,
    centerTitle: false,
    toolbarHeight: 70,
    title: Text(title),
    titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w800,
      letterSpacing: -.4,
    ),
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? ParkDesign.darkPage
        : ParkDesign.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  );
}
