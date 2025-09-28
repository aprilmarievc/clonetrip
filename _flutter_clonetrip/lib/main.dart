import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';
import 'data_service_scope.dart';
import 'pages/expenses_page.dart';
import 'widgets/qr_share_sheet.dart';
import 'package:country_flags/country_flags.dart';
import 'widgets/add_itinerary_sheet.dart';
import 'firebase_options.dart';
import 'pages/itinerary_editor_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Continue with mock data service fallback
  }
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (_) {}
  final dataService = await createDataService();
  runApp(MyApp(dataService: dataService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.dataService});

  final DataService dataService;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Sun/Moon themes
    final Color sunSeed = const Color(0xFFFF6A00); // bright orange
    final Color moonSeed = const Color(0xFF2D1B69); // dark purple-blue
    final Gradient sunriseGradient = const RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Color(0x3DFFFF00), // softer yellow core
        Color(0x66FF6A00), // softer orange aura
        Color(0x00FFFFFF), // fade to transparent over white
      ],
      stops: [0.0, 0.45, 1.0],
    );
    final Gradient nightGradient = const LinearGradient(
      colors: [Color(0xFF000000), Color(0xFF0D1B2A), Color(0xFF2D1B69)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final ColorScheme colorSchemeLight =
        ColorScheme.fromSeed(
          seedColor: sunSeed,
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFFFFA64D), // light orange for buttons
          secondary: const Color(0xFFFF6A00), // bright orange
          tertiary: const Color(0xFFFFFF00), // bright yellow
        );

    TextTheme applyBlackMangoToTitles(TextTheme base) {
      const String blackMango = 'Tan Mon Cheri';
      const List<String> fallback = ['Inter', 'sans-serif'];
      return base.copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        displayMedium: base.displayMedium?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        displaySmall: base.displaySmall?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontFamily: blackMango,
          fontFamilyFallback: fallback,
        ),
      );
    }

    final TextTheme interLight = GoogleFonts.interTextTheme().apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );
    final ThemeData baseLight = ThemeData(
      colorScheme: colorSchemeLight,
      scaffoldBackgroundColor: Colors.white,
      textTheme: applyBlackMangoToTitles(interLight),
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          fontFamily: 'Tan Mon Cheri',
          fontFamilyFallback: ['Inter', 'sans-serif'],
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      useMaterial3: true,
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        final app = MaterialApp(
          title: 'Clone Trip',
          theme: baseLight,
          darkTheme: (() {
            final TextTheme interDark = GoogleFonts.interTextTheme().apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            );
            return ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: moonSeed,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF0D1B2A),
              textTheme: applyBlackMangoToTitles(interDark),
              cardColor: Colors.white.withOpacity(0.10),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                titleTextStyle: const TextStyle(
                  fontFamily: 'Tan Mon Cheri',
                  fontFamilyFallback: ['Inter', 'sans-serif'],
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              useMaterial3: true,
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white.withOpacity(0.18),
              ),
            );
          })(),
          themeMode: mode,
          home: MyHomePage(
            title: 'Clone Trip',
            sunriseGradient: sunriseGradient,
            nightGradient: nightGradient,
          ),
          debugShowCheckedModeBanner: false,
        );
        return DataServiceScope(service: dataService, child: app);
      },
    );
  }
}

final ValueNotifier<ThemeMode> _themeMode = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.sunriseGradient,
    required this.nightGradient,
  });

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final Gradient sunriseGradient;
  final Gradient nightGradient;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedTabIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _MyTripsPage(),
      const _WishlistPage(),
      const _GroupsPage(),
    ];

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        actions: const [_ThemeModeToggle()],
      ),
      body: isDark
          ? Stack(
              children: [
                Container(
                  decoration: BoxDecoration(gradient: widget.nightGradient),
                ),
                CustomPaint(
                  painter: _StarfieldPainter(seed: 42, density: 0.0006),
                  size: Size.infinite,
                ),
                SafeArea(child: pages[_selectedTabIndex]),
              ],
            )
          : Stack(
              children: [
                Container(color: Colors.white),
                Container(
                  decoration: BoxDecoration(gradient: widget.sunriseGradient),
                ),
                SafeArea(child: pages[_selectedTabIndex]),
              ],
            ),
      // Maps feature currently disabled
      floatingActionButton: null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groups',
          ),
        ],
      ),
    );
  }
}

class _MyTripsPage extends StatelessWidget {
  const _MyTripsPage();

  @override
  Widget build(BuildContext context) {
    final data = DataServiceScope.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';
    return StreamBuilder(
      stream: data.watchItineraries(userId, wishlist: false),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _ProfileHeader(),
            const SizedBox(height: 16),
            const _SectionTitle('Current Itineraries'),
            const SizedBox(height: 8),
            for (final t in items)
              _TripCardMock(
                title: t.title,
                countryCode: t.countryCode,
                dates: t.startDateIso != null && t.endDateIso != null
                    ? '${t.startDateIso} - ${t.endDateIso}'
                    : 'Planned',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ItineraryEditorPage(
                        itineraryId: t.id,
                        title: t.title,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return AddItinerarySheet(
                        onSubmit:
                            ({
                              required String title,
                              required String countryCode,
                              String? startDateIso,
                              String? endDateIso,
                            }) async {
                              await data.createItinerary(
                                userId: userId,
                                title: title,
                                countryCode: countryCode,
                                startDateIso: startDateIso,
                                endDateIso: endDateIso,
                              );
                            },
                      );
                    },
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Trip'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WishlistPage extends StatelessWidget {
  const _WishlistPage();

  @override
  Widget build(BuildContext context) {
    final data = DataServiceScope.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';
    return StreamBuilder(
      stream: data.watchItineraries(userId, wishlist: true),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle('Wishlist'),
            const SizedBox(height: 8),
            for (final t in items)
              _TripCardMock(
                title: t.title,
                countryCode: t.countryCode,
                dates: 'Someday',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ItineraryEditorPage(
                        itineraryId: t.id,
                        title: t.title,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return AddItinerarySheet(
                        isWishlist: true,
                        onSubmit:
                            ({
                              required String title,
                              required String countryCode,
                              String? startDateIso,
                              String? endDateIso,
                            }) async {
                              await data.createItinerary(
                                userId: userId,
                                title: title,
                                countryCode: countryCode,
                                startDateIso: startDateIso,
                                endDateIso: endDateIso,
                                isWishlist: true,
                              );
                            },
                      );
                    },
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Wish'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupsPage extends StatelessWidget {
  const _GroupsPage();

  @override
  Widget build(BuildContext context) {
    final data = DataServiceScope.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';
    return StreamBuilder(
      stream: data.watchGroups(userId),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle('Groups'),
            const SizedBox(height: 8),
            for (final g in groups)
              Card(
                elevation: 0,
                color: Theme.of(context).cardColor,
                child: ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(g.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_2),
                        tooltip: 'Invite',
                        onPressed: () async {
                          final link = await data.createGroupInvite(g.id);
                          await QrShareSheet.show(
                            context,
                            title: g.name,
                            link: link,
                          );
                        },
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ExpensesStreamPage(
                          groupId: g.id,
                          groupName: g.name,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final controller = TextEditingController();
                  await showDialog(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Join Group'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Paste invite link or code',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final text = controller.text.trim();
                              String? groupId;
                              String? code;
                              final parts = text.split('/');
                              if (parts.length >= 2) {
                                groupId = parts[parts.length - 2];
                                code = parts.last;
                              } else if (text.contains(':')) {
                                final p = text.split(':');
                                groupId = p.first;
                                code = p.last;
                              } else {
                                // fallback assume only code with known group
                              }
                              if (groupId != null && code != null) {
                                final ok = await data.acceptGroupInvite(
                                  groupId: groupId,
                                  code: code,
                                  userId: userId,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!ok && ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid invite'),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Join'),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Join Group'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final data = DataServiceScope.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';
    return StreamBuilder(
      stream: data.watchUserProfile(userId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = profile?.displayName ?? 'Traveler';
        final code = profile?.countryCode ?? 'US';
        final subtitle =
            profile?.nextDestination ??
            profile?.recentTrip ??
            'Set your next destination';
        return Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(radius: 24, backgroundColor: Colors.white30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _UserNameWithFlag(name: displayName, countryCode: code),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserNameWithFlag extends StatelessWidget {
  const _UserNameWithFlag({required this.name, required this.countryCode});

  final String name;
  final String countryCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        CountryFlag.fromCountryCode(
          countryCode.toLowerCase(),
          height: 18,
          width: 24,
        ),
      ],
    );
  }
}

String _countryCodeToEmoji(String countryCode) {
  final base = 0x1F1E6 - 'A'.codeUnitAt(0);
  final chars = countryCode
      .toUpperCase()
      .codeUnits
      .map((c) => String.fromCharCode(base + c))
      .join();
  return chars;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _TripCardMock extends StatelessWidget {
  const _TripCardMock({
    required this.title,
    required this.countryCode,
    required this.dates,
    this.onTap,
  });

  final String title;
  final String countryCode;
  final String dates;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Text(
          _countryCodeToEmoji(countryCode),
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(title),
        subtitle: Text(dates),
        trailing: IconButton(
          icon: const Icon(Icons.qr_code_2),
          onPressed: () => QrShareSheet.show(
            context,
            title: title,
            link: 'https://example.com/trip/$title',
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ThemeModeToggle extends StatelessWidget {
  const _ThemeModeToggle();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ThemeMode>(
      icon: const Icon(Icons.brightness_6_outlined),
      tooltip: 'Theme',
      onSelected: (mode) => _themeMode.value = mode,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: ThemeMode.light,
          child: Row(
            children: [
              Icon(Icons.wb_sunny_outlined),
              SizedBox(width: 8),
              Text('Sun'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Row(
            children: [
              Icon(Icons.nightlight_round),
              SizedBox(width: 8),
              Text('Moon'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.system,
          child: Row(
            children: [
              Icon(Icons.settings_suggest_outlined),
              SizedBox(width: 8),
              Text('System'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.seed, this.density = 0.0005});

  final int seed;
  final double density; // stars per pixel

  @override
  void paint(Canvas canvas, Size size) {
    final int starCount = (size.width * size.height * density).toInt();
    final math.Random rng = math.Random(seed);
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < starCount; i++) {
      final double x = rng.nextDouble() * size.width;
      final double y = rng.nextDouble() * size.height;
      final double r = 0.4 + rng.nextDouble() * 0.9; // small stars
      final int alpha = 140 + rng.nextInt(116); // 140-255
      // vary color slightly between cool white and pale violet
      final bool violet = rng.nextBool();
      final Color color = violet
          ? Color.fromARGB(alpha, 220, 215, 255)
          : Color.fromARGB(alpha, 245, 245, 255);
      paint.color = color;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.density != density;
  }
}

class _ExpensesStreamPage extends StatelessWidget {
  const _ExpensesStreamPage({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    final data = DataServiceScope.of(context);
    return StreamBuilder(
      stream: data.watchExpenses(groupId),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? const [];
        return ExpensesPage(
          groupName: groupName,
          groupId: groupId,
          expenses: expenses,
        );
      },
    );
  }
}
