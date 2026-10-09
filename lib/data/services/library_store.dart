import 'package:flutter/foundation.dart';

import '../models/chapter.dart';
import '../models/reel.dart';

/// Phase-1 in-memory library, grouped by chapter/topic.
/// Persistence (local JSON on device) is planned; no cloud, no analytics.
class LibraryStore extends ChangeNotifier {
  final List<Reel> _reels = [];

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

  void addReel(Reel reel) {
    _reels.add(reel);
    notifyListeners();
  }

  void removeReel(String id) {
    _reels.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
