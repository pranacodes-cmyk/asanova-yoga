import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../theme/tokens.dart';

/// Our bundled films are square by contract (`scripts/media/encode-film.py`), so they are
/// laid out square: a file with stray pixel-aspect metadata then still plays undistorted.
/// Licensed network media keeps its own shape.
Size filmBox(VideoPlayerController c, {required bool square}) =>
    square ? Size.square(c.value.size.height) : c.value.size;

/// Muted looping demo film for an exercise (web `DemoFilm`): licensed network media first,
/// then our bundled demo asset. Shows the pose photo until the film is ready, and keeps it on
/// failure. Photo and film share one framing, so the hand-over never jumps; callers give the
/// film a box that is never taller than wide, so a floor pose is never cut at the sides.
class DemoFilm extends StatefulWidget {
  const DemoFilm({
    super.key,
    required this.exercise,
    this.playing = true,
    this.alignment = Alignment.center,
  });
  final Exercise exercise;
  final bool playing;
  final Alignment alignment;
  @override
  State<DemoFilm> createState() => _DemoFilmState();
}

class _DemoFilmState extends State<DemoFilm> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final film = widget.exercise.film;
    if (film == null) return;
    final options = VideoPlayerOptions(mixWithOthers: true);
    final c = film.asset
        ? VideoPlayerController.asset(film.src, videoPlayerOptions: options)
        : VideoPlayerController.networkUrl(
            Uri.parse(film.src),
            videoPlayerOptions: options,
          );
    _c = c;
    c.setLooping(true);
    c.setVolume(0);
    c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          if (widget.playing) c.play();
        })
        .catchError((Object _) {
          // photo stays visible
        });
  }

  @override
  void didUpdateWidget(covariant DemoFilm old) {
    super.didUpdateWidget(old);
    final c = _c;
    if (c == null || !_ready) return;
    widget.playing ? c.play() : c.pause();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return ColoredBox(
      color: C.sand,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            img(widget.exercise.image),
            fit: BoxFit.cover,
            alignment: widget.alignment,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          if (c != null && _ready)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: widget.alignment,
                child: SizedBox.fromSize(
                  size: filmBox(c, square: widget.exercise.film!.asset),
                  child: VideoPlayer(c),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
