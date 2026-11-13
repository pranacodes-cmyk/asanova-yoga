import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../i18n/i18n.dart';
import '../logic/logic.dart';
import '../services/analytics_service.dart';
import '../services/market_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/paywall_film.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

/// India paywall (web: src/components/enso/UpiPaywall.tsx): one plan — ₹2 for the first day
/// highlighted, then ₹399/month by UPI Autopay — paid in a UPI app the person picks.
class UpiPaywallScreen extends StatefulWidget {
  const UpiPaywallScreen({super.key, required this.from});
  final String from;
  @override
  State<UpiPaywallScreen> createState() => _UpiPaywallScreenState();
}

class _UpiPaywallScreenState extends State<UpiPaywallScreen> with WidgetsBindingObserver {
  List<({String package, String name, Uint8List? icon})> apps = const [];
  UpiOffer offer = upiOfferDefault;
  String? picked;
  bool busy = false;
  bool waiting = false;
  final _ref = TextEditingController();

  String get _trial => rupees(offer.trialPaise);
  String get _price => rupees(offer.monthlyPaise);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.event('paywall_viewed', {'variant': 'upi', 'from': widget.from});
    Market.offer().then((o) {
      if (mounted) setState(() => offer = o);
    });
    Market.upiApps().then((found) {
      if (!mounted) return;
      final a = sortUpiApps(found, (x) => x.package);
      setState(() {
        apps = a;
        picked = a.isNotEmpty ? a.first.package : null;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ref.dispose();
    super.dispose();
  }

  /// Back from the UPI app: ask the server whether the ₹2 went through.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && waiting) _confirm();
  }

  Future<void> _confirm() async {
    setState(() => busy = true);
    for (var i = 0; i < 6; i++) {
      if (await Market.hasAccess()) return _unlocked();
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
    }
    if (mounted) setState(() => busy = false);
  }

  void _unlocked() {
    if (!mounted) return;
    AnalyticsService.event('purchase_completed', {'plan': 'upiMonthly', 'variant': 'upi', 'from': widget.from});
    context.read<AppState>().setPremium('upiMonthly');
    context.go('/');
  }

  Future<void> _pay() async {
    if (busy) return;
    setState(() => busy = true);
    AnalyticsService.event('purchase_started', {'plan': 'upiMonthly', 'variant': 'upi', 'from': widget.from});
    if (upiTestUnlock) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      Toast.show(tr('upi.testMode'));
      return _unlocked();
    }
    final r = await Market.checkout();
    if (!mounted) return;
    final url = r?['payUrl'] as String?;
    if (r == null || r['configured'] != true || url == null) {
      setState(() => busy = false);
      Toast.show(tr('upi.notReady'));
      return;
    }
    waiting = true;
    final opened = await Market.openUpi(url, picked);
    if (mounted) setState(() => busy = opened);
  }

  Future<void> _restore() async {
    setState(() => busy = true);
    final ok = await Market.hasAccess(reference: _ref.text.trim());
    if (!mounted) return;
    if (ok) return _unlocked();
    setState(() => busy = false);
    Toast.show(tr('upi.restoreFailed'));
  }

  ({String package, String name, Uint8List? icon})? get _app {
    for (final a in apps) {
      if (a.package == picked) return a;
    }
    return null;
  }

  Widget _appIcon(Uint8List? icon, String name, {double size = 36}) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: icon != null
            ? Image.memory(icon, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(
                width: size,
                height: size,
                color: C.sand,
                alignment: Alignment.center,
                child: Text(name.isEmpty ? 'U' : name.substring(0, 1), style: T.label),
              ),
      );

  void _openRestore() {
    showEnsoSheet<void>(
      context,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('upi.restore'), style: T.title.s(18)),
          const SizedBox(height: 12),
          TextField(controller: _ref, autofocus: true, decoration: InputDecoration(hintText: tr('upi.restorePlaceholder'))),
          const SizedBox(height: 12),
          EnsoButton(label: tr('upi.restoreCta'), onTap: busy ? null : () { Navigator.pop(sheet); _restore(); }),
        ]),
      ),
    );
  }

  void _openPicker() {
    showEnsoSheet<void>(
      context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('upi.payWith'), style: T.title.s(18)),
          for (final a in apps)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Pressable(
                onTap: () {
                  setState(() => picked = a.package);
                  Navigator.pop(sheet);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: picked == a.package ? C.jadeSoft : C.ivory,
                    border: Border.all(color: picked == a.package ? C.jade : C.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    _appIcon(a.icon, a.name),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.name, style: T.label.s(15))),
                    Icon(picked == a.package ? LucideIcons.circleCheck : LucideIcons.circle, color: picked == a.package ? C.jade : C.muted, size: 20),
                  ]),
                ),
              ),
            ),
        ])),
      ),
    );
  }

  double _coverMin(BuildContext context) => MediaQuery.sizeOf(context).height <= 640 ? 150 : 200;

  @override
  Widget build(BuildContext context) {
    final benefits = [
      (LucideIcons.layers, tr('paywall.progressiveCourses', {'n': Content.i.plans.where((p) => p.days.length > 1).length})),
      (LucideIcons.moon, tr('paywall.guidedMeditations', {'n': Content.i.meditations.length})),
      (LucideIcons.leaf, tr('paywall.styles')),
      (LucideIcons.heartHandshake, tr('upi.benefitSafe')),
    ];
    final app = _app;
    // Hard paywall (server-set, after onboarding only): Android back can't skip it either.
    return PopScope(
      canPop: upiCanClose(offer, widget.from),
      child: EnsoScaffold(
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              // First screen fills exactly: the film takes the spare height, so no empty gap; the
              // legal terms sit just below the fold behind the CTA and are read by scrolling.
              builder: (context, bounds) => SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: math.max(bounds.maxHeight, _coverMin(context) + 400),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(
                        child: Stack(fit: StackFit.expand, children: [
                          LayoutBuilder(builder: (context, frame) => Padding(
                            padding: EdgeInsets.only(top: math.max(topInset(context), frame.maxHeight * 0.10)),
                            child: const PaywallFilm(topAligned: true),
                          )),
                          Positioned(
                            left: 0, right: 0, bottom: 0, height: 64,
                            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.cream.withValues(alpha: 0), C.cream]))),
                          ),
                          if (upiCanClose(offer, widget.from)) Positioned(
                            top: topInset(context) + 6,
                            right: 16,
                            child: CircleBtn(icon: LucideIcons.x, tone: Tone.dark, label: tr('common.close'), onTap: busy ? null : () => context.go('/')),
                          ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: C.goldSoft, borderRadius: BorderRadius.circular(99)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(LucideIcons.sparkles, size: 13, color: C.jadeDeep),
                              const SizedBox(width: 5),
                              Text(tr('upi.offerEyebrow'), style: T.label.s(12).copyWith(color: C.jadeDeep)),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Text(tr('upi.heroTitle', {'trial': _trial}), style: T.displayMd.copyWith(fontSize: 23, height: 1.12)),
                          const SizedBox(height: 10),
                          for (final (icon, text) in benefits)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(children: [
                                Container(width: 26, height: 26, decoration: const BoxDecoration(color: C.jadeSoft, shape: BoxShape.circle), child: Icon(icon, size: 14, color: C.jadeDeep)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(text, style: T.body.s(12).copyWith(fontWeight: FontWeight.w500, height: 1.25))),
                              ]),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(color: C.jadeSoft, border: Border.all(color: C.jade, width: 2), borderRadius: BorderRadius.circular(20)),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(tr('paywall.plusBadge'), style: T.tiny.copyWith(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700, color: C.jadeDeep)),
                                  const SizedBox(height: 4),
                                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                                    Text(_trial, style: T.displayMd.copyWith(fontSize: 34, height: 1, fontWeight: FontWeight.w800, color: C.jadeDeep)),
                                    const SizedBox(width: 6),
                                    Text(tr('upi.today'), style: T.label.s(16)),
                                  ]),
                                  if (offer.showMonthlyLine) ...[
                                    const SizedBox(height: 4),
                                    Text(tr('upi.thenLine', {'price': _price}), style: T.caption.s(12)),
                                  ],
                                ]),
                              ),
                              const Icon(LucideIcons.circleCheck, color: C.jade, size: 26),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Column(children: [
                      Text(tr('upi.terms', {'trial': _trial, 'price': _price}), textAlign: TextAlign.center, style: T.tiny.s(11)),
                      Wrap(alignment: WrapAlignment.center, children: [
                        for (final doc in const ['terms', 'privacy'])
                          TextButton(
                            onPressed: () => context.push('/legal/$doc'),
                            child: Text(tr(doc == 'terms' ? 'paywall.termsOfUse' : 'paywall.privacyPolicy'), style: T.label.s(11).copyWith(color: C.muted)),
                          ),
                        TextButton(
                          onPressed: busy ? null : _openRestore,
                          child: Text(tr('paywall.restorePurchase'), style: T.label.s(11).copyWith(color: C.muted)),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Pressable(
                  onTap: apps.length > 1 ? _openPicker : null,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                    decoration: BoxDecoration(color: C.ivory, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      _appIcon(app?.icon, app?.name ?? 'UPI', size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('upi.payWith'), style: T.caption.s(11)),
                          Text(app?.name ?? 'UPI', style: T.label.s(14)),
                        ]),
                      ),
                      if (apps.length > 1) ...[
                        Text(tr('upi.change'), style: T.label.s(13).copyWith(color: C.jadeDeep)),
                        const Icon(LucideIcons.chevronRight, color: C.jadeDeep, size: 16),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                EnsoButton(label: busy ? tr('upi.checking') : tr('upi.cta', {'trial': _trial}), loading: busy, onTap: busy ? null : _pay),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.lock, color: C.jadeDeep, size: 13),
                  const SizedBox(width: 6),
                  Flexible(child: Text(tr('upi.secureLine'), style: T.caption.s(11))),
                ]),
              ]),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
