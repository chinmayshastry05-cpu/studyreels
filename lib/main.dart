import 'package:flutter/material.dart';

import 'ui/screens/feed_screen.dart';
import 'ui/screens/import_screen.dart';
import 'ui/screens/library_screen.dart';

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
      home: const HomeShell(),
    );
  }
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
