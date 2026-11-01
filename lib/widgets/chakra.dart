import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/models.dart';
import '../i18n/i18n.dart';
import '../logic/lesson_media.dart';
import '../logic/logic.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'demo_film.dart';
import 'ui.dart';

/// Today's cinematic card for the signature experience (web `FeatureExperienceCard`): its looping
/// preview film, the seven centres as a glowing spine, and one clear way in.
class FeatureExperienceCard extends StatelessWidget {
  const FeatureExperienceCard({
    super.key,
    required this.plan,
    required this.completed,
    required this.premium,
    required this.onOpen,
  });
  final Plan plan;
  final List<int> completed;
  final bool premium;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final films = courseFilms(plan);
    final film = films.preview ?? films.welcome;
    final next = nextPlanDay(plan.days.length, completed);
    final states = chapterStates(plan, completed);
    final freeChip = plan.premium && !premium && plan.freeDays > 0;
    return Pressable(
      onTap: onOpen,
      semanticLabel: plan.title,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(
            color: C.forest,
            borderRadius: BorderRadius.circular(34),
            boxShadow: S.float,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DemoFilm.keyed(
                film: film,
                poster: filmPoster(film),
                portrait: true,
                alignment: const Alignment(0, -0.4),
              ),
              DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 112,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [C.forest.withValues(alpha: 0.55), C.forest.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 16,
                child: Row(
                  children: [
                    Flexible(
                      child: Glass(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.sparkles, size: 14, color: C.gold),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tr('home.signatureExperience'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.tiny.copyWith(fontWeight: FontWeight.w600, color: C.ivory),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (freeChip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          tr('plan.firstDaysFree', {'n': plan.freeDays}),
                          style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.ink),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow(plan.subtitle, color: C.ivory.withValues(alpha: 0.7)),
                    const SizedBox(height: 6),
                    Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.displayLg.copyWith(fontSize: 33.6, height: 1.05, color: C.ivory),
                    ),
                    const SizedBox(height: 16),
                    ChakraSpine(chapters: plan.chapters, states: states),
                    const SizedBox(height: 16),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(999)),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.play, size: 20, color: C.ink),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              completed.isNotEmpty
                                  ? tr('home.featureContinue', {'day': next})
                                  : tr('home.featureBegin'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.body.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: C.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The seven centres in a row, joined like a spine; finished centres glow, the current one pulses
/// (web `ChakraSpine`).
class ChakraSpine extends StatelessWidget {
  const ChakraSpine({super.key, required this.chapters, required this.states});
  final List<PlanChapter> chapters;
  final List<ChapterState> states;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            right: 12,
            child: Container(height: 1, color: C.ivory.withValues(alpha: 0.25)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < chapters.length; i++)
                  ChakraNode(
                    color: C.chakra(chapters[i].chakra) ?? C.ivory,
                    state: i < states.length ? states[i] : ChapterState.upcoming,
                    size: 24,
                    dot: 16,
                    smallDot: 12,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// One centre: a coloured dot that glows once reached and pulses while current.
class ChakraNode extends StatefulWidget {
  const ChakraNode({
    super.key,
    required this.color,
    required this.state,
    this.size = 32,
    this.dot = 24,
    this.smallDot = 16,
    this.check = false,
  });
  final Color color;
  final ChapterState state;
  final double size, dot, smallDot;
  final bool check;
  @override
  State<ChakraNode> createState() => _ChakraNodeState();
}

class _ChakraNodeState extends State<ChakraNode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.state == ChapterState.current) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant ChakraNode old) {
    super.didUpdateWidget(old);
    if (widget.state == ChapterState.current && !_pulse.isAnimating) _pulse.repeat();
    if (widget.state != ChapterState.current && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.state != ChapterState.upcoming;
    final d = lit ? widget.dot : widget.smallDot;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.state == ChapterState.current)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                // ease in and out like the web pulse: grow to 1.6× while fading away
                final t = Curves.easeInOut.transform((_pulse.value * 2) % 1.0);
                final up = _pulse.value < 0.5;
                final scale = up ? 1 + 0.6 * t : 1.6 - 0.6 * t;
                final alpha = up ? 0.55 * (1 - t) : 0.55 * t;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(color: widget.color.withValues(alpha: alpha), shape: BoxShape.circle),
                  ),
                );
              },
            ),
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: lit ? 1 : 0.75),
              shape: BoxShape.circle,
              border: widget.check ? null : Border.all(color: C.ivory.withValues(alpha: 0.7), width: 2),
              boxShadow: lit
                  ? [BoxShadow(color: widget.color.withValues(alpha: 0.9), blurRadius: 14, spreadRadius: 2)]
                  : null,
            ),
            child: widget.check && widget.state == ChapterState.done
                ? const Icon(LucideIcons.check, size: 14, color: C.ink)
                : null,
          ),
        ],
      ),
    );
  }
}

/// The seven centres of a chakra course as a glowing spine, root at the bottom and crown on top
/// (web `ChakraMap`): each centre's element and seed sound, and how far the journey has come.
class ChakraMap extends StatelessWidget {
  const ChakraMap({super.key, required this.plan, required this.completed});
  final Plan plan;
  final List<int> completed;
  @override
  Widget build(BuildContext context) {
    final states = chapterStates(plan, completed);
    final rows = [
      for (var i = plan.chapters.length - 1; i >= 0; i--)
        (c: plan.chapters[i], state: i < states.length ? states[i] : ChapterState.upcoming),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: G.forest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: S.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(tr('plan.sevenCentres'), color: C.gold),
          const SizedBox(height: 4),
          Text(
            tr('plan.sevenCentresDesc'),
            style: T.bodySm.copyWith(height: 1.45, color: C.ivory.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Positioned(
                left: 15.5,
                top: 20,
                bottom: 20,
                child: Container(width: 1, color: C.ivory.withValues(alpha: 0.15)),
              ),
              Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Reveal(
                      delay: 0.05 * (rows.length - i),
                      dy: 8,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            ChakraNode(
                              color: C.chakra(rows[i].c.chakra) ?? C.ivory,
                              state: rows[i].state,
                              check: true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rows[i].c.title,
                                    style: T.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, color: C.ivory),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rows[i].c.summary,
                                    style: T.caption.copyWith(height: 1.3, color: C.ivory.withValues(alpha: 0.6)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            switch (rows[i].state) {
                              ChapterState.current => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: C.ivory, borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  tr('plan.chakraNow'),
                                  style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.ink),
                                ),
                              ),
                              ChapterState.done => Text(
                                tr('plan.chakraDone'),
                                style: T.tiny.copyWith(fontWeight: FontWeight.w600, color: C.ivory.withValues(alpha: 0.7)),
                              ),
                              ChapterState.upcoming => Text(
                                tr('plan.chakraDays', {'from': rows[i].c.from, 'to': rows[i].c.to}),
                                style: T.tiny.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: T.tabular,
                                  color: C.ivory.withValues(alpha: 0.45),
                                ),
                              ),
                            },
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
