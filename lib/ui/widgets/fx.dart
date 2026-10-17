// Visual effects re-implemented in Flutter, inspired by Magic UI
// (https://github.com/magicuidesign/magicui, MIT License,
// Copyright (c) Magic UI). No Magic UI source code is copied; the effect
// ideas (shimmer text, aurora background, animated gradient border/beam,
// glow card, animated number) are rebuilt from scratch with Flutter
// animations. All painters are cheap (one controller each, RepaintBoundary).
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slowly drifting colored blobs behind the app (aurora-style).
class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 14))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
                painter: _AuroraPainter(_c.value, dark,
                    Theme.of(context).scaffoldBackgroundColor)),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool dark;
  final Color bg;
  _AuroraPainter(this.t, this.dark, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final a = t * 2 * math.pi;
    final blobs = <(Offset, Color, double)>[
      (Offset(size.width * (0.2 + 0.15 * math.sin(a)), size.height * 0.15),
          const Color(0xFF7C5CFF), size.width * 0.8),
      (Offset(size.width * (0.85 + 0.1 * math.cos(a)), size.height * (0.35 + 0.08 * math.sin(a))),
          const Color(0xFF00C2FF), size.width * 0.7),
      (Offset(size.width * (0.4 + 0.2 * math.cos(a + 1)), size.height * 0.85),
          const Color(0xFFFF4DA6), size.width * 0.75),
    ];
    for (final (c, color, r) in blobs) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: dark ? 0.22 : 0.16),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: c, radius: r)));
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.dark != dark;
}

/// Text with a light sweep passing over it.
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const ShimmerText(this.text, {super.key, this.style});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    final hi = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(
          colors: [base, hi, base],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.5 + 3 * _c.value, 0),
          end: Alignment(-0.5 + 3 * _c.value, 0),
        ).createShader(r),
        child: child,
      ),
      child: Text(widget.text, style: widget.style),
    );
  }
}

/// Card with a rotating gradient border (animated beam) and soft glow.
class GlowCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool animate;
  const GlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    this.onTap,
    this.animate = false,
  });

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: widget.margin,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: SweepGradient(
                transform: GradientRotation(_c.value * 2 * math.pi),
                colors: [
                  cs.primary.withValues(alpha: 0.15),
                  cs.primary,
                  const Color(0xFF00C2FF),
                  cs.primary.withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                    color: cs.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    spreadRadius: 0),
              ],
            ),
            padding: const EdgeInsets.all(1.5),
            child: child,
          ),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18.5),
            child: InkWell(
              borderRadius: BorderRadius.circular(18.5),
              onTap: widget.onTap,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Number that counts up to [value].
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCount(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('${v.round()}', style: style),
      );
}

/// Progress bar with a moving highlight beam.
class BeamProgress extends StatefulWidget {
  final double? value;
  const BeamProgress({super.key, this.value});

  @override
  State<BeamProgress> createState() => _BeamProgressState();
}

class _BeamProgressState extends State<BeamProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
              painter: _BeamPainter(widget.value, _c.value, cs.primary,
                  cs.surfaceContainerHighest)),
        ),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double? v;
  final double t;
  final Color fg, bg;
  _BeamPainter(this.v, this.t, this.fg, this.bg);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = bg);
    final w = s.width * (v ?? 1.0).clamp(0.0, 1.0);
    final r = Rect.fromLTWH(0, 0, w, s.height);
    canvas.drawRect(r, Paint()..color = fg);
    final bx = (t * 1.4 - 0.2) * s.width;
    canvas.save();
    canvas.clipRect(r);
    canvas.drawRect(
        Rect.fromLTWH(bx - 40, 0, 80, s.height),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0),
          ]).createShader(Rect.fromLTWH(bx - 40, 0, 80, s.height)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeamPainter o) => o.t != t || o.v != v;
}
