import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../theme/tokens.dart';
import 'demo_film.dart';

/// A flow round's continuous film (web `RoundFilm`). A round is one film, cut into a few parts;
/// part [part] (re)starts from its first frame whenever [startKey] changes — the player passes the
/// item that began the part, so the film restarts exactly with the breath cue and never drifts.
///
/// While one part plays, the next one is prepared paused on its first frame, and a part only
/// replaces the one on screen once it is ready. Until then the previous part stays (its last frame
/// is the next part's first), so moving between parts or rounds never flashes a photo or goes black.
class RoundFilm extends StatefulWidget {
  const RoundFilm({
    super.key,
    required this.films,
    required this.part,
    required this.startKey,
    required this.playing,
    required this.poster,
  });

  final List<String> films;
  final int part;
  final String startKey;
  final bool playing;
  final String poster;

  @override
  State<RoundFilm> createState() => _RoundFilmState();
}

class _Slot {
  _Slot(this.film, this.c);
  final String film;
  final VideoPlayerController c;
  bool ready = false;
}

class _RoundFilmState extends State<RoundFilm> {
  static final _options = VideoPlayerOptions(mixWithOthers: true);
  _Slot? _shown, _next;

  /// The prepared slot should take over as soon as it is ready.
  bool _takeOver = false;

  String get _want => widget.films[widget.part];
  String? get _upcoming => widget.films.length > 1
      ? widget.films[(widget.part + 1) % widget.films.length]
      : null;

  _Slot _open(String film, {required bool play}) {
    final c = ourFilmController(film, _options);
    final slot = _Slot(film, c);
    c.setLooping(false);
    c.setVolume(0);
    c
        .initialize()
        .then((_) {
          if (!mounted) return;
          slot.ready = true;
          if (identical(slot, _next) && _takeOver) {
            _swap();
          } else if (identical(slot, _shown)) {
            setState(() {});
            if (play && widget.playing) c.play();
          }
        })
        .catchError((Object _) {
          // the photo (or the part before) stays on screen
          if (identical(slot, _next)) _takeOver = false;
        });
    return slot;
  }

  @override
  void initState() {
    super.initState();
    _shown = _open(_want, play: true);
    _prepareUpcoming();
  }

  /// Opens the part after the one on screen, paused on its first frame.
  void _prepareUpcoming() {
    final up = _upcoming;
    if (up == null || up == _shown?.film || up == _next?.film) return;
    final old = _next;
    _next = _open(up, play: false);
    old?.c.dispose();
  }

  void _start(_Slot s) {
    s.c.seekTo(Duration.zero);
    if (widget.playing) s.c.play();
  }

  /// The prepared part replaces the one on screen.
  void _swap() {
    final next = _next;
    if (next == null) return;
    _takeOver = false;
    final old = _shown;
    _start(next);
    setState(() {
      _shown = next;
      _next = null;
    });
    old?.c.pause();
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.c.dispose());
    _prepareUpcoming();
  }

  @override
  void didUpdateWidget(covariant RoundFilm old) {
    super.didUpdateWidget(old);
    if (old.startKey != widget.startKey || old.films != widget.films) {
      final want = _want;
      final shown = _shown;
      if (shown != null && shown.film == want) {
        _takeOver = false;
        if (shown.ready) _start(shown);
      } else {
        if (_next?.film != want) {
          final stale = _next;
          _next = _open(want, play: false);
          stale?.c.dispose();
        }
        _takeOver = true;
        if (_next!.ready) _swap();
      }
    }
    final s = _shown;
    if (s != null && s.ready && old.playing != widget.playing) {
      widget.playing ? s.c.play() : s.c.pause();
    }
  }

  @override
  void dispose() {
    _shown?.c.dispose();
    _next?.c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _shown;
    return ColoredBox(
      color: C.sand,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            img(widget.poster),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          if (s != null && s.ready)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox.fromSize(
                  size: filmBox(s.c, square: true),
                  child: VideoPlayer(s.c),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
