import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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

/// Checks for the on-device LLM bundle before entering the app.
/// Shows a clear "model missing" screen with the exact expected path.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<_ModelCheck> _check;

  @override
  void initState() {
    super.initState();
    _check = _runCheck();
  }

  Future<_ModelCheck> _runCheck() async {
    final docs = await getApplicationDocumentsDirectory();
    final expected = ModelStore.expectedModelPath(docs.path);
    final present = await ModelStore.isModelPresent(docs.path);
    return _ModelCheck(present: present, expectedPath: expected);
  }

  void _recheck() {
    setState(() {
      _check = _runCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ModelCheck>(
      future: _check,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final check = snap.data!;
        if (!check.present) {
          return ModelMissingScreen(
            expectedPath: check.expectedPath,
            onRecheck: _recheck,
          );
        }
        return const HomeShell();
      },
    );
  }
}

class _ModelCheck {
  final bool present;
  final String expectedPath;
  const _ModelCheck({required this.present, required this.expectedPath});
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = <Widget>[
    FeedScreen(),
    LibraryScreen(),
    ImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
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
