import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/lesson_media.dart';
import '../services/media_store.dart';
import '../theme/tokens.dart';

/// Our films are square by contract (`scripts/media/encode-film.py`), so they are laid out
/// square: a file with stray pixel-aspect metadata then still plays undistorted.
/// Licensed network media keeps its own shape.
Size filmBox(VideoPlayerController c, {required bool square}) =>
    square ? Size.square(c.value.size.height) : c.value.size;

/// Muted looping demo film (web `DemoFilm`): an exercise's film, a flow's sequence film or a
/// tutor film. Our films play from the phone when downloaded, else from the app bundle, else
/// stream from the media server; licensed media streams from its own URL. Shows the poster
/// photo until the film is ready, and keeps it on failure. Photo and film share one framing,
/// so the hand-over never jumps; callers give the film a box never taller than wide.
class DemoFilm extends StatefulWidget {
  DemoFilm({
    super.key,
    required Exercise exercise,
    this.playing = true,
    this.loop = true,
    this.alignment = Alignment.center,
  }) : film = exercise.video == null ? exercise.demo : null,
       licensed = exercise.video,
       poster = exercise.image;

  /// A film by key (flow sequence or tutor film) over the [poster] image.
  const DemoFilm.keyed({
    super.key,
    required String this.film,
    required this.poster,
    this.playing = true,
    this.loop = true,
    this.alignment = Alignment.center,
  }) : licensed = null;

  final String? film, licensed;
  final String poster;
  final bool playing, loop;
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
    final options = VideoPlayerOptions(mixWithOthers: true);
    final VideoPlayerController c;
    if (widget.licensed != null) {
      c = VideoPlayerController.networkUrl(
        Uri.parse(widget.licensed!),
        videoPlayerOptions: options,
      );
    } else if (widget.film != null) {
      final src = MediaStore.source(filmPath(widget.film!));
      c = switch (src.origin) {
        MediaOrigin.file => VideoPlayerController.file(
          File(src.path),
          videoPlayerOptions: options,
        ),
        MediaOrigin.asset => VideoPlayerController.asset(
          src.path,
          videoPlayerOptions: options,
        ),
        MediaOrigin.network => VideoPlayerController.networkUrl(
          Uri.parse(src.path),
          videoPlayerOptions: options,
        ),
      };
    } else {
      return;
    }
    _c = c;
    c.setLooping(widget.loop);
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
            img(widget.poster),
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
                  size: filmBox(c, square: widget.licensed == null),
                  child: VideoPlayer(c),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
