import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/scaffold.dart';
import '../widgets/tab_shell.dart';
import '../widgets/ui.dart';

class MeditateScreen extends StatefulWidget {
  const MeditateScreen({super.key});
  @override
  State<MeditateScreen> createState() => _MeditateScreenState();
}

class _MeditateScreenState extends State<MeditateScreen> {
  String cat = 'All';
  String? get playing =>
      Ambient.state.value.playing ? Ambient.state.value.key : null;

  void _onAmbient() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Ambient.state.addListener(_onAmbient);
  }

  @override
  void dispose() {
    Ambient.state.removeListener(_onAmbient);
    super.dispose();
  }

  void _toggleSound(String id) {
    if (playing == id) {
      Ambient.pause();
    } else {
      Ambient.play(id, 0.55);
    }
  }

  void _open(String id, bool premium) {
    if (isMeditationLocked(id, premium)) {
      context.push('/paywall?from=meditation');
    } else {
      context.push('/meditation/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final premium = app.premium.active;
    final c = Content.i;
    final list = c.meditations
        .where((m) => cat == 'All' || m.category == cat)
        .toList();
    final featured = c.meditation(
      featuredMeditationId(DateTime.now().hour, app.premium.active),
    )!;
    final offline = c.meditations
        .where((m) => app.downloads.contains(m.id))
        .toList();
    final chakras = c.meditations
        .where((m) => m.category == 'Chakras' && m.id != chakraJourneyId)
        .toList();
    final journey = c.meditation(chakraJourneyId);
    final breath = c.meditations.where((m) => m.category == 'Breath').toList();
    final nidra = c.meditations
        .where((m) => m.category == 'Yoga Nidra')
        .toList();

    return AsanovaScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: topInset(context) + 18,
          bottom: tabBarSpace(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meditate', style: T.displayLg),
                  const SizedBox(height: 4),
                  Text(
                    '${c.meditations.length} guided sessions · breath, chakras, Yoga Nidra and sleep.',
                    style: T.bodySm.c(C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Reveal(
              delay: 0.05,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Pressable(
                  onTap: () => _open(featured.id, premium),
                  child: Container(
                    height: 320,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: S.float,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        KenBurns(child: EImage(img(featured.image))),
                        DecoratedBox(
                          decoration: BoxDecoration(gradient: G.scrim),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Eyebrow(
                                      'Featured · ${featured.category} · ${featured.minutes} min',
                                      color: C.ivory.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      featured.title,
                                      style: T.displayMd.c(C.ivory),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      featured.about.isNotEmpty
                                          ? featured.about
                                          : featured.subtitle,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.caption.copyWith(
                                        fontSize: 13.5,
                                        height: 1.45,
                                        color: C.ivory.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: C.ivory,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 32,
                                  color: C.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              delay: 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Pressable(
                  onTap: () => context.push('/breathe'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: G.jade,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: S.card,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _BreathDot(),
                              Icon(LucideIcons.wind, size: 28, color: C.ivory),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Breathing coach',
                                style: T.title.c(C.ivory),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Box, 4-7-8 & calm breathing · 1–5 min',
                                style: T.caption.c(
                                  C.ivory.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          LucideIcons.arrowRight,
                          size: 20,
                          color: C.ivory,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (chakras.isNotEmpty) ...[
              const SizedBox(height: 36),
              Reveal(
                delay: 0.12,
                child: _ChakraPath(
                  chakras: chakras,
                  journey: journey,
                  premium: premium,
                  onOpen: (id) => _open(id, premium),
                ),
              ),
            ],
            if (breath.isNotEmpty) ...[
              const SizedBox(height: 36),
              Reveal(
                delay: 0.14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Pranayama'),
                    const _ShelfNote(
                      'The classic breathing practices of yoga, each with a guided rhythm.',
                    ),
                    HScroll(
                      gap: 12,
                      children: [
                        for (final m in breath)
                          _MedCard(
                            m,
                            width: 168,
                            height: 220,
                            locked: isMeditationLocked(m.id, premium),
                            onTap: () => _open(m.id, premium),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (nidra.isNotEmpty) ...[
              const SizedBox(height: 32),
              Reveal(
                delay: 0.16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Yoga Nidra'),
                    const _ShelfNote(
                      'Yogic sleep: lie down, listen, and rest more deeply than a nap.',
                    ),
                    HScroll(
                      gap: 12,
                      children: [
                        for (final m in nidra)
                          _MedCard(
                            m,
                            width: 268,
                            height: 176,
                            locked: isMeditationLocked(m.id, premium),
                            onTap: () => _open(m.id, premium),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            const SectionHeader('All sessions'),
            HScroll(
              gap: 8,
              children: [
                for (final m in c.meditationCategories)
                  ChipPill(
                    label: m,
                    active: cat == m,
                    onTap: () => setState(() => cat = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final (i, m) in list.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Reveal(
                        key: ValueKey('$cat-${m.id}'),
                        delay: 0.04 + i * 0.02,
                        child: MeditationRow(
                          m,
                          locked: isMeditationLocked(m.id, premium),
                          onTap: () => _open(m.id, premium),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SectionHeader('Soundscapes'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  for (final s in c.soundscapes)
                    Pressable(
                      onTap: () => _toggleSound(s.id),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: S.soft,
                          border: Border.all(
                            color: playing == s.id
                                ? C.jade
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EImage(img(s.image)),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xFF111A15)
                                        .withValues(alpha: 0.8),
                                  ],
                                  stops: const [0.2, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: C.ivory.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  playing == s.id
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 20,
                                  color: C.ink,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              bottom: 12,
                              child: Row(
                                children: [
                                  if (playing == s.id) ...[
                                    const _Equalizer(),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    s.name,
                                    style: T.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: C.ivory,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (offline.isNotEmpty) ...[
              const SizedBox(height: 36),
              const SectionHeader('Available offline'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final m in offline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MeditationRow(
                          m,
                          locked: isMeditationLocked(m.id, premium),
                          onTap: () => _open(m.id, premium),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One muted line under a shelf title.
class _ShelfNote extends StatelessWidget {
  const _ShelfNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
    child: Text(text, style: T.caption.copyWith(height: 1.45)),
  );
}

/// Image card for the Pranayama and Yoga Nidra shelves.
class _MedCard extends StatelessWidget {
  const _MedCard(
    this.m, {
    required this.width,
    required this.height,
    required this.locked,
    required this.onTap,
  });
  final Meditation m;
  final double width, height;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: S.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EImage(img(m.image)),
            DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
            Positioned(
              left: 12,
              top: 12,
              child: Glass(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, size: 13, color: C.ivory),
                    const SizedBox(width: 4),
                    Text('${m.minutes} min', style: T.tiny.c(C.ivory)),
                  ],
                ),
              ),
            ),
            if (locked)
              const Positioned(right: 12, top: 12, child: PremiumBadge()),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.title
                        .c(C.ivory)
                        .copyWith(fontSize: 17, height: 1.15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.tiny.c(C.ivory.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The seven chakras from root to crown as a connected path of image orbs, with the full
/// root-to-crown sitting beneath it.
class _ChakraPath extends StatelessWidget {
  const _ChakraPath({
    required this.chakras,
    required this.journey,
    required this.premium,
    required this.onOpen,
  });
  final List<Meditation> chakras;
  final Meditation? journey;
  final bool premium;
  final void Function(String id) onOpen;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Row(
            children: [
              const Icon(LucideIcons.flower2, size: 13, color: C.gold),
              const SizedBox(width: 6),
              Eyebrow('Root to crown', color: C.gold),
            ],
          ),
        ),
        const SectionHeader('The chakra path'),
        const _ShelfNote(
          "Yoga's traditional map of seven centres, each with its own image and seed sound.",
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, m) in chakras.indexed)
                _ChakraOrb(
                  m,
                  first: i == 0,
                  last: i == chakras.length - 1,
                  locked: isMeditationLocked(m.id, premium),
                  onTap: () => onOpen(m.id),
                ),
            ],
          ),
        ),
        if (journey != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MeditationRow(
              journey!,
              locked: isMeditationLocked(journey!.id, premium),
              onTap: () => onOpen(journey!.id),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChakraOrb extends StatelessWidget {
  const _ChakraOrb(
    this.m, {
    required this.first,
    required this.last,
    required this.locked,
    required this.onTap,
  });
  final Meditation m;
  final bool first, last, locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final parts = m.title.split(' · ');
    final sanskrit = parts.first;
    final english = parts.length > 1 ? parts[1] : '';
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            SizedBox(
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: first ? Colors.transparent : C.sandDeep,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: last ? Colors.transparent : C.sandDeep,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      shape: BoxShape.circle,
                      boxShadow: S.soft,
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EImage(img(m.image)),
                          if (locked)
                            Container(
                              color: C.ink.withValues(alpha: 0.3),
                              child: const Icon(
                                LucideIcons.lock,
                                size: 15,
                                color: C.ivory,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sanskrit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.label.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              english,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.tiny.c(C.jade),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreathDot extends StatefulWidget {
  const _BreathDot();
  @override
  State<_BreathDot> createState() => _BreathDotState();
}

class _BreathDotState extends State<_BreathDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Transform.scale(
      scale: 0.7 + 0.3 * (0.5 - 0.5 * math.cos(2 * math.pi * _c.value)),
      child: Container(
        decoration: BoxDecoration(
          color: C.ivory.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _Equalizer extends StatefulWidget {
  const _Equalizer();
  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => SizedBox(
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Container(
              width: 3,
              height:
                  14 *
                  (0.3 +
                      0.7 *
                          (0.5 -
                              0.5 *
                                  math.cos(
                                    2 * math.pi * ((_c.value + i * 0.15) % 1),
                                  ))),
              decoration: BoxDecoration(
                color: C.ivory,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
