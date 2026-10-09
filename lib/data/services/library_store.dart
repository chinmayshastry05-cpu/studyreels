import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chapter.dart';
import '../models/reel.dart';

/// The on-device library: reels grouped by chapter/topic, persisted as
/// local JSON. No cloud, no analytics.
class LibraryStore extends ChangeNotifier {
  static const String fileName = 'library.json';

  /// Set false in unit tests to skip file IO (path_provider needs native).
  final bool persist;
  final List<Reel> _reels = [];

  LibraryStore({this.persist = true});

  List<Reel> get reels => List.unmodifiable(_reels);

  List<Chapter> get chapters {
    final byChapter = <String, List<Reel>>{};
    for (final r in _reels) {
      byChapter.putIfAbsent(r.chapter, () => []).add(r);
    }
    return byChapter.entries
        .map((e) => Chapter(name: e.key, reels: e.value))
        .toList();
  }

  Future<void> load() async {
    if (!persist) return;
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is List) {
        _reels
          ..clear()
          ..addAll(raw.map(
              (e) => Reel.fromJson(e as Map<String, dynamic>)));
        notifyListeners();
      }
    } catch (_) {
      // Corrupt library file: start empty rather than crash.
      _reels.clear();
    }
  }

  Future<void> addReel(Reel reel) async {
    _reels.add(reel);
    notifyListeners();
    await _save();
  }

  Future<void> addReels(Iterable<Reel> reels) async {
    _reels.addAll(reels);
    notifyListeners();
    await _save();
  }

  Future<void> removeReel(String id) async {
    _reels.removeWhere((r) => r.id == id);
    notifyListeners();
    await _save();
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<void> _save() async {
    if (!persist) return;
    try {
      final file = await _file();
      await file.writeAsString(
          jsonEncode(_reels.map((r) => r.toJson()).toList()));
    } catch (_) {
      // Best effort: the in-memory library still works.
    }
  }
}
