import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../i18n/i18n.dart';
import '../logic/logic.dart';
import '../services/audio_service.dart';
import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/confetti.dart';
import '../widgets/paywall_film.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

/// Music that runs under the onboarding quiz; the onboarding paywall is where it ends.
const _onbTrack = 'music-bamboo';

/// Paywall variants:
/// - standard (first): normal-price yearly + monthly + lifetime — no trial
/// - regular (revealed by the close survey): yearly with a 7-day free trial + monthly + lifetime
/// - gift: discounted yearly, monthly and lifetime — no trial
/// - exit: one lower yearly offer after "the price feels high" — no trial
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.from, this.offer = 'standard'});
  final String from;
  final String offer;
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late String selected;
  late String variant;
  bool busy = false;
  bool surveyOpen = false;
  String? reveal;

  List<Offer> get _offers => [
    for (final o in switch (variant) {
      'gift' => giftOffers,
      'exit' => [exitOffer],
      'regular' => regularOffers,
      _ => standardOffers,
    })
      PurchaseService.localized(o),
  ];

  int get _trialDays => regularOffers.first.trialDays;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    variant = paywallVariant(widget.from, widget.offer, app.paywallOffer);
    // The last offer seen in onboarding is the one the app keeps offering.
    if (widget.from == 'onboarding') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => app.setPaywallOffer(variant),
      );
    }
    selected = _offers.first.id;
    // Real store prices replace the placeholders as soon as they load.
    PurchaseService.warmUp().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Onboarding music runs until the person leaves the onboarding paywall.
    if (widget.from == 'onboarding' && Ambient.state.value.key == _onbTrack) {
      Ambient.stop();
    }
    super.dispose();
  }

  void _leave() {
    if (widget.from == 'onboarding' || !context.canPop()) {
      context.go('/');
    } else {
      context.pop();
    }
  }

  /// Ask once why, then reveal the matching offer before showing its paywall.
  Future<void> _close() async {
    if (surveyOpen) return;
    final app = context.read<AppState>();
    if (!shouldAskExitSurvey(variant, app.exitSurveyAsked)) {
      _leave();
      return;
    }
    app.markExitSurveyAsked();
    surveyOpen = true;
    final reason = await showEnsoSheet<String>(
      context,
      builder: (_) => _ExitSurvey(trialDays: _trialDays),
    );
    if (!mounted) return;
    surveyOpen = false;
    if (reason == null) return;
    // Re-check trial eligibility right before choosing, in case offerings loaded late.
    await PurchaseService.warmUp();
    if (!mounted) return;
    final next = paywallSurveyOffer(
      reason,
      trialAvailable: PurchaseService.trialAvailable,
    );
    if (next == null) return;
    setState(() => reveal = next);
  }

  void _showRevealedOffer() {
    final next = reveal;
    if (next == null) return;
    setState(() {
      variant = next;
      selected = _offers.first.id;
      reveal = null;
    });
    context.read<AppState>().setPaywallOffer(next);
  }

  Future<void> _buy() async {
    if (busy) return;
    setState(() => busy = true);
    final ok = await PurchaseService.purchase(selected);
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) {
      final error = PurchaseService.lastError;
      if (error != null) {
        Toast.show(tr('paywall.purchaseFailed'), description: error);
      }
      return;
    }
    final bought = _offers.firstWhere((o) => o.id == selected);
    context.read<AppState>().setPremium(selected);
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => _Celebration(offer: bought),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    if (mounted) _leave();
  }

  String _terms(Offer offer) {
    if (offer.id == 'lifetime') {
      return tr('paywall.termsLifetime', {'price': offer.price});
    }
    if (offer.trialDays > 0) {
      return tr('paywall.termsTrial', {
        'days': offer.trialDays,
        'price': offer.price,
        'period': offer.period,
      });
    }
    return tr('paywall.termsStandard', {
      'price': offer.price,
      'period': offer.period,
    });
  }

  /// Film height: the full 16:9 frame; tall phones grow it (cropping only studio wall), short
  /// phones shrink it so the plans and the button stay on one screen (web `.paywall-cover`).
  double _coverHeight(BuildContext context, double width) {
    final h = MediaQuery.sizeOf(context).height;
    if (h > 720) return math.max(width * 9 / 16, math.min(h * 0.4, 420.0));
    return math.min(width * 9 / 16, h <= 600 ? 180.0 : 230.0);
  }

  @override
  Widget build(BuildContext context) {
    final offers = _offers;
    final offer = offers.firstWhere(
      (o) => o.id == selected,
      orElse: () => offers.first,
    );
    final isExit = variant == 'exit';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) {
          if (reveal != null) {
            _leave();
          } else {
            _close();
          }
        }
      },
      child: reveal != null
          ? _OfferReveal(
              lower: reveal == 'exit',
              trialDays: _trialDays,
              offer: PurchaseService.localized(
                reveal == 'exit' ? exitOffer : regularOffers.first,
              ),
              onContinue: _showRevealedOffer,
              onSkip: _leave,
            )
          : EnsoScaffold(
              body: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) => SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: _coverHeight(context, bounds.maxWidth),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PaywallFilm(key: ValueKey(isExit), exit: isExit),
                                  Positioned(
                                    top: topInset(context) + 6,
                                    right: 16,
                                    child: CircleBtn(
                                      icon: LucideIcons.x,
                                      tone: Tone.dark,
                                      label: tr('common.close'),
                                      onTap: busy ? null : _close,
                                    ),
                                  ),
                                  // dark glass keeps the label readable over any film frame
                                  Positioned(
                                    left: 14,
                                    bottom: 10,
                                    child: Glass(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            LucideIcons.crown,
                                            size: 12,
                                            color: C.gold,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            tr('paywall.plusBadge'),
                                            style: T.tiny.copyWith(
                                              fontSize: 11,
                                              letterSpacing: 1,
                                              fontWeight: FontWeight.w700,
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('paywall.heroTitle'),
                                    style: T.displayMd.copyWith(
                                      fontSize: 25,
                                      height: 1.12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (final (icon, text) in [
                                    (
                                      LucideIcons.layers,
                                      tr('paywall.progressiveCourses', {
                                        'n': Content.i.plans
                                            .where((p) => p.days.length > 1)
                                            .length,
                                      }),
                                    ),
                                    (LucideIcons.leaf, tr('paywall.styles')),
                                    (
                                      LucideIcons.moon,
                                      tr('paywall.guidedMeditations', {
                                        'n': Content.i.meditations.length,
                                      }),
                                    ),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(icon, size: 17, color: C.jade),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              text,
                                              style: T.bodySm.copyWith(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 22,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isExit
                                              ? LucideIcons.gift
                                              : offer.trialDays > 0
                                              ? LucideIcons.check
                                              : LucideIcons.crown,
                                          size: 16,
                                          color: C.jadeDeep,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isExit
                                                ? tr(
                                                    'paywall.exclusiveYearlySaving',
                                                  )
                                                : offer.trialDays > 0
                                                ? tr('paywall.daysOnUs', {
                                                    'days': offer.trialDays,
                                                  })
                                                : tr(
                                                    'paywall.everyCourseEveryClass',
                                                  ),
                                            style: T.caption
                                                .s(12)
                                                .c(C.jadeDeep),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Subscriptions side by side; Lifetime gets its own full-width
                                  // row below, so no price ever wraps or gets cut.
                                  Semantics(
                                    label: tr('paywall.subscriptionPlan'),
                                    container: true,
                                    child: Column(
                                      children: [
                                        IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              for (final (i, o)
                                                  in offers
                                                      .where(
                                                        (o) =>
                                                            o.id != 'lifetime',
                                                      )
                                                      .indexed) ...[
                                                if (i > 0)
                                                  const SizedBox(width: 8),
                                                Expanded(
                                                  child: _OfferCard(
                                                    offer: o,
                                                    compact: !isExit,
                                                    selected: selected == o.id,
                                                    onTap: busy
                                                        ? null
                                                        : () => setState(
                                                            () =>
                                                                selected = o.id,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        for (final o in offers.where(
                                          (o) => o.id == 'lifetime',
                                        ))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: _OfferCard(
                                              offer: o,
                                              selected: selected == o.id,
                                              onTap: busy
                                                  ? null
                                                  : () => setState(
                                                      () => selected = o.id,
                                                    ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Full width so the links centre like the web `justify-center` row.
                                  SizedBox(
                                    width: double.infinity,
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      children: [
                                        // Other variants are only explored during onboarding; afterwards
                                        // the app keeps that offer.
                                        if ((variant == 'standard' ||
                                                variant == 'regular') &&
                                            widget.from == 'onboarding')
                                          EnsoButton(
                                            label: tr('paywall.viewAllPlans'),
                                            variant: BtnVariant.ghost,
                                            size: BtnSize.sm,
                                            expand: false,
                                            onTap: busy
                                                ? null
                                                : () => context.push(
                                                    '/paywall?from=${widget.from}&offer=gift',
                                                  ),
                                          ),
                                        EnsoButton(
                                          label: tr('paywall.restorePurchase'),
                                          variant: BtnVariant.ghost,
                                          size: BtnSize.sm,
                                          expand: false,
                                          onTap: busy
                                              ? null
                                              : () async {
                                                  final app = context
                                                      .read<AppState>();
                                                  final restored =
                                                      await PurchaseService.restore();
                                                  Toast.show(
                                                    restored
                                                        ? tr(
                                                            'paywall.purchaseRestored',
                                                          )
                                                        : tr(
                                                            'paywall.noPreviousPurchaseFound',
                                                          ),
                                                  );
                                                  if (restored && mounted) {
                                                    if (!app.premium.active) {
                                                      app.setPremium('yearly');
                                                    }
                                                    _leave();
                                                  }
                                                },
                                        ),
                                      ],
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      bottomInset(context) + 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EnsoButton(
                          label: offer.trialDays > 0
                              ? tr('paywall.startTrialDays', {
                                  'days': offer.trialDays,
                                })
                              : tr('paywall.continueWith', {
                                  'title':
                                      offer.id == 'gift' || offer.id == 'exit'
                                      ? tr('paywall.yearly')
                                      : offer.title,
                                }),
                          loading: busy,
                          onTap: busy ? null : _buy,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _terms(offer),
                          textAlign: TextAlign.center,
                          style: T.tiny.copyWith(
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            for (final (label, doc) in [
                              (tr('paywall.termsOfUse'), 'terms'),
                              (tr('paywall.privacyPolicy'), 'privacy'),
                            ])
                              Pressable(
                                onTap: () => context.push('/legal/$doc'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    label,
                                    style: T.tiny.copyWith(
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: C.muted,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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

/// Exit survey shown once, the first time the regular paywall is closed.
class _ExitSurvey extends StatelessWidget {
  const _ExitSurvey({required this.trialDays});
  final int trialDays;
  @override
  Widget build(BuildContext context) {
    final reasons = [
      (
        'price',
        LucideIcons.tag,
        tr('paywall.reasonPriceLabel'),
        tr('paywall.reasonPriceHint'),
      ),
      (
        'later',
        LucideIcons.leaf,
        tr('paywall.reasonLaterLabel'),
        tr('paywall.reasonLaterHint', {'days': trialDays}),
      ),
      (
        'unsure',
        LucideIcons.circleHelp,
        tr('paywall.reasonUnsureLabel'),
        tr('paywall.reasonUnsureHint'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.jadeSoft, C.sand],
              ),
              boxShadow: S.soft,
            ),
            child: const Icon(
              LucideIcons.heartHandshake,
              size: 28,
              color: C.jadeDeep,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('paywall.beforeYouGo'),
            textAlign: TextAlign.center,
            style: T.displayMd.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 6),
          Text(
            tr('paywall.exitSurveySubtitle'),
            textAlign: TextAlign.center,
            style: T.bodySm.c(C.muted),
          ),
          const SizedBox(height: 20),
          for (final (i, (id, icon, label, hint)) in reasons.indexed)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 380 + i * 90),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - t)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: C.line),
                      boxShadow: S.soft,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: id == 'price' ? C.goldSoft : C.jadeSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: id == 'price' ? C.ink : C.jadeDeep,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: T.bodySm.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(hint, style: T.caption.c(C.muted)),
                            ],
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: C.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Offer reveal after the survey — deliberately separate from a confirmed purchase.
class _OfferReveal extends StatelessWidget {
  const _OfferReveal({
    required this.lower,
    required this.trialDays,
    required this.offer,
    required this.onContinue,
    required this.onSkip,
  });
  final bool lower;
  final int trialDays;
  final Offer offer;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: C.cream,
      child: Stack(
        children: [
          if (!reduceMotion)
            const Positioned.fill(child: Confetti(height: 650)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: CircleBtn(
                      icon: LucideIcons.x,
                      label: tr('paywall.closeOffer'),
                      onTap: onSkip,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                              duration: Duration(
                                milliseconds: reduceMotion ? 0 : 900,
                              ),
                              curve: Curves.elasticOut,
                              builder: (_, t, child) =>
                                  Transform.scale(scale: t, child: child),
                              child: Container(
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: C.goldSoft,
                                  boxShadow: S.soft,
                                ),
                                child: Icon(
                                  lower ? LucideIcons.gift : LucideIcons.crown,
                                  size: 52,
                                  color: C.jadeDeep,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              lower
                                  ? tr('paywall.lowerPriceReady')
                                  : tr('paywall.trialReady', {
                                      'days': trialDays,
                                    }),
                              textAlign: TextAlign.center,
                              style: T.displayMd.copyWith(fontSize: 30),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              lower
                                  ? tr('paywall.lowerPriceDetail', {
                                      'price': offer.price,
                                    })
                                  : tr('paywall.trialDetail', {
                                      'days': trialDays,
                                    }),
                              textAlign: TextAlign.center,
                              style: T.body.c(C.jadeDeep),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              lower
                                  ? tr('paywall.billedYearlyNote')
                                  : tr('paywall.eligibleYearlyNote'),
                              textAlign: TextAlign.center,
                              style: T.bodySm.c(C.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  EnsoButton(
                    label: lower
                        ? tr('paywall.seeLowerPrice')
                        : tr('paywall.seeTrialPlan'),
                    onTap: onContinue,
                  ),
                  const SizedBox(height: 8),
                  EnsoButton(
                    label: tr('paywall.continueWithFreeSessions'),
                    variant: BtnVariant.ghost,
                    onTap: onSkip,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen celebration after a purchase or trial start (web `Celebration`).
class _Celebration extends StatelessWidget {
  const _Celebration({required this.offer});
  final Offer offer;
  @override
  Widget build(BuildContext context) {
    final trial = offer.trialDays > 0;
    final ends = DateTime.now().add(Duration(days: offer.trialDays));
    final perks = [
      tr('paywall.perkEveryCourse'),
      tr('paywall.perkAllMeditations'),
      if (trial)
        tr('paywall.perkTrialReminder')
      else
        tr('paywall.perkCancelAnytime'),
    ];
    Widget rise(int i, Widget child) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + i * 120),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: c),
      ),
      child: child,
    );
    return Material(
      color: C.cream,
      child: Stack(
        children: [
          const Positioned.fill(child: Confetti(height: 900)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                children: [
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.elasticOut,
                    builder: (_, t, c) => Transform.scale(scale: t, child: c),
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [C.goldSoft, C.gold],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: C.gold.withValues(alpha: 0.45),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.crown,
                        size: 52,
                        color: C.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  rise(
                    0,
                    Text(
                      trial
                          ? tr('paywall.trialStarted')
                          : tr('paywall.welcomeToPlus'),
                      textAlign: TextAlign.center,
                      style: T.displayMd.copyWith(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 10),
                  rise(
                    1,
                    Text(
                      trial
                          ? tr('paywall.enjoyUntil', {
                              'date': DateFormat.MMMd(appLocale).format(ends),
                            })
                          : tr('paywall.everyCourseClassMeditation'),
                      textAlign: TextAlign.center,
                      style: T.body.c(C.muted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final (i, p) in perks.indexed)
                    rise(
                      2 + i,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: C.jade,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.check,
                                size: 15,
                                color: C.ivory,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p,
                                style: T.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  rise(
                    6,
                    EnsoButton(
                      label: tr('paywall.startPracticing'),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final Offer offer;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    button: true,
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.jadeSoft : C.ivory,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? C.jade : C.line, width: 2),
        ),
        child: compact ? _compact() : _row(),
      ),
    ),
  );

  Widget _compact() => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 72),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                offer.id == 'gift' ? tr('paywall.yearly') : offer.title,
                style: T.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: C.ink,
                  height: 1.2,
                ),
              ),
            ),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 16,
              color: selected ? C.jade : C.muted,
            ),
          ],
        ),
        // Local prices like "₹2,799.00" stay on one line (scaled down, never cut).
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            offer.price,
            maxLines: 1,
            softWrap: false,
            style: T.body.copyWith(fontWeight: FontWeight.w700).tab,
          ),
        ),
        Text(
          offer.trialDays > 0
              ? tr('paywall.daysFree', {'days': offer.trialDays})
              : offer.period == 'once'
              ? tr('paywall.payOnce')
              : tr('paywall.perPeriod', {'period': offer.period}),
          style: T.tiny.c(selected ? C.jadeDeep : C.muted),
        ),
      ],
    ),
  );

  Widget _row() => Row(
    children: [
      Icon(
        selected ? LucideIcons.circleCheck : LucideIcons.circle,
        size: 22,
        color: selected ? C.jade : C.muted,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              offer.id == 'gift'
                  ? tr('paywall.yearly')
                  : offer.id == 'exit'
                  ? tr('paywall.yearlySpecialPrice')
                  : offer.title,
              style: T.bodySm.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              offer.trialDays > 0
                  ? tr('paywall.dayFreeTrial', {'days': offer.trialDays})
                  : offer.save != null
                  ? offer.save!
                  : offer.period == 'once'
                  ? tr('paywall.payOnceKeepForever')
                  : offer.period == 'month'
                  ? tr('paywall.billedMonthly')
                  : tr('paywall.billedYearly'),
              style: T.caption.c(selected ? C.jadeDeep : C.muted),
            ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (offer.strike != null) ...[
                Text(
                  offer.strike!,
                  style: T.tiny.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: C.muted,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                offer.price,
                style: T.bodySm.copyWith(fontWeight: FontWeight.w800).tab,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            offer.period == 'once'
                ? tr('paywall.oneTime')
                : tr('paywall.perPeriodLower', {'period': offer.period}),
            style: T.caption,
          ),
        ],
      ),
    ],
  );
}
