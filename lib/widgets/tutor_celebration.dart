import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../i18n/i18n.dart';
import '../logic/coach.dart';
import '../logic/lesson_media.dart';
import '../logic/logic.dart';
import '../services/narration.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'demo_film.dart';
import 'sheet.dart';
import 'ui.dart';

/// The tutor's celebration at the end of a practice (web `TutorCelebration`): her film, the
/// day/course/class headline and her spoken congratulations, captioned line by line.
class TutorCelebration extends StatefulWidget {
  const TutorCelebration({
    super.key,
    required this.title,
    required this.completion,
    required this.lines,
  });
  final String title;
  final Completion completion;
  final List<String> lines;
  @override
  State<TutorCelebration> createState() => _TutorCelebrationState();
}

class _TutorCelebrationState extends State<TutorCelebration> {
  Narration? _narr;
  String _caption = '';

  @override
  void initState() {
    super.initState();
    _caption = widget.lines.isEmpty ? '' : widget.lines.first;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _play();
    });
  }

  void _play() {
    final app = context.read<AppState>();
    _narr?.dispose();
    _narr = Narration(
      lines: widget.lines,
      voiceOn: app.audio.voice,
      rate: app.audio.voiceRate,
      onLine: (k) {
        if (mounted) setState(() => _caption = widget.lines[k]);
      },
    )..start();
  }

  @override
  void dispose() {
    _narr?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.completion;
    final eyebrow = switch (c.kind) {
      CompletionKind.day => tr('complete.dayComplete', {'day': c.day!}),
      CompletionKind.course => tr('complete.courseComplete'),
      CompletionKind.single => tr('complete.sessionComplete'),
    };
    return Column(
      children: [
        Reveal(
          dy: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DemoFilm.keyed(
                        film: kTutorCongratsFilm,
                        poster: 'tutor-seat',
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: CircleBtn(
                          icon: LucideIcons.rotateCcw,
                          tone: Tone.dark,
                          size: 38,
                          iconSize: 16,
                          label: tr('journey.replay'),
                          onTap: _play,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Reveal(
          delay: 0.3,
          dy: 12,
          child: Column(
            children: [
              Eyebrow(eyebrow, color: C.sage),
              const SizedBox(height: 8),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: T.displayLg.c(C.ivory),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320, minHeight: 58),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _caption,
                    key: ValueKey(_caption),
                    textAlign: TextAlign.center,
                    style: T.serifAccent.copyWith(
                      fontSize: 20,
                      height: 1.35,
                      color: C.ivory.withValues(alpha: 0.85),
                    ),
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

/// Tomorrow's lesson under a finished course day (web `TomorrowCard`).
class TomorrowCard extends StatelessWidget {
  const TomorrowCard({super.key, required this.plan, required this.next});
  final Plan plan;
  final PlanDay next;
  @override
  Widget build(BuildContext context) {
    final premium = context.watch<AppState>().premium.active;
    final locked = isDayLocked(plan, next.day, premium);
    return Pressable(
      onTap: () => context.push('/plan/${plan.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: C.ivory.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.ivory.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.sunrise, size: 15, color: C.terracotta),
                const SizedBox(width: 6),
                Eyebrow(tr('complete.tomorrow'), color: C.terracotta),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('common.dayTitle', {'day': next.day, 'title': next.title}),
              style: T.title.c(C.ivory),
            ),
            if (next.tease != null) ...[
              const SizedBox(height: 6),
              Text(
                next.tease!,
                style: T.bodySm.copyWith(
                  color: C.ivory.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  locked ? LucideIcons.lock : LucideIcons.clock,
                  size: 14,
                  color: C.ivory.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locked
                        ? tr('complete.tomorrowLocked')
                        : formatMinutes(totalSeconds(next.items)),
                    style: T.caption.c(C.ivory.withValues(alpha: 0.7)),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: C.ivory.withValues(alpha: 0.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Watch the welcome" on a course page: the tutor's welcome film with her spoken, captioned
/// welcome, replayable any time (web `TutorWelcomeSheet`).
Future<void> showTutorWelcome(BuildContext context, Plan plan) =>
    showEnsoSheet<void>(
      context,
      dark: true,
      builder: (_) => _TutorWelcome(plan: plan),
    );

class _TutorWelcome extends StatefulWidget {
  const _TutorWelcome({required this.plan});
  final Plan plan;
  @override
  State<_TutorWelcome> createState() => _TutorWelcomeState();
}

class _TutorWelcomeState extends State<_TutorWelcome> {
  Narration? _narr;
  late final List<String> _lines = CoachLines.welcome(widget.plan);
  late String _caption = _lines.first;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _play();
    });
  }

  void _play() {
    final app = context.read<AppState>();
    _narr?.dispose();
    _narr = Narration(
      lines: _lines,
      voiceOn: app.audio.voice,
      rate: app.audio.voiceRate,
      onLine: (k) {
        if (mounted) setState(() => _caption = _lines[k]);
      },
    )..start();
  }

  @override
  void dispose() {
    _narr?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: const DemoFilm.keyed(
                film: kTutorWelcomeFilm,
                poster: 'tutor-seat',
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Eyebrow(tr('journey.welcomeEyebrow'), color: C.sage),
        const SizedBox(height: 6),
        Text(
          widget.plan.title,
          textAlign: TextAlign.center,
          style: T.title.c(C.ivory),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _caption,
              key: ValueKey(_caption),
              textAlign: TextAlign.center,
              style: T.serifAccent.copyWith(
                fontSize: 19,
                height: 1.35,
                color: C.ivory.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: EnsoButton(
                label: tr('journey.replay'),
                variant: BtnVariant.glass,
                icon: LucideIcons.rotateCcw,
                onTap: _play,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: EnsoButton(
                label: tr('common.close'),
                variant: BtnVariant.light,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The course-page entry to the tutor's welcome (web `MeetTutorCard`).
class MeetTutorCard extends StatelessWidget {
  const MeetTutorCard({super.key, required this.plan});
  final Plan plan;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => showTutorWelcome(context, plan),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.ivory,
        borderRadius: BorderRadius.circular(22),
        boxShadow: S.card,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 64,
              height: 64,
              child: EImage('tutor-seat'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('journey.watchWelcome'), style: T.label.c(C.ink)),
                const SizedBox(height: 3),
                Text(
                  tr('journey.howItWorks'),
                  style: T.caption.c(C.ink.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: C.jade,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.play, size: 18, color: C.ivory),
          ),
        ],
      ),
    ),
  );
}
