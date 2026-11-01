import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import '../i18n/i18n.dart';

enum BreathPhase { inhale, hold, exhale, rest }

String _phaseLabel(BreathPhase phase) => switch (phase) {
  BreathPhase.inhale => tr('breathOrb.breatheIn'),
  BreathPhase.hold => tr('breathOrb.hold'),
  BreathPhase.exhale => tr('breathOrb.breatheOut'),
  BreathPhase.rest => tr('breathOrb.rest'),
};

/// Drives an [inhale, hold, exhale, hold] cycle once per second (web useBreathCycle).
class BreathCycle extends ChangeNotifier {
  BreathCycle(this.pattern, {this.onPhase}) : left = pattern[0];
  final List<int> pattern;
  final void Function(BreathPhase)? onPhase;
  BreathPhase phase = BreathPhase.inhale;
  int left;
  Timer? _t;

  String get label => _phaseLabel(phase);
  int get duration => pattern[phase.index];

  void setRunning(bool running) {
    _t?.cancel();
    if (!running) return;
    // A cycle starting (or resuming) at the top of a phase announces it, so the very first
    // "Breathe in" is spoken instead of the coach's first word being "Hold".
    if (left == pattern[phase.index]) onPhase?.call(phase);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (left > 1) {
        left--;
        notifyListeners();
        return;
      }
      var i = phase.index;
      for (var k = 0; k < 4; k++) {
        i = (i + 1) % 4;
        if (pattern[i] > 0) break;
      }
      phase = BreathPhase.values[i];
      left = pattern[i];
      onPhase?.call(phase);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

/// Asanova's living breath orb: soft morphing layers swell on the in-breath and
/// settle on the out-breath, a thin ring traces the current phase and a glassy
/// core holds the label. [settling] is the narrator's settle-in time before counting starts.
class BreathOrb extends StatefulWidget {
  const BreathOrb({
    super.key,
    required this.phase,
    required this.left,
    required this.duration,
    required this.running,
    this.settling = false,
    this.quiet = false,
    this.size = 260,
  });

  /// Convenience for screens driven by a [BreathCycle].
  static Widget cycle({
    Key? key,
    required BreathCycle cycle,
    required bool running,
    bool quiet = false,
    double size = 260,
  }) => ListenableBuilder(
    key: key,
    listenable: cycle,
    builder: (_, _) => BreathOrb(
      phase: cycle.phase,
      left: cycle.left,
      duration: cycle.duration,
      running: running,
      quiet: quiet,
      size: size,
    ),
  );

  final BreathPhase phase;
  final int left, duration;
  final bool running, settling;

  /// Hides the label (e.g. under the start countdown).
  final bool quiet;
  final double size;
  @override
  State<BreathOrb> createState() => _BreathOrbState();
}

class _BreathOrbState extends State<BreathOrb> with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    value: 0.35,
  );
  late final AnimationController _ring = AnimationController(vsync: this);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );

  bool get _counting => widget.running && !widget.settling;

  @override
  void initState() {
    super.initState();
    _sync(null);
  }

  @override
  void didUpdateWidget(covariant BreathOrb old) {
    super.didUpdateWidget(old);
    _sync(old);
  }

  void _sync(BreathOrb? old) {
    if (widget.running) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
    if (!widget.running) {
      _open.animateTo(0.5, duration: const Duration(milliseconds: 900));
      _ring.stop();
      return;
    }
    if (widget.settling) {
      if (old == null || !old.settling || !old.running) {
        _open.duration = const Duration(seconds: 5);
        _open.repeat(min: 0.3, max: 0.62, reverse: true);
      }
      _ring.value = 0;
      return;
    }
    final changed =
        old == null ||
        old.phase != widget.phase ||
        old.settling ||
        !old.running ||
        widget.left == widget.duration;
    if (changed) {
      final opening =
          widget.phase == BreathPhase.inhale || widget.phase == BreathPhase.hold;
      _open.animateTo(
        opening ? 1 : 0.05,
        duration: Duration(
          milliseconds: math.max(600, widget.left * 1000),
        ),
        curve: Curves.easeInOutSine,
      );
    }
    final d = math.max(1, widget.duration);
    final from = (d - widget.left) / d;
    final to = (d - widget.left + 1) / d;
    if (_ring.value > to || changed) _ring.value = from;
    _ring.animateTo(to, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _open.dispose();
    _ring.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final label = widget.quiet
        ? ''
        : !widget.running
        ? tr('breathOrb.paused')
        : (widget.settling ? '' : _phaseLabel(widget.phase));
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_open, _ring, _spin]),
            builder: (_, _) => CustomPaint(
              size: Size.square(s),
              painter: _LivingOrbPainter(
                open: _open.value,
                ring: _counting ? _ring.value : 0,
                t: _spin.value * 90,
                loop: 90,
                showRing: _counting,
                alive: widget.running,
                flow: !_counting
                    ? 0
                    : widget.phase == BreathPhase.inhale
                        ? 1
                        : widget.phase == BreathPhase.exhale
                            ? -1
                            : 0,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty)
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: T.title.copyWith(
                    fontFamily: T.serif,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: C.ink,
                  ),
                ),
              if (_counting)
                Text(
                  '${widget.left}',
                  style: T.displayXl
                      .copyWith(fontSize: 34, color: C.ink, height: 1.05)
                      .tab,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asanova's "living sun" breath orb (web `LivingOrb`): a warm glowing sun that swells on
/// the in-breath while light particles stream into it, rests still on the hold while they
/// orbit and a gold ring traces the count, and softens on the out-breath as the light
/// drifts away. [flow] is 1 inward, 0 orbit, -1 outward. [t] loops every [loop] seconds and
/// every rate is a whole number of turns per loop so nothing jumps.
class _LivingOrbPainter extends CustomPainter {
  _LivingOrbPainter({
    required this.open,
    required this.ring,
    required this.t,
    required this.loop,
    required this.showRing,
    this.alive = true,
    this.flow = 0,
  });
  final double open, ring, t, loop;
  final bool showRing, alive;
  final int flow;

  double _rate(double perSecond) =>
      math.max(1, (perSecond * loop).round()) / loop;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final sunR = r * (0.34 + 0.24 * open);
    // Aura.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            C.gold.withValues(alpha: 0.12 + 0.24 * open),
            C.terracotta.withValues(alpha: 0.06 + 0.06 * open),
            C.gold.withValues(alpha: 0),
          ],
          stops: [0, 0.35 + 0.3 * open, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Guide track + phase progress.
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = C.ivory.withValues(alpha: 0.12),
    );
    if (showRing && ring > 0) {
      final rect = Rect.fromCircle(center: c, radius: r * 0.94);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = C.goldSoft.withValues(alpha: 0.9),
      );
      final a = -math.pi / 2 + 2 * math.pi * ring;
      final tip = c + Offset(math.cos(a), math.sin(a)) * r * 0.94;
      canvas.drawCircle(
        tip,
        5,
        Paint()
          ..color = C.gold.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(tip, 2.4, Paint()..color = C.ivory);
    }
    // Light particles.
    const n = 36;
    final speed = _rate(alive ? 0.22 : 0.06);
    final spin = 2 * math.pi * _rate(0.02);
    final outer = r * 0.9;
    for (var i = 0; i < n; i++) {
      final seed = (i * 0.618034) % 1;
      final base = i * 2.399963;
      final p = (t * speed + seed) % 1;
      double rad, ang, alpha;
      if (flow == 1) {
        rad = outer + (sunR - outer) * p;
        ang = base + 0.6 * p;
        alpha = math.sin(math.pi * p);
      } else if (flow == -1) {
        rad = sunR + (outer - sunR) * p;
        ang = base - 0.6 * p;
        alpha = math.sin(math.pi * p) * (1 - 0.4 * p);
      } else {
        rad = sunR + r * (0.07 + 0.12 * seed);
        ang = base + spin * t * (i.isEven ? 1 : -1);
        alpha = 0.35 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * (p + seed)));
      }
      final pos = c + Offset(math.cos(ang), math.sin(ang)) * rad;
      final dot = (0.9 + 1.5 * seed) * r / 130;
      canvas.drawCircle(
        pos,
        dot * 2.6,
        Paint()
          ..color = C.gold.withValues(alpha: 0.25 * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, dot * 2),
      );
      canvas.drawCircle(pos, dot, Paint()..color = C.goldSoft.withValues(alpha: 0.9 * alpha));
    }
    // Sun glow.
    canvas.drawCircle(
      c,
      sunR * 1.04,
      Paint()
        ..color = C.gold.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sunR * 0.32),
    );
    // Sun body.
    final sunRect = Rect.fromCircle(center: c, radius: sunR);
    canvas.drawCircle(
      c,
      sunR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.28, -0.32),
          radius: 1.05,
          colors: [C.ivory, C.goldSoft, C.gold, C.terracotta],
          stops: const [0, 0.32, 0.72, 1],
        ).createShader(sunRect),
    );
    // Drifting shimmer on the surface.
    canvas.save();
    canvas.clipPath(Path()..addOval(sunRect));
    for (var k = 0; k < 2; k++) {
      final a = 2 * math.pi * _rate(0.03) * t * (k == 0 ? 1 : -1) + k * 2.5;
      final sc = c + Offset(math.cos(a), math.sin(a)) * sunR * 0.42;
      canvas.drawCircle(
        sc,
        sunR * 0.55,
        Paint()
          ..shader = RadialGradient(
            colors: [C.ivory.withValues(alpha: 0.22), C.ivory.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: sc, radius: sunR * 0.55)),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      sunR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = C.ivory.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _LivingOrbPainter o) =>
      o.open != open || o.ring != ring || o.t != t || o.showRing != showRing || o.alive != alive || o.flow != flow;
}

/// Soft looping orb for non-breath meditations (web CalmOrb).
class CalmOrb extends StatefulWidget {
  const CalmOrb({super.key, required this.running, this.size = 260});
  final bool running;
  final double size;
  @override
  State<CalmOrb> createState() => _CalmOrbState();
}

class _CalmOrbState extends State<CalmOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );
  @override
  void initState() {
    super.initState();
    if (widget.running) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant CalmOrb old) {
    super.didUpdateWidget(old);
    if (widget.running && !_c.isAnimating) _c.repeat();
    if (!widget.running) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final wave = 0.5 - 0.5 * math.cos(2 * math.pi * 3 * _c.value);
        return CustomPaint(
          size: Size.square(s),
          painter: _LivingOrbPainter(
            open: widget.running ? 0.25 + 0.45 * wave : 0.35,
            ring: 0,
            t: _c.value * 30,
            loop: 30,
            showRing: false,
            alive: widget.running,
          ),
        );
      },
    );
  }
}
