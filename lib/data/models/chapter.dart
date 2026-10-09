import 'reel.dart';

/// A chapter groups reels by chapter/topic for the Library screen.
class Chapter {
  final String name;
  final List<Reel> reels;

  const Chapter({required this.name, this.reels = const []});

  List<Reel> get topics => reels.where((r) => !r.isProblem).toList();
  List<Reel> get problems => reels.where((r) => r.isProblem).toList();
}
