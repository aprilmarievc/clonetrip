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
import 'models/itinerary.dart';

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

    TextTheme interTitlesOnly(TextTheme base) {
      // Ensure Inter is used by default across all text styles
      const List<String> fallback = ['Inter', 'sans-serif'];
      return base.copyWith(
        displayLarge: base.displayLarge?.copyWith(fontFamilyFallback: fallback),
        displayMedium: base.displayMedium?.copyWith(
          fontFamilyFallback: fallback,
        ),
        displaySmall: base.displaySmall?.copyWith(fontFamilyFallback: fallback),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamilyFallback: fallback,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamilyFallback: fallback,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontFamilyFallback: fallback,
        ),
        titleLarge: base.titleLarge?.copyWith(fontFamilyFallback: fallback),
        titleMedium: base.titleMedium?.copyWith(fontFamilyFallback: fallback),
        titleSmall: base.titleSmall?.copyWith(fontFamilyFallback: fallback),
        bodyLarge: base.bodyLarge?.copyWith(fontFamilyFallback: fallback),
        bodyMedium: base.bodyMedium?.copyWith(fontFamilyFallback: fallback),
        bodySmall: base.bodySmall?.copyWith(fontFamilyFallback: fallback),
        labelLarge: base.labelLarge?.copyWith(fontFamilyFallback: fallback),
        labelMedium: base.labelMedium?.copyWith(fontFamilyFallback: fallback),
        labelSmall: base.labelSmall?.copyWith(fontFamilyFallback: fallback),
      );
    }

    final TextTheme interLight = GoogleFonts.interTextTheme().apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );
    final ThemeData baseLight = ThemeData(
      colorScheme: colorSchemeLight,
      scaffoldBackgroundColor: Colors.white,
      textTheme: interTitlesOnly(interLight),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          // Use Inter for all app bar titles by default (light)
          fontFamily: 'Inter',
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
              textTheme: interTitlesOnly(interDark),
              cardColor: Colors.white.withOpacity(0.10),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  // Use Inter for all app bar titles by default (dark)
                  fontFamily: 'Inter',
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

Future<String> _ensureUid() async {
  final auth = FirebaseAuth.instance;
  final current = auth.currentUser;
  if (current != null) return current.uid;
  final cred = await auth.signInAnonymously();
  if (cred.user == null) {
    throw Exception('Sign-in failed');
  }
  return cred.user!.uid;
}

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
      const _TimelinePage(),
      const _WishlistPage(),
      const _GroupsPage(),
    ];

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            // Use special font only for the literal home title 'Clone Trip'
            if (widget.title == 'Clone Trip') {
              return const Text(
                'Clone Trip',
                style: TextStyle(
                  fontFamily: 'Tan Mon Cheri',
                  fontFamilyFallback: ['Inter', 'sans-serif'],
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              );
            }
            return Text(widget.title);
          },
        ),
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
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Timeline',
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

class _TimelinePage extends StatelessWidget {
  const _TimelinePage();

  @override
  Widget build(BuildContext context) {
    final data = DataServiceScope.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo';
    return StreamBuilder(
      stream: data.watchItineraries(userId), // all itineraries
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        // Build map year -> month -> itineraries
        String ymOf(Itinerary t) {
          final iso = t.startDateIso ?? t.endDateIso;
          if (iso == null || iso.length < 7) return 'Unknown';
          return iso.substring(0, 7); // YYYY-MM
        }

        String yOf(String ym) => ym.length >= 4 ? ym.substring(0, 4) : ym;
        String mOf(String ym) => ym.length >= 7 ? ym.substring(5, 7) : '';
        const months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];

        final Map<String, Map<String, List<Itinerary>>> byYearMonth = {};
        for (final t in items) {
          final ym = ymOf(t);
          final y = yOf(ym);
          final m = mOf(ym);
          final yMap = byYearMonth.putIfAbsent(y, () => {});
          (yMap[m] ??= <Itinerary>[]).add(t);
        }

        final years = byYearMonth.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // recent year first

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Vertical axis with year left and months right
            for (final y in years) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      y,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // axis line
                  Container(
                    width: 2,
                    height: 8,
                    color: Theme.of(context).dividerColor,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // months for this year (descending)
              Builder(
                builder: (ctx) {
                  final monthsMap = byYearMonth[y]!;
                  final monthKeys = monthsMap.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  return Column(
                    children: [
                      for (final m in monthKeys) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 72),
                            // axis line extended
                            Container(
                              width: 2,
                              height: 24,
                              color: Theme.of(context).dividerColor,
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: Text(
                                m.isEmpty
                                    ? ''
                                    : months[(int.tryParse(m) ?? 1) - 1],
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final t in monthsMap[m]!)
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ItineraryEditorPage(
                                              itineraryId: t.id,
                                              title: t.title,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(t.title),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
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
            // Current Trip quick-add section (above Current Itineraries)
            Builder(
              builder: (ctx) {
                final current = items.where((t) => t.isCurrent).toList();
                if (current.isEmpty) return const SizedBox.shrink();
                final trip = current.first;
                final titleCtrl = TextEditingController();
                final priceCtrl = TextEditingController();
                return Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Trip: ${trip.title}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double total = constraints.maxWidth;
                            // Reserve ~110 for price and ~84 for button and small gaps
                            final double titleWidth = total - 110 - 84 - 24;
                            // Ensure non-negative, normalized constraints for the text field
                            final double fieldMaxWidth =
                                (titleWidth.isFinite ? titleWidth : total)
                                    .clamp(0.0, total)
                                    .toDouble();
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: fieldMaxWidth,
                                  ),
                                  child: TextField(
                                    controller: titleCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Add location or activity',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: priceCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'USD',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () async {
                                    final title = titleCtrl.text.trim();
                                    if (title.isEmpty) return;
                                    final price = double.tryParse(
                                      priceCtrl.text.trim(),
                                    );
                                    // Compute correct day: today if within trip window
                                    DateTime today = DateTime.now();
                                    DateTime? start = DateTime.tryParse(
                                      trip.startDateIso ?? '',
                                    );
                                    DateTime? end = DateTime.tryParse(
                                      trip.endDateIso ?? '',
                                    );
                                    String toYmd(DateTime d) {
                                      final mm = d.month.toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      final dd = d.day.toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      return '${d.year}-$mm-$dd';
                                    }

                                    String dayIso;
                                    if (start != null && end != null) {
                                      final DateTime dayOnly = DateTime(
                                        today.year,
                                        today.month,
                                        today.day,
                                      );
                                      if (dayOnly.isBefore(start)) {
                                        dayIso = toYmd(start);
                                      } else if (dayOnly.isAfter(end)) {
                                        dayIso = toYmd(end);
                                      } else {
                                        dayIso = toYmd(dayOnly);
                                      }
                                    } else if (start != null) {
                                      dayIso = toYmd(start);
                                    } else {
                                      final DateTime dayOnly = DateTime(
                                        today.year,
                                        today.month,
                                        today.day,
                                      );
                                      dayIso = toYmd(dayOnly);
                                    }
                                    await data.quickAddActivityAndExpense(
                                      itineraryId: trip.id,
                                      title: title,
                                      dayIso: dayIso,
                                      priceUsd: price,
                                    );
                                    titleCtrl.clear();
                                    priceCtrl.clear();
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const _ProfileHeader(),
            const SizedBox(height: 16),
            const _SectionTitle('Current Itineraries'),
            const SizedBox(height: 8),
            for (final t in items)
              _TripCardMock(
                title: t.title,
                countryCode: t.countryCode,
                cities: t.cities,
                datesLabel: (t.startDateIso != null && t.endDateIso != null)
                    ? '${t.startDateIso} - ${t.endDateIso}'
                    : (t.startDateIso ?? t.endDateIso ?? ''),
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
                        onSubmit: ({
                          required String title,
                          String? countryCode,
                          List<String>? cities,
                          String? startDateIso,
                          String? endDateIso,
                        }) async {
                          await data.createItinerary(
                            userId: userId,
                            title: title,
                            countryCode: countryCode,
                            cities: cities,
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
                cities: t.cities,
                datesLabel: (t.startDateIso != null && t.endDateIso != null)
                    ? '${t.startDateIso} - ${t.endDateIso}'
                    : (t.startDateIso ?? t.endDateIso ?? ''),
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
                        onSubmit: ({
                          required String title,
                          String? countryCode,
                          List<String>? cities,
                          String? startDateIso,
                          String? endDateIso,
                        }) async {
                          await data.createItinerary(
                            userId: userId,
                            title: title,
                            countryCode: countryCode,
                            cities: cities,
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
                      InkWell(
                        onTap: () async {
                          final nameCtrl = TextEditingController(
                            text: displayName,
                          );
                          final countryCtrl = TextEditingController(text: code);
                          await showDialog(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                title: const Text('Edit Traveler'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: nameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Display Name',
                                      ),
                                    ),
                                    TextField(
                                      controller: countryCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Country Code (e.g., US)',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      await data.updateUserProfile(
                                        userId: userId,
                                        updates: {
                                          'displayName': nameCtrl.text.trim(),
                                          'countryCode': countryCtrl.text
                                              .trim()
                                              .toUpperCase(),
                                        },
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: _UserNameWithFlag(
                          name: displayName,
                          countryCode: code,
                        ),
                      ),
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
    required this.cities,
    required this.datesLabel,
    this.onTap,
  });

  final String title;
  final String countryCode;
  final List<String> cities;
  final String datesLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: (countryCode.trim().length == 2)
            ? Text(
                _countryCodeToEmoji(countryCode),
                style: const TextStyle(fontSize: 24),
              )
            : const Icon(Icons.place_outlined),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cities.isNotEmpty)
              Text(cities.join(', ')),
            if ((datesLabel).isNotEmpty)
              Text(datesLabel),
          ],
        ),
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
