import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/coach.dart';
import '../logic/lesson_media.dart';
import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../services/narration.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/demo_film.dart';
import '../widgets/lesson_prepare.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/ui.dart';
import 'plan_detail_screen.dart';
import '../i18n/i18n.dart';

/// Phases of a guided session (web `Phase`): the tutor's course welcome, the day's intention
/// (or a short countdown), a watch-first demo, "your turn" before a flow, timed practice and rest.
enum _Phase { welcome, intro, ready, demo, turn, work, rest }

const _readySec = 3.0;

/// Room the coaching block (phase, name, cue, clock, controls, progress) needs under the film.
const double kPlayerCoachingMin = 292;

/// Height of the edge-to-edge square film in the player (web `filmHeight`): the full width
/// when there is room, never taller than wide, and never squeezing the controls.
double playerFilmHeight(double width, double height, double bottomInset) =>
    math.max(180.0, math.min(width, height - kPlayerCoachingMin - bottomInset));

/// Opens a session: decides the journey for this person (welcome, which demos), makes sure the
/// lesson's films and voice are on the phone, then runs the guided player.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Session? session = resolveSession(widget.sessionId);
  late final JourneyOptions opts;
  late final List<String> paths;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final s = session;
    final plan = s?.planId == null ? null : Content.i.plan(s!.planId!);
    final completed =
        (s?.planId == null
            ? null
            : app.planProgress[s!.planId!]?.completedDays) ??
        const <int>[];
    opts = JourneyOptions(
      known: practisedSet(app.history),
      demos: app.audio.demos,
      welcome:
          plan != null &&
          s?.day != null &&
          shouldWelcome(plan, s!.day!, completed),
      completedDays: completed,
    );
    paths = s == null ? const [] : sessionMediaPaths(s, opts, Content.i.voice);
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s == null) return const NotFoundView();
    return LessonPrepare(
      paths: paths,
      child: _GuidedPlayer(session: s, opts: opts),
    );
  }
}

class _GuidedPlayer extends StatefulWidget {
  const _GuidedPlayer({required this.session, required this.opts});
  final Session session;
  final JourneyOptions opts;
  @override
  State<_GuidedPlayer> createState() => _GuidedPlayerState();
}

class _GuidedPlayerState extends State<_GuidedPlayer> {
  late final AppState app = context.read<AppState>();
  Session get session => widget.session;
  late final Plan? plan = session.planId == null
      ? null
      : Content.i.plan(session.planId!);
  bool get multiDay => plan != null && plan!.days.length > 1;

  _Phase phase = _Phase.ready;
  int index = 0;
  double remaining = _readySec;
  bool running = true;
  double elapsed = 0, work = 0;
  bool spokeHalf = false, finished = false, yourTurn = false;
  int stepIdx = 0;
  String caption = '';
  Narration? _narr;
  Timer? _tick, _turnTimer;
  DateTime _last = DateTime.now();

  List<SessionItem> get items => session.items;
  SessionItem get item => items[index];
  Exercise get current => Content.i.exercise(item.e)!;
  YogaFlow? get flow => Content.i.flow(item.f);
  Exercise? get nextEx =>
      index + 1 < items.length ? Content.i.exercise(items[index + 1].e) : null;
  bool get _voiceLed =>
      phase == _Phase.welcome ||
      phase == _Phase.intro ||
      phase == _Phase.demo ||
      phase == _Phase.turn;

  /// Characters after which a spoken caption switches to the compact six-line layout (web `LONG_CAPTION`).
  static const _longCaptionChars = 170;
  bool get _longCaption => _voiceLed && _text.length > _longCaptionChars;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    Sfx.play('sfx-bell-start', 0.6);
    _syncMusic();
    _last = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      widget.opts.welcome && plan != null ? _enterWelcome() : _enterIntro();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _turnTimer?.cancel();
    _narr?.dispose();
    Voice.stop();
    Ambient.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  void _say(List<String> lines, {bool interrupt = true}) {
    if (app.audio.voice) {
      Voice.say(lines, interrupt: interrupt, rate: app.audio.voiceRate);
    }
  }

  void _syncMusic() {
    if (app.audio.music && running) {
      Ambient.play(app.audio.musicTrack, app.audio.musicVolume * 0.6);
    } else {
      Ambient.pause();
    }
  }

  // ------------------------------------------------------------ voice-led moments

  void _narrate(List<String> lines, VoidCallback then) {
    _narr?.dispose();
    final n = Narration(
      lines: lines,
      voiceOn: app.audio.voice,
      rate: app.audio.voiceRate,
      onLine: (k) {
        if (mounted) setState(() => caption = lines[k]);
      },
      onDone: () {
        if (mounted && !finished) then();
      },
    );
    _narr = n;
    if (running) {
      n.start();
    } else {
      setState(
        () => caption = lines.firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        ),
      );
    }
  }

  void _enterWelcome() {
    setState(() => phase = _Phase.welcome);
    _narrate(CoachLines.welcome(plan!), _enterIntro);
  }

  void _enterIntro() {
    _narr?.dispose();
    Voice.stop();
    if (session.intro.isEmpty) {
      setState(() {
        phase = _Phase.ready;
        remaining = _readySec;
      });
      _say(CoachLines.begin(Content.i.exercise(items.first.e)!));
      return;
    }
    setState(() {
      phase = _Phase.intro;
      index = 0;
    });
    _narrate(
      CoachLines.dayIntro(session.intro, multiDay ? session.day : null),
      () => _beginItem(0),
    );
  }

  /// Item i opens with its demo, a flow's "your turn", or straight into practice.
  void _beginItem(int i) {
    _narr?.dispose();
    final it = items[i];
    final demo = journeyDemoAt(items, i, widget.opts);
    setState(() => index = i);
    final blockStart = it.f != null && (i == 0 || items[i - 1].f != it.f);
    if (blockStart && Content.i.flow(it.f) != null) {
      demo == DemoKind.flow ? _enterDemo(i) : _enterTurn(i);
    } else if (demo == DemoKind.pose) {
      _enterDemo(i);
    } else {
      _startWork(i);
    }
  }

  void _enterDemo(int i) {
    final it = items[i];
    final f = Content.i.flow(it.f);
    setState(() {
      index = i;
      phase = _Phase.demo;
    });
    Sfx.play('sfx-chime', 0.35);
    _narrate(
      f != null && it.f != null
          ? CoachLines.flowDemo(f)
          : CoachLines.demo(Content.i.exercise(it.e)!),
      () => f != null ? _enterTurn(i) : _startWork(i, afterDemo: true),
    );
  }

  void _enterTurn(int i) {
    final f = Content.i.flow(items[i].f)!;
    setState(() {
      index = i;
      phase = _Phase.turn;
    });
    Haptics.medium();
    _narrate(CoachLines.flowGo(f), () => _startWork(i));
  }

  // ------------------------------------------------------------ timed practice

  void _onTick() {
    if (!running || finished) return;
    final now = DateTime.now();
    final dt = now.difference(_last).inMicroseconds / 1e6;
    _last = now;
    if (phase != _Phase.ready && phase != _Phase.welcome) elapsed += dt;
    if (_voiceLed) return;
    final prev = remaining;
    final next = prev - dt;
    if (phase == _Phase.work) work += dt;
    bool crossed(double n) => prev > n && next <= n;
    if (app.audio.beeps &&
        item.f == null &&
        (crossed(3) || crossed(2) || crossed(1))) {
      Sfx.play('sfx-tick', 0.5);
    }
    if (phase == _Phase.work && item.f == null) {
      final ex = current;
      final len = item.s;
      if (!ex.isAffirmation && ex.steps.length > 1) {
        // walk through the real instructions, one step per equal slice of the hold
        final k = ((len - next) / (len / ex.steps.length)).floor().clamp(
          0,
          ex.steps.length - 1,
        );
        if (k != stepIdx) {
          stepIdx = k;
          _say(CoachLines.step(ex, k), interrupt: false);
        }
      } else if (!spokeHalf && len >= 40 && next <= len / 2) {
        spokeHalf = true;
        _say(
          CoachLines.halfway(ex, halfwayAffirmation(session.id, index)),
          interrupt: false,
        );
      }
    }
    setState(() => remaining = next);
    if (next <= 0) {
      switch (phase) {
        case _Phase.ready:
          _beginItem(0);
        case _Phase.work:
          _advance();
        case _Phase.rest:
          _beginItem(index + 1);
        default:
          break;
      }
    }
  }

  void _startWork(int i, {bool afterDemo = false}) {
    _narr?.dispose();
    final it = items[i];
    final ex = Content.i.exercise(it.e)!;
    final inFlow = it.f != null;
    setState(() {
      index = i;
      phase = _Phase.work;
      remaining = it.s.toDouble();
      spokeHalf = false;
      stepIdx = 0;
      yourTurn = afterDemo;
    });
    _turnTimer?.cancel();
    if (afterDemo) {
      _turnTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => yourTurn = false);
      });
    }
    if (!inFlow || isRoundStart(items, i)) Sfx.play('sfx-chime', 0.45);
    inFlow ? Haptics.light() : Haptics.medium();
    if (inFlow) {
      _say(CoachLines.flowMove(it, isRoundStart(items, i)));
    } else {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && phase == _Phase.work && index == i) {
          _say(afterDemo ? CoachLines.yourTurn(ex) : CoachLines.start(ex));
        }
      });
    }
  }

  void _advance() {
    if (index >= items.length - 1) {
      _finish();
      return;
    }
    final gap = gapBefore(items, index + 1, session.restSec);
    if (gap > 0) {
      setState(() {
        phase = _Phase.rest;
        remaining = gap.toDouble();
      });
      Sfx.play('sfx-chime', 0.35);
      _say(CoachLines.rest(Content.i.exercise(items[index + 1].e)!));
    } else {
      _beginItem(index + 1);
    }
  }

  void _finish() {
    if (finished) return;
    finished = true;
    _tick?.cancel();
    _narr?.dispose();
    setState(() => running = false);
    Sfx.play('sfx-bell-end', 0.7);
    _say(CoachLines.finish());
    final s = session;
    final totalWork = items.fold<int>(0, (a, it) => a + it.s);
    final ratio = math.min(1.0, work / math.max(1, totalWork));
    final entry = HistoryEntry(
      id: '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 30).toRadixString(36)}',
      sessionId: s.id,
      title: s.title,
      kind: 'workout',
      image: s.image,
      completedAt: DateTime.now(),
      durationSec: math.max(30, elapsed.round()),
      kcal: math.max(
        1,
        (kcalForWeight(s.baseKcal, app.profile.weightKg) * ratio).round(),
      ),
      planId: s.planId,
      day: s.day,
    );
    app.completeSession(entry);
    Ambient.stop();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) context.pushReplacement('/complete?id=${entry.id}');
    });
  }

  // ------------------------------------------------------------ controls

  void _togglePlay() {
    Haptics.light();
    setState(() => running = !running);
    if (running) {
      _narr?.resume();
    } else {
      _narr?.pause();
      Voice.stop();
    }
    _last = DateTime.now();
    _syncMusic();
  }

  void _skipNext() {
    switch (phase) {
      case _Phase.welcome:
        _enterIntro();
      case _Phase.intro:
      case _Phase.ready:
        _beginItem(0);
      case _Phase.demo:
        Voice.stop();
        items[index].f != null
            ? _enterTurn(index)
            : _startWork(index, afterDemo: true);
      case _Phase.turn:
        Voice.stop();
        _startWork(index);
      case _Phase.work:
      case _Phase.rest:
        if (index >= items.length - 1) {
          _finish();
          return;
        }
        Voice.stop();
        _beginItem(index + 1);
    }
    if (!running) _togglePlay();
  }

  void _skipPrev() {
    Voice.stop();
    final spent = item.s - remaining;
    if (phase == _Phase.work && spent > 3) {
      _startWork(index);
    } else if (phase == _Phase.welcome || phase == _Phase.intro) {
      phase == _Phase.welcome ? _enterWelcome() : _enterIntro();
    } else {
      _beginItem(math.max(0, phase == _Phase.rest ? index : index - 1));
    }
    if (!running) _togglePlay();
  }

  Future<void> _exit() async {
    final wasRunning = running;
    if (wasRunning) _togglePlay();
    final pctDone =
        ((index + (phase == _Phase.work ? _progress : 0)) / items.length * 100)
            .round();
    final leave = await showEnsoSheet<bool>(
      context,
      dark: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              Text(
                tr('player.leaveSessionTitle'),
                style: T.displayMd.c(C.ivory),
              ),
              const SizedBox(height: 8),
              Text(
                tr('player.leaveSessionBody', {'pct': pctDone}),
                textAlign: TextAlign.center,
                style: T.bodySm.c(C.ivory.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 24),
              EnsoButton(
                label: tr('player.keepPracticing'),
                variant: BtnVariant.ivory,
                onTap: () => Navigator.pop(ctx, false),
              ),
              const SizedBox(height: 8),
              Pressable(
                onTap: () => Navigator.pop(ctx, true),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      tr('player.endSession'),
                      style: T.label.c(C.terracotta),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (leave == true) {
      _narr?.dispose();
      Voice.stop();
      Ambient.stop();
      context.go('/');
    } else if (wasRunning && !running) {
      _togglePlay();
    }
  }

  void _settings() {
    showEnsoSheet<void>(
      context,
      dark: true,
      builder: (ctx) => _SoundSheet(onChange: _syncMusic),
    );
  }

  double get _phaseTotal => switch (phase) {
    _Phase.ready => _readySec,
    _Phase.rest => gapBefore(items, index + 1, session.restSec).toDouble(),
    _ => item.s.toDouble(),
  };
  double get _progress =>
      (1 - math.max(0, remaining) / math.max(1, _phaseTotal)).clamp(0.0, 1.0);
  double get _overall {
    if (phase == _Phase.welcome ||
        phase == _Phase.intro ||
        phase == _Phase.ready) {
      return 0;
    }
    final part = phase == _Phase.work
        ? _progress
        : (phase == _Phase.rest ? 1.0 : 0.0);
    return ((index + part) / items.length).clamp(0.0, 1.0);
  }

  // ------------------------------------------------------------ view

  Widget _film() {
    final f = flow;
    final Widget film;
    if (phase == _Phase.welcome) {
      film = DemoFilm.keyed(
        key: const ValueKey('welcome'),
        film: kTutorWelcomeFilm,
        poster: 'tutor-seat',
        playing: running,
      );
    } else if (phase == _Phase.demo && f != null && f.demo != null) {
      film = DemoFilm.keyed(
        key: ValueKey('flow-${f.id}'),
        film: f.demo!,
        poster: current.image,
        playing: running,
      );
    } else {
      // The tutor moves into each pose once (entry film) — during the rest before it, in "watch
      // first", or as the hold begins — then the hold film loops; flow moves play their breath
      // transition (web player, same rule).
      final shownIndex = phase == _Phase.rest && nextEx != null
          ? index + 1
          : index;
      final shownItem = items[shownIndex];
      final shown = phase == _Phase.rest && nextEx != null ? nextEx! : current;
      final intro = shownItem.f != null
          ? (phase == _Phase.rest ? null : shownItem.v)
          : shown.entry;
      film = DemoFilm(
        key: ValueKey(
          '${shown.id}-${shownItem.f != null ? shownIndex : 0}-${intro ?? ''}',
        ),
        exercise: shown,
        intro: intro,
        introOnly: shownItem.f != null && shownItem.v != null && !shownItem.vl,
        playing: running,
      );
    }
    final pill = switch (phase) {
      _Phase.demo => (LucideIcons.eye, tr('player.watchFirst')),
      _Phase.turn => (LucideIcons.hand, tr('player.yourTurn')),
      _ => null,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        film,
        if (phase == _Phase.ready || phase == _Phase.rest)
          ColoredBox(
            color: C.forest.withValues(alpha: 0.4),
            child: Center(
              child: Text(
                '${math.max(1, remaining.ceil())}',
                style: T.displayXl.copyWith(fontSize: 64, color: C.ivory).tab,
              ),
            ),
          ),
        if (phase == _Phase.intro)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  C.forest.withValues(alpha: 0.05),
                  C.forest.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        if (pill != null)
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: C.forest.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(pill.$1, size: 15, color: C.ivory),
                  const SizedBox(width: 6),
                  Text(
                    pill.$2,
                    style: T.tiny.copyWith(
                      fontWeight: FontWeight.w700,
                      color: C.ivory,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (current.isAffirmation && phase == _Phase.work)
          Container(
            color: C.forest.withValues(alpha: 0.6),
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              current.description,
              textAlign: TextAlign.center,
              style: T.serifAccent.copyWith(fontSize: 26, color: C.ivory),
            ),
          ),
      ],
    );
  }

  String? get _eyebrow {
    final f = flow;
    switch (phase) {
      case _Phase.welcome:
        return tr('journey.welcomeEyebrow');
      case _Phase.intro:
        return multiDay
            ? tr('journey.dayOfTotal', {
                'day': session.day ?? 1,
                'total': plan!.days.length,
              })
            : tr('journey.todayEyebrow');
      case _Phase.demo:
        return tr('player.watchFirst');
      case _Phase.turn:
        return tr('player.yourTurn');
      case _Phase.work:
        if (yourTurn) return tr('player.yourTurn');
        if (f != null) {
          return '${tr('player.roundOf', {'n': item.r ?? 1, 'total': flowRounds(items, index)})} · ${f.name}';
        }
        return item.p;
      case _Phase.rest:
        return index + 1 < items.length ? items[index + 1].p : null;
      case _Phase.ready:
        return item.p;
    }
  }

  String get _title {
    final f = flow;
    return switch (phase) {
      _Phase.welcome => plan!.title,
      _Phase.intro => session.title,
      _Phase.demo || _Phase.turn => f?.name ?? current.name,
      _Phase.rest => nextEx?.name ?? current.name,
      _ => current.name,
    };
  }

  String get _text {
    if (_voiceLed) return caption;
    if (phase == _Phase.rest) return tr('player.restGuidance');
    final ex = current;
    if (item.c != null) return item.c!;
    if (ex.isAffirmation) return ex.description;
    if (ex.steps.isEmpty) return ex.cue;
    return ex.steps[stepIdx.clamp(0, ex.steps.length - 1)];
  }

  Widget _centre() {
    if (!_voiceLed) {
      return Text(
        formatClock(remaining),
        style: T.displayMd.copyWith(fontSize: 32, color: C.ivory).tab,
      );
    }
    final (String label, VoidCallback onTap)? action = switch (phase) {
      _Phase.welcome => (tr('journey.skipWelcome'), _skipNext),
      _Phase.intro => (tr('journey.begin'), _skipNext),
      _Phase.demo => (tr('player.skipDemo'), _skipNext),
      _ => null,
    };
    return SizedBox(
      height: 38,
      child: action == null
          ? null
          : Pressable(
              onTap: action.$2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: C.ivory.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(action.$1, style: T.label.c(C.ivory)),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = topInset(context);
    final bottom = bottomInset(context);
    final header = switch (phase) {
      // the welcome and the day's intention carry their own eyebrow, so the top bar stays quiet
      _Phase.welcome || _Phase.intro => '',
      _Phase.ready => tr('player.getReady'),
      _Phase.rest => tr('player.restNextMovement'),
      _ => tr('player.stepOfTotal', {
        'current': index + 1,
        'total': items.length,
      }),
    };
    final eyebrow = _eyebrow;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: EnsoScaffold(
        background: C.forest,
        lightIcons: true,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 4, 16, 8),
              child: Row(
                children: [
                  CircleBtn(
                    icon: LucideIcons.x,
                    tone: Tone.dark,
                    onTap: _exit,
                    label: tr('common.close'),
                  ),
                  Expanded(
                    child: Text(
                      header,
                      textAlign: TextAlign.center,
                      style: T.caption.c(C.ivory.withValues(alpha: 0.7)),
                    ),
                  ),
                  CircleBtn(
                    icon: LucideIcons.slidersHorizontal,
                    tone: Tone.dark,
                    onTap: _settings,
                    label: tr('player.audioSettings'),
                  ),
                ],
              ),
            ),
            // The square film runs edge to edge (web `filmHeight`): full width when the screen
            // allows, otherwise a little shorter, but never taller than wide, so no pose is cut
            // at the sides and nothing is padded or blurred. The coaching block takes the rest.
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final filmH = playerFilmHeight(
                    box.maxWidth,
                    box.maxHeight,
                    bottom,
                  );
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: filmH,
                        child: _film(),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (eyebrow != null && eyebrow.isNotEmpty) ...[
                                Eyebrow(
                                  eyebrow,
                                  color:
                                      phase == _Phase.demo ||
                                          phase == _Phase.turn ||
                                          yourTurn
                                      ? C.terracotta
                                      : C.sage,
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                _title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: T.title.copyWith(
                                  fontSize: 24,
                                  color: C.ivory,
                                ),
                              ),
                              // the cue hugs its text so the coaching block stays grouped
                              // and centred under the film (web `justify-center`)
                              Flexible(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Align(
                                    heightFactor: 1,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      child: Text(
                                        _text,
                                        key: ValueKey(_text),
                                        // long spoken paragraphs (a day's intention) get more
                                        // lines in a slightly smaller size so they are never cut
                                        maxLines: _voiceLed
                                            ? (_longCaption ? 6 : 4)
                                            : 3,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: T.bodySm.copyWith(
                                          color: C.ivory.withValues(
                                            alpha: _voiceLed ? 0.85 : 0.65,
                                          ),
                                          fontSize: _longCaption ? 14 : null,
                                          height: _longCaption ? 1.45 : 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _centre(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  CircleBtn(
                                    icon: Icons.skip_previous_rounded,
                                    tone: Tone.dark,
                                    size: 48,
                                    iconSize: 26,
                                    onTap: _skipPrev,
                                    label: tr('player.previous'),
                                  ),
                                  Pressable(
                                    onTap: _togglePlay,
                                    semanticLabel: running
                                        ? tr('common.pause')
                                        : tr('common.play'),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: const BoxDecoration(
                                        color: C.ivory,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        running
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 34,
                                        color: C.ink,
                                      ),
                                    ),
                                  ),
                                  CircleBtn(
                                    icon: Icons.skip_next_rounded,
                                    tone: Tone.dark,
                                    size: 48,
                                    iconSize: 26,
                                    onTap: _skipNext,
                                    label: tr('player.next'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: _overall,
                                  minHeight: 2,
                                  backgroundColor: C.ivory.withValues(
                                    alpha: 0.15,
                                  ),
                                  color: C.sage,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundSheet extends StatelessWidget {
  const _SoundSheet({required this.onChange});
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final a = app.audio;
    Widget toggle(IconData icon, String label, bool on, VoidCallback onTap) =>
        Expanded(
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: on ? C.jade : C.ivory.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: C.ivory),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: T.label.c(C.ivory))),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(tr('player.sound'), style: T.title.c(C.ivory)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              toggle(
                a.voice ? LucideIcons.mic : LucideIcons.micOff,
                a.voice ? tr('player.voiceOn') : tr('player.voiceOff'),
                a.voice,
                () => app.setAudio((x) => x.voice = !x.voice),
              ),
              const SizedBox(width: 12),
              toggle(
                LucideIcons.music2,
                a.music ? tr('player.musicOn') : tr('player.musicOff'),
                a.music,
                () {
                  app.setAudio((x) => x.music = !x.music);
                  onChange();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Pressable(
            onTap: () => app.setAudio((x) => x.demos = !x.demos),
            semanticLabel: tr('player.demos'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: a.demos ? C.jade : C.ivory.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    a.demos ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 20,
                    color: C.ivory,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('player.demos'), style: T.label.c(C.ivory)),
                        const SizedBox(height: 2),
                        Text(
                          tr('player.demosDesc'),
                          style: T.tiny.copyWith(
                            fontWeight: FontWeight.w400,
                            color: C.ivory.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              tr('player.soundscape'),
              style: T.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: C.ivory.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              for (final s in Content.i.soundscapes)
                Pressable(
                  onTap: () {
                    app.setAudio((x) {
                      x.musicTrack = s.id;
                      x.music = true;
                    });
                    onChange();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: a.musicTrack == s.id
                            ? C.ivory
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EImage(img(s.image)),
                          Container(color: C.ink.withValues(alpha: 0.45)),
                          Positioned(
                            left: 10,
                            right: 8,
                            bottom: 8,
                            child: Text(
                              s.name,
                              style: T.tiny.copyWith(
                                fontWeight: FontWeight.w700,
                                color: C.ivory,
                                height: 1.1,
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
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              tr('player.musicVolume'),
              style: T.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: C.ivory.withValues(alpha: 0.6),
              ),
            ),
          ),
          Slider(
            value: a.musicVolume,
            onChanged: (v) {
              app.setAudio((x) => x.musicVolume = v);
              Ambient.setVolume(v * 0.6);
            },
            inactiveColor: C.ivory.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}
