import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'data/services/library_store.dart';
import 'data/services/model_store.dart';
import 'ui/screens/feed_screen.dart';
import 'ui/screens/import_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/model_missing_screen.dart';
import 'ui/screens/permissions_screen.dart';
import 'ui/widgets/fx.dart';

void main() {
  runApp(const StudyReelsApp());
}

ThemeData _buildTheme(Brightness brightness) {
  const seed = Color(0xFF7C5CFF);
  final dark = brightness == Brightness.dark;
  final bg = dark ? const Color(0xFF0B0A12) : const Color(0xFFF6F4FF);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface.withValues(alpha: 0.85),
      indicatorColor: seed.withValues(alpha: 0.3),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

/// Light / dark / follow system. Toggle button lives in the home shell.
final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

class StudyReelsApp extends StatelessWidget {
  const StudyReelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'StudyReels',
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: mode,
        home: const StartupGate(),
      ),
    );
  }
}

/// Checks for the on-device LLM bundle before entering the app, then loads
/// the persisted library and provides it to the feed/library/import screens.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<_Startup> _startup;
  bool _onboarded = true;

  @override
  void initState() {
    super.initState();
    _startup = _runStartup();
  }

  Future<_Startup> _runStartup() async {
    _onboarded = await PermissionsScreen.isDone();
    final docs = await getApplicationDocumentsDirectory();
    final expected = ModelStore.expectedModelPath(docs.path);
    final present = await ModelStore.isModelPresent(docs.path) &&
        await ModelStore.isWhisperPresent(docs.path);
    final library = LibraryStore();
    if (present) {
      await library.load();
    }
    return _Startup(
        modelPresent: present,
        expectedPath: expected,
        library: library);
  }

  void _retry() {
    setState(() {
      _startup = _runStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Startup>(
      future: _startup,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final startup = snap.data!;
        if (!_onboarded) {
          return PermissionsScreen(onDone: _retry);
        }
        if (!startup.modelPresent) {
          return ModelMissingScreen(
            expectedPath: startup.expectedPath,
            onRecheck: _retry,
          );
        }
        return ChangeNotifierProvider.value(
          value: startup.library,
          child: const HomeShell(),
        );
      },
    );
  }
}

class _Startup {
  final bool modelPresent;
  final String expectedPath;
  final LibraryStore library;
  const _Startup({
    required this.modelPresent,
    required this.expectedPath,
    required this.library,
  });
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const FeedScreen(),
      const LibraryScreen(),
      ImportScreen(onDone: () => setState(() => _index = 0)),
    ];
    return Scaffold(
      extendBody: false,
      body: AuroraBackground(
        child: Theme(
          data: Theme.of(context)
              .copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: Stack(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child:
                  KeyedSubtree(key: ValueKey(_index), child: screens[_index]),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 4,
              right: 8,
              child: IconButton(
                tooltip: 'Light / dark',
                icon: Icon(Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () => themeMode.value =
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              selectedIcon: Icon(Icons.play_circle),
              label: 'Reels'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Library'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Import'),
        ],
      ),
    );
  }
}
