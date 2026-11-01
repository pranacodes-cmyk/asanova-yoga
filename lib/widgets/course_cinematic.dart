import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../i18n/i18n.dart';
import '../logic/logic.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'demo_film.dart';
import 'player_caption.dart';
import 'ui.dart';
import 'scaffold.dart';

/// Portrait tutor interlude, separate from square practice footage.
class CourseCinematic extends StatelessWidget {
  const CourseCinematic({super.key, required this.film, required this.eyebrow,
    required this.title, required this.caption, required this.running,
    required this.onToggle, required this.onContinue, this.onClose});
  final String film, eyebrow, title, caption;
  final bool running;
  final VoidCallback onToggle, onContinue;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    DemoFilm.keyed(film: film, poster: '$film-poster', playing: running,
      loop: false, portrait: true, contain: true, alignment: Alignment.topCenter),
    const DecoratedBox(decoration: BoxDecoration(gradient: G.courseCinematic)),
    Positioned(top: topInset(context) + 8, left: 16, right: 16,
      child: Row(children: [
        if (onClose != null) CircleBtn(icon: LucideIcons.x, tone: Tone.dark,
          label: tr('common.close'), onTap: () => onClose?.call()),
        const Spacer(),
        CircleBtn(icon: running ? LucideIcons.pause : LucideIcons.play,
          tone: Tone.dark, label: tr(running ? 'common.pause' : 'common.play'), onTap: onToggle),
      ])),
    Positioned(left: 24, right: 24, bottom: bottomInset(context) + 16,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow, color: C.sage),
          const SizedBox(height: 8),
          Text(title, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: T.title.copyWith(fontSize: 23, height: 1.2, color: C.ivory)),
          const SizedBox(height: 14),
          SizedBox(height: 108, child: PlayerCaption(key: ValueKey(caption),
            text: caption, running: running, readingSeconds: speechSeconds([caption]) * 0.5,
            style: T.bodySm.copyWith(fontSize: 17, height: 1.45, color: C.ivory))),
          const SizedBox(height: 16),
          EnsoButton(label: tr('common.continue'), variant: BtnVariant.light,
            icon: LucideIcons.arrowRight, onTap: onContinue),
        ])),
  ]);
}
