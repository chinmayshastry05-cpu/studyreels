// StudyReels visual language: black + saffron-gold, soft rounded shapes,
// calm motion. Effect ideas (shimmer sweep, aurora glow, animated gradient
// border) are inspired by Magic UI (https://github.com/magicuidesign/magicui,
// MIT License) and re-implemented from scratch with Flutter animations.
// No Magic UI source code is copied. Painters are cheap: one controller
// each, RepaintBoundary, low alphas.
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppColors {
  static const gold = Color(0xFFF5B301);
  static const goldBright = Color(0xFFFFCB3D);
  static const goldDeep = Color(0xFF9C6D00);
  static const darkSurface = Color(0xFF141416);
  static const darkCard = Color(0xFF17171B);
}

/// Warm, barely-there glow behind the app. Dark: gold embers on black.
/// Light: soft warm wash. Slow 22s drift so it feels alive, not noisy.
class AmbientBackground extends StatefulWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 22))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) =>
                CustomPaint(painter: _AmbientPainter(_c.value, dark, bg)),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class _AmbientPainter extends CustomPainter {
  final double t;
  final bool dark;
  final Color bg;
  _AmbientPainter(this.t, this.dark, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final a = t * 2 * math.pi;
    final blobs = <(Offset, Color, double, double)>[
      // (center, color, radius, alpha)
      (
        Offset(size.width * (0.85 + 0.08 * math.cos(a)), -size.height * 0.05),
        AppColors.gold,
        size.width * 0.9,
        dark ? 0.10 : 0.12,
      ),
      (
        Offset(size.width * (0.1 + 0.06 * math.sin(a)), size.height * 1.02),
        const Color(0xFFFF8A00),
        size.width * 0.8,
        dark ? 0.07 : 0.08,
      ),
    ];
    for (final (c, color, r, alpha) in blobs) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: c, radius: r)));
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.t != t || old.dark != dark;
}

/// Text with a soft light sweep passing over it (gold highlight).
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
    const hi = AppColors.goldBright;
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

/// Primary call-to-action: full-width gold pill with a shimmer sweep.
class GoldButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const GoldButton({super.key, required this.label, this.icon, this.onPressed});

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? const [AppColors.goldBright, AppColors.gold]
                  : const [Color(0xFF3A3A3E), Color(0xFF2C2C30)],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6)),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: widget.onPressed,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(children: [
                  if (enabled)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        widthFactor: 0.35,
                        alignment:
                            Alignment(-3 + 6 * ((_c.value * 1.0)), 0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon,
                            size: 20,
                            color: enabled
                                ? Colors.black
                                : Colors.white38),
                        const SizedBox(width: 8),
                      ],
                      Text(widget.label,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? Colors.black
                                  : Colors.white38)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rounded card with a hairline border; [animate] adds a slow gold beam
/// travelling around the border plus a soft glow.
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
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final border = widget.animate
        ? null
        : Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08));
    return Padding(
      padding: widget.margin,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: border,
              gradient: widget.animate
                  ? SweepGradient(
                      transform: GradientRotation(_c.value * 2 * math.pi),
                      colors: [
                        AppColors.gold.withValues(alpha: 0.15),
                        AppColors.gold,
                        AppColors.goldBright,
                        AppColors.gold.withValues(alpha: 0.15),
                      ],
                    )
                  : null,
              boxShadow: widget.animate
                  ? [
                      BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.20),
                          blurRadius: 20)
                    ]
                  : null,
            ),
            padding: EdgeInsets.all(widget.animate ? 1.5 : 0),
            child: child,
          ),
          child: Material(
            color: cs.brightness == Brightness.dark
                ? AppColors.darkCard
                : cs.surface,
            borderRadius: BorderRadius.circular(widget.animate ? 20.5 : 22),
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.animate ? 20.5 : 22),
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

/// Progress bar: gold fill, rounded ends, moving light beam.
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
    final track = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
              painter: _BeamPainter(widget.value, _c.value, track)),
        ),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double? v;
  final double t;
  final Color track;
  _BeamPainter(this.v, this.t, this.track);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = track);
    final w = s.width * (v ?? 1.0).clamp(0.0, 1.0);
    final r = Rect.fromLTWH(0, 0, w, s.height);
    canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
                  colors: [AppColors.goldBright, AppColors.gold])
              .createShader(r));
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

/// Small label chip: TOPIC = filled gold; anything else = gold outline.
class AppChip extends StatelessWidget {
  final String label;
  final bool filled;
  const AppChip(this.label, {super.key, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? AppColors.gold : Colors.transparent,
        border: filled ? null : Border.all(color: AppColors.gold, width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: filled ? Colors.black : AppColors.gold)),
    );
  }
}

/// Rounded-square gold-tinted icon badge.
class GoldIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  const GoldIconBadge(this.icon, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: AppColors.gold, size: size * 0.5),
    );
  }
}
