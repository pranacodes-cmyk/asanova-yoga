import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

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
  // looping cinematic behind the preparation screen (bundled welcome film, muted)
  final VideoPlayerController _film = VideoPlayerController.asset('assets/video/welcome-clear.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
  bool _filmOn = false;

  bool get _ready => _missing.isEmpty;

  @override
  void initState() {
    super.initState();
    _film.initialize().then((_) async {
      if (!mounted) return;
      await _film.setVolume(0);
      await _film.setLooping(true);
      await _film.play();
      if (mounted) setState(() => _filmOn = true);
    }).catchError((_) {});
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
    _film.dispose();
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
      background: C.cream,
      body: Stack(children: [
        Positioned.fill(top: MediaQuery.sizeOf(context).height * 0.3, child: IgnorePointer(child: Stack(fit: StackFit.expand, children: [
          if (_filmOn) FittedBox(fit: BoxFit.cover, alignment: Alignment.topCenter,
            child: SizedBox(width: _film.value.size.width, height: _film.value.size.height, child: VideoPlayer(_film)))
          else EImage(img('hero-welcome'), fit: BoxFit.cover, alignment: Alignment.topCenter),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [C.cream, C.cream.withValues(alpha: 0.1), C.cream.withValues(alpha: 0.1), C.cream, C.cream],
            stops: const [0, 0.18, 0.55, 0.72, 1]))),
        ]))),
        LayoutBuilder(builder: (context, box) {
        final compact = box.maxHeight < 660;
        return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(children: [
            Padding(padding: EdgeInsets.fromLTRB(16, topInset(context) + 8, 16, 0),
              child: Row(children: [
                CircleBtn(icon: LucideIcons.x, label: tr('prepare.cancel'), onTap: _close),
                const Spacer(),
                Text(tr('welcome.brandName'), style: T.label.c(C.ink)),
                const Spacer(),
                CircleBtn(icon: app.audio.music ? LucideIcons.music2 : LucideIcons.volumeX,
                  label: tr(app.audio.music ? 'player.musicOn' : 'player.musicOff'),
                  onTap: () {
                    app.setAudio((a) => a.music = !a.music);
                    _syncMusic();
                    setState(() {});
                  }),
              ])),
            Padding(padding: EdgeInsets.fromLTRB(24, compact ? 16 : 28, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(_failed ? 'prepare.failedTitle' : 'prepare.title'),
                  style: T.displayMd.copyWith(fontSize: 30, height: 1.15, color: C.ink)),
                const SizedBox(height: 10),
                Text(tr(_failed ? 'prepare.failedBody' : 'prepare.subtitle'),
                  style: T.bodySm.c(C.muted)),
              ])),
            SizedBox(height: compact ? 12 : 20),
            SizedBox(height: math.min(330.0, box.maxHeight * (compact ? 0.32 : 0.38))),
            Padding(padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset(context) + 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Icon(_failed ? LucideIcons.wifiOff : LucideIcons.download, color: C.jade, size: 22),
                  Text(tr('prepare.progress', {'pct': pct}),
                    style: T.displayMd.copyWith(fontSize: 36, color: C.ink).tab),
                ]),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: pct / 100, minHeight: 4,
                  backgroundColor: C.sandDeep, color: C.jade),
                SizedBox(height: compact ? 20 : 28),
                if (!_failed && cycle != null) ListenableBuilder(listenable: cycle,
                  builder: (_, _) => Row(children: [
                    const Icon(LucideIcons.wind, color: C.sage, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Text(cycle.label, style: T.serifAccent.copyWith(fontSize: 22, color: C.ink))),
                    Text('${cycle.left}', style: T.label.c(C.muted).tab),
                  ])),
                if (_failed) EnsoButton(label: tr('prepare.retry'), icon: LucideIcons.rotateCw,
                  onTap: _run),
              ])),
          ]),
        ),
        );
      }),
      ]),
    );
  }
}
