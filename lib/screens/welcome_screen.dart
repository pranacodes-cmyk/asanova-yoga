import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../data/content.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

/// First screen: cinematic tutor film played once (poster image until it plays), headline and the quiz CTA.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  VideoPlayerController? _video;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final v = VideoPlayerController.asset(
      'assets/video/welcome-clear.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = v;
    v
        .initialize()
        .then((_) async {
          if (!mounted) return;
          await v.setVolume(0);
          // cinematic opener plays once and holds its last, eyes-closed frame
          await v.setLooping(false);
          await v.play();
          if (mounted) setState(() => _playing = true);
        })
        .catchError((_) {
          // poster image stays visible if the device cannot play the film
        });
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = topInset(context);
    final bottom = bottomInset(context);
    const focus = Alignment.topCenter;
    final v = _video;
    return EnsoScaffold(
      background: C.forest,
      lightIcons: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: EImage(img('hero-welcome'), alignment: focus),
          ),
          if (v != null && v.value.isInitialized)
            AnimatedOpacity(
              opacity: _playing ? 1 : 0,
              duration: const Duration(milliseconds: 1000),
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: focus,
                  child: SizedBox(
                    width: v.value.size.width,
                    height: v.value.size.height,
                    child: VideoPlayer(v),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 150,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    C.forest.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height * 0.48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    C.forest.withValues(alpha: 0),
                    C.forest.withValues(alpha: 0.8),
                    C.forest,
                  ],
                  stops: [0, 0.38, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, top + 22, 28, bottom + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Reveal(
                  delay: 0.2,
                  dy: -8,
                  child: Row(
                    children: [
                      Image.asset(
                        img('logo-asanova-mark-light.png'),
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr('welcome.brandName'),
                        style: T.label.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: C.ivory,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Reveal(
                  delay: 0.45,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: tr('welcome.headlineBrandLine')),
                        TextSpan(
                          text: tr('welcome.headlineRitualLine'),
                          style: T.serifAccent.copyWith(
                            fontSize: 32,
                            color: C.ivory,
                            height: 1.12,
                          ),
                        ),
                      ],
                    ),
                    style: T.displayXl.copyWith(fontSize: 34, color: C.ivory),
                  ),
                ),
                const SizedBox(height: 28),
                Reveal(
                  delay: 0.85,
                  dy: 20,
                  child: Column(
                    children: [
                      EnsoButton(
                          label: tr('welcome.ctaLabel'),
                          variant: BtnVariant.ivory,
                          trailing: LucideIcons.arrowRight,
                          onTap: () => context.go('/onboarding'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr('welcome.quizNote'),
                        style: T.caption.copyWith(
                          color: C.ivory.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => context.push('/legal/terms'),
                            child: Text(tr('welcome.termsLabel')),
                          ),
                          TextButton(
                            onPressed: () => context.push('/legal/privacy'),
                            child: Text(tr('welcome.privacyShort')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
