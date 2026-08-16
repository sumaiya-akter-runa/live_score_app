import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small set of animation primitives shared by the auth pages so the
/// login and signup screens feel consistent. Kept in one file so tweaks
/// propagate to both pages automatically.

/// Wraps [child] in a press-down / release-up scale animation. Used for
/// every actionable button on the auth pages.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.95,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;

  void _setScale(double v) {
    if (_scale == v) return;
    setState(() => _scale = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setScale(widget.pressedScale),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Slides + fades in from below, optionally after a [delay] so multiple
/// widgets appear one after the other for a staggered effect.
class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.slideOffset = 24,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Opacity(
          opacity: _anim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _anim.value) * widget.slideOffset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animated background: two soft, slow-drifting radial blobs painted on top
/// of a base gradient. Cheap to render (uses a CustomPaint) and gives the
/// pages a "live" feeling without distracting from the form.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(_ctrl.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double t; // 0..1
  _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base gradient.
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFF8E1)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    // Two drifting blobs. Their centers travel along Lissajous-ish paths.
    final phase = t * 2 * math.pi;
    final blob1X = w * (0.25 + 0.15 * math.sin(phase));
    final blob1Y = h * (0.20 + 0.10 * math.cos(phase));
    final blob2X = w * (0.75 + 0.10 * math.cos(phase));
    final blob2Y = h * (0.80 + 0.12 * math.sin(phase));

    final blob1 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.deepOrange.withOpacity(0.18),
          Colors.deepOrange.withOpacity(0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: Offset(blob1X, blob1Y), radius: w * 0.55));
    canvas.drawCircle(Offset(blob1X, blob1Y), w * 0.55, blob1);

    final blob2 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.purple.withOpacity(0.12),
          Colors.purple.withOpacity(0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: Offset(blob2X, blob2Y), radius: w * 0.5));
    canvas.drawCircle(Offset(blob2X, blob2Y), w * 0.5, blob2);
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => old.t != t;
}

/// A horizontal divider with "or" in the middle, used to separate the
/// email/password form from the social login button.
class OrDivider extends StatelessWidget {
  final String label;
  const OrDivider({super.key, this.label = 'or'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(thickness: 1)),
      ],
    );
  }
}

/// Inline Google "G" logo so the "Continue with Google" button doesn't need
/// any extra asset bundling. Aesthetic only; not the official mark.
class GoogleGLogo extends StatelessWidget {
  final double size;
  const GoogleGLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _GLogoPainter()),
    );
  }
}

class _GLogoPainter extends CustomPainter {
  const _GLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    // Background ring.
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF4285F4));
    // White inner area.
    canvas.drawCircle(
        center,
        r * 0.78,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    // The "G" letter approximated with a thick arc + a horizontal bar.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, 6.0, false, arc);
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
        Rect.fromLTWH(center.dx, center.dy - r * 0.14, r * 0.6, r * 0.28), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
