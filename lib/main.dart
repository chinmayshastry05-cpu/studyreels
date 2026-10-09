import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'data/services/library_store.dart';
import 'data/services/model_store.dart';
import 'ui/screens/feed_screen.dart';
import 'ui/screens/import_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/model_missing_screen.dart';

void main() {
  runApp(const StudyReelsApp());
}

class StudyReelsApp extends StatelessWidget {
  const StudyReelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyReels',
      theme: ThemeData.dark(useMaterial3: true),
      home: const StartupGate(),
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

  @override
  void initState() {
    super.initState();
    _startup = _runStartup();
  }

  Future<_Startup> _runStartup() async {
    final docs = await getApplicationDocumentsDirectory();
    final expected = ModelStore.expectedModelPath(docs.path);
    final present = await ModelStore.isModelPresent(docs.path);
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
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_arrow), label: 'Reels'),
          NavigationDestination(icon: Icon(Icons.folder), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.add), label: 'Import'),
        ],
      ),
    );
  }
}
