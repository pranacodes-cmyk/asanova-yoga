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

/// Asanova's lotus breath: eight petals open on the in-breath and fold on the
/// out-breath, a thin ring traces the current phase and a bindu glows at the
/// centre. [settling] is the narrator's settle-in time before counting starts.
class BreathOrb extends StatefulWidget {
  const BreathOrb({
    super.key,
    required this.phase,
    required this.left,
    required this.duration,
    required this.running,
    this.settling = false,
    this.size = 260,
  });

  /// Convenience for screens driven by a [BreathCycle].
  static Widget cycle({
    Key? key,
    required BreathCycle cycle,
    required bool running,
    double size = 260,
  }) => ListenableBuilder(
    key: key,
    listenable: cycle,
    builder: (_, _) => BreathOrb(
      phase: cycle.phase,
      left: cycle.left,
      duration: cycle.duration,
      running: running,
      size: size,
    ),
  );

  final BreathPhase phase;
  final int left, duration;
  final bool running, settling;
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
    final label = !widget.running
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
              painter: _LotusPainter(
                open: _open.value,
                ring: _counting ? _ring.value : 0,
                spin: _spin.value,
                showRing: _counting,
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
                    fontWeight: FontWeight.w500,
                    color: C.ivory,
                  ),
                ),
              if (_counting)
                Text(
                  '${widget.left}',
                  style: T.displayXl
                      .copyWith(fontSize: 34, color: C.ivory, height: 1.05)
                      .tab,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LotusPainter extends CustomPainter {
  _LotusPainter({
    required this.open,
    required this.ring,
    required this.spin,
    required this.showRing,
  });
  final double open, ring, spin;
  final bool showRing;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Soft aura grows with the breath.
    canvas.drawCircle(
      c,
      r * (0.55 + 0.3 * open),
      Paint()
        ..shader = RadialGradient(
          colors: [
            C.terracotta.withValues(alpha: 0.28 * (0.4 + open)),
            C.sage.withValues(alpha: 0.10),
            C.sage.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Guide track + phase progress.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = C.ivory.withValues(alpha: 0.16);
    canvas.drawCircle(c, r * 0.94, track);
    if (showRing && ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.94),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = C.ivory.withValues(alpha: 0.85),
      );
      final a = -math.pi / 2 + 2 * math.pi * ring;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.94,
        4.5,
        Paint()..color = C.ivory,
      );
    }
    // Two petal layers: clay behind, sage in front, slowly turning.
    void layer(double rot, Color color, double scale, double alpha) {
      for (var i = 0; i < 8; i++) {
        final ang = rot + i * math.pi / 4;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(ang);
        final lift = r * (0.08 + 0.30 * open) * scale;
        final len = r * (0.34 + 0.20 * open) * scale;
        final w = r * (0.15 + 0.07 * open) * scale;
        final path = Path()
          ..moveTo(0, -lift + len * 0.5)
          ..quadraticBezierTo(w, -lift, 0, -lift - len * 0.5)
          ..quadraticBezierTo(-w, -lift, 0, -lift + len * 0.5)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color.withValues(alpha: alpha * 0.35),
                color.withValues(alpha: alpha),
              ],
            ).createShader(path.getBounds()),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = C.ivory.withValues(alpha: 0.22),
        );
        canvas.restore();
      }
    }

    final turn = spin * 2 * math.pi;
    layer(turn + math.pi / 8, C.terracotta, 1.0, 0.42);
    layer(-turn * 0.6, C.sage, 0.86, 0.62);
    // Bindu core keeps the label readable.
    canvas.drawCircle(
      c,
      r * 0.29,
      Paint()
        ..shader = RadialGradient(
          colors: [C.forest2.withValues(alpha: 0.92), C.forest.withValues(alpha: 0.75)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.29)),
    );
    canvas.drawCircle(
      c,
      r * 0.29,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = C.gold.withValues(alpha: 0.35 + 0.4 * open),
    );
  }

  @override
  bool shouldRepaint(covariant _LotusPainter o) =>
      o.open != open || o.ring != ring || o.spin != spin || o.showRing != showRing;
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
    duration: const Duration(seconds: 10),
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
        double wave(double offset) =>
            0.5 - 0.5 * math.cos(2 * math.pi * ((_c.value + offset) % 1));
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (i, r) in [1.0, 0.8, 0.6].indexed)
                Transform.scale(
                  scale: widget.running ? 0.92 + 0.14 * wave(i * 0.08) : 0.95,
                  child: Container(
                    width: s * r,
                    height: s * r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.ivory.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              Transform.scale(
                scale: widget.running ? 0.88 + 0.17 * wave(0) : 0.9,
                child: Container(
                  width: s * 0.5,
                  height: s * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [
                        Color(0xFFEADDC1),
                        Color(0xFF6A9C7F),
                        Color(0xFF284B3A),
                      ],
                      stops: [0, 0.6, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA6CBAF).withValues(alpha: 0.6),
                        blurRadius: 90,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
