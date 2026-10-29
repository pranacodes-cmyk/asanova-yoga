import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../i18n/i18n.dart';
import '../data/content.dart';
import '../logic/coach.dart';
import '../logic/lesson_media.dart';
import '../services/audio_service.dart';
import '../services/media_store.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'breath_orb.dart';
import 'scaffold.dart';
import 'ui.dart';

/// Gate in front of a lesson or meditation player (web `LessonPrepare`): when the lesson's films
/// and voice are already on the phone (or bundled) the player opens immediately; otherwise the
/// tutor breathes with the person (bundled breath cues) while the files download with real
/// progress, then the player opens. Failures keep what finished and offer a retry.
class LessonPrepare extends StatefulWidget {
  const LessonPrepare({super.key, required this.paths, required this.child});
  final List<String> paths;
  final Widget child;
  @override
  State<LessonPrepare> createState() => _LessonPrepareState();
}

class _LessonPrepareState extends State<LessonPrepare> {
  late List<String> _missing = MediaStore.missing(widget.paths);
  late final AppState app = context.read<AppState>();
  int _done = 0;
  bool _failed = false, _cancelled = false;
  int _total = 0;
  BreathCycle? _cycle;

  bool get _ready => _missing.isEmpty;

  @override
  void initState() {
    super.initState();
    if (_ready) return;
    _cycle = BreathCycle(
      const [4, 1, 5, 1],
      onPhase: (ph) {
        if (!app.audio.voice || _ready || _failed) return;
        if (ph == BreathPhase.inhale) {
          Voice.say(CoachLines.breath(CoachBreath.inhale));
        }
        if (ph == BreathPhase.exhale) {
          Voice.say(CoachLines.breath(CoachBreath.exhale));
        }
      },
    )..setRunning(true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && app.audio.voice && !_ready) {
        Voice.say(CoachLines.breath(CoachBreath.inhale));
      }
    });
    _syncMusic();
    _run();
  }

  void _syncMusic() {
    if (app.audio.music) {
      Ambient.play(app.audio.musicTrack, app.audio.musicVolume * 0.6);
    } else {
      Ambient.pause();
    }
  }

  Future<void> _run() async {
    setState(() {
      _failed = false;
      _done = 0;
      _total = _missing.length;
    });
    _cycle?.setRunning(true);
    try {
      await MediaStore.download(
        _missing,
        onProgress: (d, _) {
          if (mounted) setState(() => _done = d);
        },
        cancelled: () => _cancelled || !mounted,
      );
      if (!mounted || _cancelled) return;
      Voice.stop();
      _cycle?.setRunning(false);
      setState(() => _missing = MediaStore.missing(widget.paths));
      if (!_ready) setState(() => _failed = true);
    } catch (_) {
      if (!mounted) return;
      Voice.stop();
      _cycle?.setRunning(false);
      setState(() {
        _failed = true;
        _missing = MediaStore.missing(widget.paths);
      });
    }
  }

  void _close() {
    _cancelled = true;
    Voice.stop();
    Ambient.stop();
    context.canPop() ? context.pop() : context.go('/');
  }

  @override
  void dispose() {
    _cancelled = true;
    _cycle?.dispose();
    if (!_ready) {
      Voice.stop();
      Ambient.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final pct = downloadPercent(_done, _total);
    final cycle = _cycle;
    return EnsoScaffold(
      background: C.forest,
      lightIcons: true,
      body: LayoutBuilder(builder: (context, box) {
        final compact = box.maxHeight < 660;
        return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(children: [
            SizedBox(
              height: math.min(390.0, box.maxHeight * (compact ? 0.40 : 0.46)),
              child: Stack(fit: StackFit.expand, children: [
                EImage(img('tutor-seat')),
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [C.forest.withValues(alpha: 0.12), C.forest.withValues(alpha: 0.05), C.forest],
                  stops: const [0, 0.55, 1],
                ))),
                Positioned(top: topInset(context) + 8, left: 16, right: 16,
                  child: Row(children: [
                    CircleBtn(icon: LucideIcons.x, tone: Tone.dark,
                      label: tr('prepare.cancel'), onTap: _close),
                    const Spacer(),
                    Text(tr('welcome.brandName'), style: T.label.c(C.ivory)),
                    const Spacer(),
                    CircleBtn(icon: app.audio.music ? LucideIcons.music2 : LucideIcons.volumeX,
                      tone: Tone.dark, label: tr(app.audio.music ? 'player.musicOn' : 'player.musicOff'),
                      onTap: () {
                        app.setAudio((a) => a.music = !a.music);
                        _syncMusic();
                        setState(() {});
                      }),
                  ])),
              ]),
            ),
            Padding(padding: EdgeInsets.fromLTRB(28, 8, 28, bottomInset(context) + (compact ? 16 : 24)),
              child: Column(children: [
                Text(tr(_failed ? 'prepare.failedTitle' : 'prepare.title'),
                  textAlign: TextAlign.center, style: T.displayMd.c(C.ivory)),
                const SizedBox(height: 12),
                Text(tr(_failed ? 'prepare.failedBody' : 'prepare.subtitle'),
                  textAlign: TextAlign.center, style: T.bodySm.c(C.ivory.withValues(alpha: 0.65))),
                SizedBox(height: compact ? 16 : 24),
                SizedBox(width: compact ? 92 : 112, height: compact ? 92 : 112, child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(
                    value: _failed ? 0 : pct / 100, strokeWidth: 2,
                    backgroundColor: C.ivory.withValues(alpha: 0.12), color: C.sage)),
                  if (_failed) const Icon(LucideIcons.wifiOff, color: C.sage, size: 32)
                  else Text(tr('prepare.progress', {'pct': pct}),
                    style: T.displayMd.copyWith(fontSize: 30, color: C.ivory).tab),
                ])),
                SizedBox(height: compact ? 12 : 18),
                if (!_failed && cycle != null) ListenableBuilder(listenable: cycle,
                  builder: (_, _) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(cycle.label, style: T.serifAccent.copyWith(fontSize: 22, color: C.sage)),
                    const SizedBox(width: 12),
                    Text('${cycle.left}', style: T.label.c(C.ivory.withValues(alpha: 0.65)).tab),
                  ])),
                if (_failed) EnsoButton(label: tr('prepare.retry'), icon: LucideIcons.rotateCw,
                  variant: BtnVariant.ivory, onTap: _run),
                SizedBox(height: compact ? 16 : 24),
                LinearProgressIndicator(value: pct / 100, minHeight: 2,
                  backgroundColor: C.ivory.withValues(alpha: 0.12), color: C.sage),
              ])),
          ]),
        ),
        );
      }),
    );
  }
}
