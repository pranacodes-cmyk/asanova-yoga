import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../i18n/i18n.dart';
import '../logic/logic.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
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
    // The India film carries its own voiceover, so onboarding music and narration stop here.
    _stopOnboardingAudio();
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
    if (!_backToOnboarding) _stopOnboardingAudio();
    WidgetsBinding.instance.removeObserver(this);
    _ref.dispose();
    super.dispose();
  }

  void _stopOnboardingAudio() {
    if (Ambient.state.value.key == 'music-bamboo') Ambient.stop();
    Voice.stop();
  }

  bool _backToOnboarding = false;

  /// Android back from the onboarding paywall returns to the plan reveal, music still playing.
  void _back() {
    if (busy) return;
    if (widget.from == 'onboarding') {
      _backToOnboarding = true;
      context.go('/plan-ready');
    } else if (upiCanClose(offer, widget.from)) {
      _leave();
    }
  }

  void _leave() {
    _stopOnboardingAudio();
    context.go('/');
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
    if (mounted) {
      setState(() { busy = false; waiting = false; });
      Toast.show(tr('common.tryAgain'));
    }
  }

  void _unlocked() {
    if (!mounted) return;
    AnalyticsService.event('purchase_completed', {'plan': 'upiMonthly', 'variant': 'upi', 'from': widget.from});
    context.read<AppState>().setPremium('upiMonthly');
    _leave();
  }

  Future<void> _pay() async {
    if (busy) return;
    setState(() => busy = true);
    AnalyticsService.event('purchase_started', {'plan': 'upiMonthly', 'variant': 'upi', 'from': widget.from});
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
    if (mounted) {
      setState(() { busy = false; waiting = opened; });
      if (!opened) Toast.show(tr('common.tryAgain'));
    }
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


  bool get scroll => offer.layout == 'scroll';

  Widget _benefit(IconData icon, String text, bool wide) => Container(
        constraints: BoxConstraints(minHeight: wide ? 0 : 60),
        padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 12, vertical: wide ? 14 : 10),
        decoration: BoxDecoration(color: C.ivory, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(width: wide ? 36 : 32, height: wide ? 36 : 32, decoration: const BoxDecoration(color: C.jadeSoft, shape: BoxShape.circle), child: Icon(icon, size: 16, color: C.jadeDeep)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: T.body.s(wide ? 14 : 12).copyWith(fontWeight: FontWeight.w600, height: 1.35))),
        ]),
      );

  Widget _priceCard() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: C.jadeSoft, border: Border.all(color: C.jade), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('paywall.plusBadge'), style: T.tiny.copyWith(fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w700, color: C.jadeDeep)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(_trial, style: T.displayMd.copyWith(fontSize: 30, height: 1, fontWeight: FontWeight.w800, color: C.jadeDeep)),
                const SizedBox(width: 6),
                Text(tr('upi.today'), style: T.label.s(13)),
              ]),
            ]),
          ),
          const Icon(LucideIcons.circleCheck, color: C.jade, size: 24),
        ]),
      );

  Widget _legalLink(String label, VoidCallback? onTap) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(label, style: T.label.s(11).copyWith(color: C.muted, decoration: TextDecoration.underline)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final benefits = [
      (LucideIcons.layers, tr('upi.benefitCourses')),
      (LucideIcons.moon, tr('upi.benefitMeditate')),
      (LucideIcons.leaf, tr('paywall.styles')),
      (LucideIcons.heartHandshake, tr('upi.benefitSafe')),
    ];
    final app = _app;
    // Back never skips the onboarding paywall into the app; it returns to the plan reveal.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: EnsoScaffold(
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              // Server `layout`: fit = offer fills the first screen; scroll = price sits below the fold.
              // Legal terms always sit just below the fold behind the CTA and are read by scrolling.
              builder: (context, bounds) => SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: bounds.maxHeight),
                    child: IntrinsicHeight(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      ColoredBox(
                        color: C.sand,
                        child: Stack(children: [
                          // 16:9 India film: full width just below the status bar, always shown whole.
                          Padding(
                            padding: EdgeInsets.only(top: topInset(context)),
                            child: const AspectRatio(aspectRatio: 16 / 9, child: PaywallFilm(topAligned: true, india: true)),
                          ),
                          if (upiCanClose(offer, widget.from)) Positioned(
                            top: topInset(context) + 6,
                            right: 16,
                            child: CircleBtn(icon: LucideIcons.x, size: 32, iconSize: 16, tone: Tone.dark, label: tr('common.close'), onTap: busy ? null : _leave),
                          ),
                        ]),
                      ),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(tr('upi.heroTitle', {'trial': _trial}), style: T.displayMd.copyWith(fontSize: 20, height: 1.3)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final (icon, text) in benefits)
                              SizedBox(width: scroll ? bounds.maxWidth - 40 : (bounds.maxWidth - 48) / 2, child: _benefit(icon, text, scroll)),
                          ]),
                          if (!scroll) ...[
                            const SizedBox(height: 12),
                            _priceCard(),
                            const SizedBox(height: 8),
                            Text(tr('upi.terms', {'trial': _trial, 'price': _price}), textAlign: TextAlign.center, style: T.tiny.s(11).copyWith(height: 1.45)),
                          ],
                        ]),
                      )),
                    ])),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (scroll) ...[
                        _priceCard(),
                        const SizedBox(height: 10),
                        Text(tr('upi.terms', {'trial': _trial, 'price': _price}), textAlign: TextAlign.center, style: T.tiny.s(11).copyWith(height: 1.45)),
                        const SizedBox(height: 4),
                      ],
                      Wrap(alignment: WrapAlignment.center, children: [
                        _legalLink(tr('paywall.pricing'), () => context.push('/legal/pricing')),
                        for (final doc in const ['terms', 'privacy'])
                          _legalLink(tr(doc == 'terms' ? 'paywall.termsOfUse' : 'paywall.privacyPolicy'), () => context.push('/legal/$doc')),
                        _legalLink(tr('paywall.restorePurchase'), busy ? null : _openRestore),
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
                EnsoButton(label: busy ? tr('upi.checking') : tr('upi.cta', {'trial': _trial}), size: BtnSize.md, loading: busy, onTap: busy ? null : _pay),
              ]),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
