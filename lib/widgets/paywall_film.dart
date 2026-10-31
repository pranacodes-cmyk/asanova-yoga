import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../i18n/i18n.dart';
import '../theme/tokens.dart';

/// Full-bleed 16:9 tutor film (1080p, seamless ping-pong loop) for the paywall cover; the wide
/// frame keeps the teacher's whole body inside any cover height. Mirrors web PaywallFilm.
/// `exit` shows the cinematic exit-offer film once and holds its last frame (palms at heart).
class PaywallFilm extends StatefulWidget {
  const PaywallFilm({super.key, this.exit = false});
  final bool exit;
  @override
  State<PaywallFilm> createState() => _PaywallFilmState();
}

class _PaywallFilmState extends State<PaywallFilm> {
  late final _controller = VideoPlayerController.asset(
    widget.exit ? 'assets/video/paywall-exit.mp4' : 'assets/video/paywall-studio.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller
        .initialize()
        .then((_) async {
          await _controller.setVolume(0);
          await _controller.setLooping(!widget.exit);
          if (!mounted) return;
          setState(() => _ready = true);
          if (!MediaQuery.disableAnimationsOf(context)) {
            await _controller.play();
          }
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('paywall.filmLabel'),
    image: true,
    child: ColoredBox(
      color: C.sand,
      child: SizedBox.expand(
        child: _ready
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : Image.asset(
                widget.exit ? 'assets/images/paywall-exit.jpg' : 'assets/images/paywall-studio.jpg',
                fit: BoxFit.cover,
              ),
      ),
    ),
  );
}
