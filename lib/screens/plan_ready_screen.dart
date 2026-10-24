import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _checklist = [
  'Reading your intention',
  'Adapting poses to your body',
  'Choosing your course',
  'Pacing your first week',
];

class PlanReadyScreen extends StatefulWidget {
  const PlanReadyScreen({super.key});
  @override
  State<PlanReadyScreen> createState() => _PlanReadyScreenState();
}

class _PlanReadyScreenState extends State<PlanReadyScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final p = (elapsed.inMilliseconds / 4800 * 100).clamp(0.0, 100.0);
      setState(() => progress = p);
      if (p >= 100) _ticker.stop();
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = progress >= 100;
    return PopScope(
      canPop: false,
      child: AsanovaScaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: kEase,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(a),
              child: c,
            ),
          ),
          child: done
              ? const _Result(key: ValueKey('res'))
              : _Generating(key: const ValueKey('gen'), progress: progress),
        ),
      ),
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    final list = Content.i.testimonials;
    final t = list[math.max(0, (progress / 26).floor()) % list.length];
    final active = math.min(_checklist.length - 1, (progress / 25).floor());
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    C.jade.withValues(alpha: 0.16),
                    C.jade.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            topInset(context) + 56,
            28,
            bottomInset(context) + 24,
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const _Ripple(size: 164),
                  const _SpinningDash(size: 216),
                  Ring(
                    value: progress / 100,
                    size: 188,
                    stroke: 10,
                    child: Text('${progress.round()}%', style: T.displayXl.tab),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Creating your personal plan',
                textAlign: TextAlign.center,
                style: T.displayMd,
              ),
              const SizedBox(height: 8),
              Text(
                'Matching 91 poses to your answers…',
                textAlign: TextAlign.center,
                style: T.bodySm.c(C.muted),
              ),
              const SizedBox(height: 28),
              for (final (i, c) in _checklist.indexed)
                Builder(
                  builder: (context) {
                    final on = progress > (i + 1) * 24;
                    final current = !on && i == active;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Reveal(
                        delay: 0.1 + i * 0.12,
                        dy: 8,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: on
                                ? C.ivory
                                : (current
                                      ? C.ivory.withValues(alpha: 0.6)
                                      : Colors.transparent),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: on ? S.soft : null,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: on ? C.jade : C.sand,
                                      ),
                                      child: on
                                          ? const Center(
                                              child: Icon(
                                                LucideIcons.check,
                                                size: 16,
                                                color: C.ivory,
                                              ),
                                            )
                                          : null,
                                    ),
                                    if (current)
                                      const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: C.jade,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 500),
                                style: T.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: on || current ? C.ink : C.muted,
                                ),
                                child: Text(c),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  key: ValueKey(t.name),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.ivory,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: S.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(t.avatar ?? 'onb-age-f-50', size: 40),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: T.label.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Stars(count: t.rating, size: 13),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('“${t.text}”', style: T.bodySm),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpinningDash extends StatefulWidget {
  const _SpinningDash({required this.size});
  final double size;
  @override
  State<_SpinningDash> createState() => _SpinningDashState();
}

class _SpinningDashState extends State<_SpinningDash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: CustomPaint(size: Size.square(widget.size), painter: _DashPainter()),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final p = Paint()
      ..color = C.jade.withValues(alpha: 0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const n = 72;
    for (var i = 0; i < n; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: r),
        i * 2 * math.pi / n,
        2 * math.pi / n,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Ripple extends StatefulWidget {
  const _Ripple({required this.size});
  final double size;
  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Transform.scale(
      scale: 0.9 + 0.5 * _c.value,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: C.jade.withValues(alpha: 0.2 * (1 - _c.value)),
        ),
      ),
    ),
  );
}

/// Experience answer → how the plan describes the person (web `LEVEL_WORD`).
const _levelWord = {
  'new': 'brand-new',
  'returning': 'returning',
  'regular': 'practising',
  'dedicated': 'dedicated',
};

/// Phase colours for the "Inside Day 1" bar, in order (web `PHASE_COLORS`).
const _phaseColors = [
  C.sage,
  C.jade,
  C.gold,
  C.terracotta,
  C.jadeDeep,
  C.sandDeep,
];

class _Result extends StatelessWidget {
  const _Result({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final planId = recommendFor(p);
    final plan = Content.i.plan(planId)!;
    Map<String, String> labels(String step) => {
      for (final o in Content.i.step(step)?.options ?? const <OnbOption>[])
        o.id: o.label,
    };
    final goal = labels('goals')[p.goals.firstOrNull ?? ''];
    final level = labels('experience')[p.experience];
    final style = labels('style')[p.style];
    final breath = labels('breathwork')[p.breathwork];
    final gentle = p.limitations
        .where((l) => l != 'none')
        .map((l) => labels('limitations')[l])
        .whereType<String>()
        .toList();
    final word = _levelWord[p.experience];
    final profile = [
      (LucideIcons.sprout, 'Level', level ?? plan.level),
      (LucideIcons.target, 'Intention', goal ?? 'Overall wellbeing'),
      (LucideIcons.waves, 'Style', style ?? 'Classic Hatha'),
      (LucideIcons.clock, 'Daily time', '${p.dailyMinutes} minutes'),
      (LucideIcons.wind, 'Breathwork', breath ?? 'Not yet'),
      (
        LucideIcons.shieldCheck,
        'Gentler options',
        gentle.isEmpty ? 'None flagged' : gentle.join(', '),
      ),
    ];
    final week = plan.days.take(7).toList();
    final day1 = plan.days.first;
    final spans = phaseSpans(day1.items);
    final day1Sec = spans.fold<int>(0, (s, x) => s + x.sec);

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, topInset(context) + 24, 24, 170),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: C.jadeSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 14,
                      color: C.jadeDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Practice ready',
                      style: T.tiny.copyWith(
                        fontWeight: FontWeight.w700,
                        color: C.jadeDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${p.name.isNotEmpty ? '${p.name}, your' : 'Your'} practice is ',
                    ),
                    TextSpan(
                      text: 'ready',
                      style: T.serifAccent.copyWith(
                        fontSize: 36,
                        color: C.jade,
                      ),
                    ),
                  ],
                ),
                style: T.displayLg,
              ),
              const SizedBox(height: 10),
              Text(
                'Built for ${word != null ? 'a $word yogi' : 'you'}, around ${(goal ?? 'overall wellbeing').toLowerCase()}, in ${p.dailyMinutes} minutes a day.',
                style: T.body.c(C.muted),
              ),
              const SizedBox(height: 24),
              ECard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 176,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EImage(img(plan.image)),
                            DecoratedBox(
                              decoration: BoxDecoration(gradient: G.scrim),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Eyebrow(
                                    'Your course',
                                    color: C.ivory.withValues(alpha: 0.75),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.title,
                                    style: T.displayMd.c(C.ivory),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    plan.subtitle,
                                    style: T.caption.c(
                                      C.ivory.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              for (final (i, x) in [
                                (
                                  LucideIcons.calendarDays,
                                  '${plan.days.length} days',
                                ),
                                (
                                  LucideIcons.clock,
                                  '${plan.minutesPerDay} min/day',
                                ),
                                (LucideIcons.target, plan.level),
                              ].indexed) ...[
                                if (i > 0)
                                  const VerticalDivider(
                                    width: 1,
                                    color: C.line,
                                  ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Icon(x.$1, size: 20, color: C.jade),
                                      const SizedBox(height: 6),
                                      Text(
                                        x.$2,
                                        style: T.caption.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: C.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('Your yoga profile', style: T.title.s(20)),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final (i, (icon, label, value)) in profile.indexed)
                        Reveal(
                          delay: 0.1 + i * 0.05,
                          dy: 10,
                          child: Container(
                            width: w,
                            constraints: const BoxConstraints(minHeight: 92),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: C.ivory,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: S.soft,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 18, color: C.jade),
                                const SizedBox(height: 8),
                                Text(
                                  label.toUpperCase(),
                                  style: T.tiny.copyWith(
                                    fontSize: 11,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.label.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text('Inside Day 1', style: T.title.s(20))),
                  Text(
                    '${math.max(1, (day1Sec / 60).round())} min of practice',
                    style: T.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: C.jade,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(day1.title, style: T.bodySm.c(C.muted)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      for (final (i, s) in spans.indexed) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Expanded(
                          flex: math.max(1, s.sec),
                          child: ColoredBox(
                            color: _phaseColors[i % _phaseColors.length],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (final (i, s) in spans.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _phaseColors[i % _phaseColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.label, style: T.label)),
                      Text(
                        formatClock(s.sec.toDouble()),
                        style: T.caption
                            .copyWith(fontWeight: FontWeight.w600)
                            .tab,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text('Your first week', style: T.title.s(20)),
                  ),
                  Text(
                    '${plan.minutesPerDay} min a day',
                    style: T.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: C.jade,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Stack(
                children: [
                  Positioned(
                    left: 26,
                    top: 24,
                    bottom: 24,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: C.sandDeep.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      for (final (i, d) in week.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Reveal(
                            delay: 0.25 + i * 0.06,
                            dy: 10,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                10,
                                16,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: C.ivory,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: S.soft,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Stack(
                                      children: [
                                        RoundedImage(
                                          img(
                                            Content.i
                                                    .exercise(
                                                      d.items.firstOrNull?.e ??
                                                          '',
                                                    )
                                                    ?.image ??
                                                plan.image,
                                          ),
                                          size: 52,
                                          radius: 16,
                                        ),
                                        Positioned(
                                          left: 4,
                                          top: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: C.ink.withValues(
                                                alpha: 0.7,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${d.day}',
                                              style: T.tiny.copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: C.ivory,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: T.label,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${d.restore ? 'Restore day · ' : ''}${math.max(1, (totalSeconds(d.items) / 60).round())} min · ${d.items.length} poses',
                                          style: T.tiny.w(FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (i == 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: C.jadeSoft,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        'Today',
                                        style: T.tiny.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: C.jadeDeep,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text("What you'll practise", style: T.title.s(20)),
              const SizedBox(height: 14),
              for (final (i, b) in plan.benefits.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Reveal(
                    delay: 0.3 + i * 0.08,
                    dy: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: C.jade,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            size: 16,
                            color: C.ivory,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(b, style: T.body.w(FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        BottomCta(
          child: Shimmer(
            child: AsanovaButton(
              label: 'Start my practice',
              onTap: () {
                app.completeOnboarding(planId);
                context.go('/paywall?from=onboarding');
              },
            ),
          ),
        ),
      ],
    );
  }
}
