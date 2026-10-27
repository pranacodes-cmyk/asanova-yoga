import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../i18n/i18n.dart';

/// Purchase layer: RevenueCat on Android and iOS, with a demo fallback so previews, tests and
/// builds without store access still work. Mirrors src/lib/purchases.ts (same plan ids).
///
/// Funnel (competitor-style, truthful terms):
/// - standard paywall (first): normal-price yearly + monthly + lifetime — no trial; the yearly
///   is a separate store product so a first checkout can never silently start a trial
/// - regular paywall (after the close survey): yearly with a 7-day free trial + monthly + lifetime
/// - gift paywall ("View all plans"): discounted yearly, monthly, lifetime — no trial
/// - exit offer (after "the price feels high"): lower yearly — no trial
/// Prices below are the US placeholders from scripts/store/pricing.json (tier 1); [localized]
/// swaps in the store's own local price, and drops the trial for people the store says are not
/// eligible, as soon as offerings load. No advertising or analytics SDK is involved.
class Offer {
  final String id, title, price, period, perWeek;
  final String? badge, strike, save;
  final int trialDays;
  const Offer({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.perWeek,
    this.badge,
    this.trialDays = 0,
    this.strike,
    this.save,
  });
}

/// The monthly plan, shared by every subscription paywall.
Offer get _monthlyOffer => Offer(
  id: 'monthly',
  title: tr('purchase.planMonthly'),
  price: r'$7.99',
  period: 'month',
  perWeek: r'$1.84',
);

/// One-time Lifetime plan, offered on every main paywall and on "View all plans".
Offer get lifetimeOffer => Offer(
  id: 'lifetime',
  title: tr('purchase.planLifetime'),
  price: r'$99.99',
  period: 'once',
  perWeek: tr('purchase.payOnce'),
  badge: tr('purchase.badgeOneTime'),
);

/// First paywall: normal-price yearly (its own no-trial store product), monthly and lifetime.
List<Offer> get standardOffers => [
  Offer(
    id: 'standardYearly',
    title: tr('purchase.planYearly'),
    price: r'$59.99',
    period: 'year',
    perWeek: r'$1.15',
    badge: tr('purchase.badgeBestValue'),
    save: tr('purchase.savePercent', {'pct': 37}),
  ),
  _monthlyOffer,
  lifetimeOffer,
];

/// Trial paywall revealed after the close survey. The yearly plan carries the 7-day trial.
List<Offer> get regularOffers => [
  Offer(
    id: 'yearly',
    title: tr('purchase.planYearly'),
    price: r'$59.99',
    period: 'year',
    perWeek: r'$1.15',
    badge: tr('purchase.badgeBestValue'),
    trialDays: 7,
    save: tr('purchase.savePercent', {'pct': 37}),
  ),
  _monthlyOffer,
  lifetimeOffer,
];

/// "View all plans" gift screen — discounted, no trial.
List<Offer> get giftOffers => [
  Offer(
    id: 'gift',
    title: tr('purchase.planGiftYearly'),
    price: r'$39.99',
    period: 'year',
    perWeek: r'$0.77',
    badge: tr('purchase.badgeGiftDiscount'),
    strike: r'$59.99',
    save: tr('purchase.percentOff', {'pct': 33}),
  ),
  _monthlyOffer,
  lifetimeOffer,
];

/// Shown after the exit survey answer "the price feels high" — no trial.
Offer get exitOffer => Offer(
  id: 'exit',
  title: tr('purchase.planExitYearly'),
  price: r'$34.99',
  period: 'year',
  perWeek: r'$0.67',
  strike: r'$59.99',
  save: tr('purchase.savePercent', {'pct': 42}),
);

/// RevenueCat public SDK keys of the Asanova project (publishable; safe to ship in the binary).
const _androidKey = 'goog_OhaZwRKVpfiBHSHuzkvRQBUVsqV';
const _iosKey = 'appl_WYlgjSuIMqqcEwwVZmRcNxIWjNZ';

/// Entitlement and offering lookup keys configured in RevenueCat (scripts/store/products.py).
const _entitlement = 'asanova_plus';
const _offeringStandard = 'standard';
const _offeringRegular = 'default';
const _offeringGift = 'gift';
const _offeringExit = 'exit';

/// Plan id → (offering, package identifier) candidates, first found wins.
const planPackages = <String, List<(String, String)>>{
  'standardYearly': [(_offeringStandard, r'$rc_annual')],
  'yearly': [(_offeringRegular, r'$rc_annual')],
  'monthly': [
    (_offeringStandard, r'$rc_monthly'),
    (_offeringRegular, r'$rc_monthly'),
    (_offeringGift, 'gift_monthly'),
  ],
  'gift': [(_offeringGift, 'gift_yearly')],
  'exit': [(_offeringExit, 'exit_yearly')],
  'lifetime': [
    (_offeringStandard, r'$rc_lifetime'),
    (_offeringRegular, r'$rc_lifetime'),
    (_offeringGift, 'gift_lifetime'),
  ],
};

class PurchaseService {
  PurchaseService._();

  static bool _ready = false;

  /// Call once at app start. Never throws — falls back to demo mode.
  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await Purchases.configure(
        PurchasesConfiguration(Platform.isAndroid ? _androidKey : _iosKey),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Asanova purchases: $e');
      _ready = false;
    }
  }

  /// True when the user currently holds the Plus entitlement.
  static Future<bool> hasPlus() async => await plusStatus() ?? false;

  /// Plus status from the store: true / false, or null when unknown (demo mode, offline, store
  /// unavailable) so callers never revoke on errors.
  static Future<bool?> plusStatus() async {
    if (!_ready) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_entitlement);
    } catch (_) {
      return null;
    }
  }

  /// RevenueCat app user id (anonymous), shown as a support code so purchase questions can be
  /// matched. Null in demo mode.
  static Future<String?> supportCode() async {
    if (!_ready) return null;
    try {
      return await Purchases.appUserID;
    } catch (_) {
      return null;
    }
  }

  /// Plan id for an active Plus entitlement, from its store product id.
  static String planForProduct(String productId) {
    final id = productId.toLowerCase();
    if (id.contains('lifetime')) return 'lifetime';
    if (id.contains('month')) return 'monthly';
    if (id.contains('exit')) return 'exit';
    if (id.contains('gift')) return 'gift';
    if (id.contains('standard')) return 'standardYearly';
    return 'yearly';
  }

  /// Keeps the app's Plus flag in step with the store: renewals, refunds, expiries and purchases
  /// made on another device. Call once at start-up.
  static Future<void> syncEntitlement({
    required bool Function() isActive,
    required void Function(String plan) grant,
    required void Function() revoke,
  }) async {
    if (!_ready) return;
    void apply(CustomerInfo info) {
      final ent = info.entitlements.active[_entitlement];
      if (ent != null && !isActive()) {
        grant(planForProduct(ent.productIdentifier));
      }
      if (ent == null && isActive()) revoke();
    }

    try {
      apply(await Purchases.getCustomerInfo());
      Purchases.addCustomerInfoUpdateListener(apply);
    } catch (_) {}
    unawaited(warmUp());
  }

  static Map<String, Offering>? _cache;

  /// iOS intro-offer eligibility by product id (Android decides through the offer itself).
  static final _trialEligible = <String, bool>{};

  /// Pre-fetch offerings so paywalls render with real store prices.
  static Future<void> warmUp() async {
    if (!_ready) return;
    try {
      final o = await Purchases.getOfferings();
      _cache = o.all;
      final yearly = _packageFor('yearly')?.storeProduct;
      if (Platform.isIOS && yearly != null) {
        final e = await Purchases.checkTrialOrIntroductoryPriceEligibility([
          yearly.identifier,
        ]);
        final s = e[yearly.identifier]?.status;
        if (s != null &&
            s != IntroEligibilityStatus.introEligibilityStatusUnknown) {
          _trialEligible[yearly.identifier] =
              s == IntroEligibilityStatus.introEligibilityStatusEligible;
        }
      }
    } catch (_) {
      _cache ??= null;
    }
  }

  /// Whether the store will give this person the yearly 7-day trial. True while unknown (demo
  /// mode, offerings not loaded) so the survey still reveals the trial; false once the store
  /// says they are not eligible (e.g. subscribed before), and the lower price is shown instead.
  static bool get trialAvailable {
    final product = _packageFor('yearly')?.storeProduct;
    if (product == null) return true;
    return _storeTrialDays(product, 7) > 0;
  }

  static Package? _packageFor(String plan) {
    for (final (offering, id)
        in planPackages[plan] ?? const <(String, String)>[]) {
      for (final p
          in _cache?[offering]?.availablePackages ?? const <Package>[]) {
        if (p.identifier == id) return p;
      }
    }
    return null;
  }

  /// Free-trial days the store will really give for [product] (0 when none / not eligible).
  static int _storeTrialDays(StoreProduct product, int fallback) {
    if (Platform.isAndroid) {
      final free = product.defaultOption?.freePhase;
      if (free == null) return 0;
      final p = free.billingPeriod;
      return p == null
          ? fallback
          : switch (p.unit) {
              PeriodUnit.day => p.value,
              PeriodUnit.week => p.value * 7,
              PeriodUnit.month => p.value * 30,
              _ => fallback,
            };
    }
    final intro = product.introductoryPrice;
    if (intro == null || intro.price != 0) return 0;
    if (_trialEligible[product.identifier] == false) return 0;
    return switch (intro.periodUnit) {
      PeriodUnit.day => intro.periodNumberOfUnits,
      PeriodUnit.week => intro.periodNumberOfUnits * 7,
      PeriodUnit.month => intro.periodNumberOfUnits * 30,
      _ => fallback,
    };
  }

  /// The offer with the store's real, localised price when it is known (falls back to the US
  /// placeholder values before offerings load, and in demo mode).
  static Offer localized(Offer o) {
    final product = _packageFor(o.id)?.storeProduct;
    if (product == null) return o;
    final weeks = switch (o.period) {
      'year' => 52.0,
      'month' => 52.0 / 12,
      _ => 0.0,
    };
    // The normal yearly price is the anchor for discounts (both yearly products cost the same).
    final yearly =
        (_packageFor('standardYearly') ?? _packageFor('yearly'))?.storeProduct;
    final isNormalYearly = o.id == 'yearly' || o.id == 'standardYearly';
    final strike = o.strike != null && yearly != null && !isNormalYearly
        ? yearly.priceString
        : o.strike;
    String? save = o.save;
    if (o.strike != null &&
        yearly != null &&
        yearly.price > 0 &&
        !isNormalYearly) {
      final pct = ((1 - product.price / yearly.price) * 100).round();
      if (pct > 0) {
        save = o.id == 'gift'
            ? tr('purchase.percentOff', {'pct': pct})
            : tr('purchase.savePercent', {'pct': pct});
      }
    }
    // Yearly saving against twelve local monthly payments.
    final monthly = _packageFor('monthly')?.storeProduct;
    if (isNormalYearly && monthly != null && monthly.price > 0) {
      final pct = ((1 - product.price / (monthly.price * 12)) * 100).round();
      save = pct > 0 ? tr('purchase.savePercent', {'pct': pct}) : null;
    }
    return Offer(
      id: o.id,
      title: o.title,
      price: product.priceString,
      period: o.period,
      perWeek: weeks == 0
          ? o.perWeek
          : money(
              product.price / weeks,
              product.currencyCode,
              product.priceString,
            ),
      badge: o.badge,
      trialDays: o.trialDays > 0 ? _storeTrialDays(product, o.trialDays) : 0,
      strike: strike,
      save: save,
    );
  }

  /// Formats [amount] like the store's own price string [sample] (symbol and separators kept).
  static String money(double amount, String currency, String sample) {
    final digits = RegExp(r'\d[\d.,\s\u00a0\u202f]*').firstMatch(sample);
    if (digits == null) return '$currency ${amount.toStringAsFixed(2)}';
    final raw = digits.group(0)!.trim();
    final decimals =
        RegExp(r'[.,](\d{1,2})$').firstMatch(raw)?.group(1)?.length ?? 0;
    final fixed = amount.toStringAsFixed(decimals);
    final usesComma = RegExp(r',\d{1,2}$').hasMatch(raw);
    final text = usesComma ? fixed.replaceAll('.', ',') : fixed;
    return sample.replaceFirst(raw, text);
  }

  /// Human-readable reason for the last failed purchase (null when the person cancelled or it
  /// succeeded).
  static String? lastError;

  static Future<bool> purchase(String plan) async {
    lastError = null;
    if (!_ready) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return true; // demo mode (web prototype, tests, unsupported platforms)
    }
    if (_cache == null) await warmUp();
    final pkg = _packageFor(plan);
    if (pkg == null) {
      lastError = tr('purchase.plansLoadError', {
        'store': Platform.isIOS ? 'the App Store' : 'Google Play',
      });
      return false;
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      return result.customerInfo.entitlements.active.containsKey(_entitlement);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      lastError = switch (code) {
        PurchasesErrorCode.purchaseCancelledError => null,
        PurchasesErrorCode.paymentPendingError => tr('purchase.paymentPending'),
        PurchasesErrorCode.productAlreadyPurchasedError => tr(
          'purchase.alreadyOwned',
        ),
        PurchasesErrorCode.networkError => tr('purchase.noConnection'),
        PurchasesErrorCode.purchaseNotAllowedError => tr(
          'purchase.purchasesDisabled',
        ),
        _ => tr('purchase.genericError'),
      };
      return false;
    } catch (_) {
      lastError = tr('purchase.genericError');
      return false;
    }
  }

  static Future<bool> restore() async {
    if (!_ready) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return false;
    }
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(_entitlement);
    } catch (_) {
      return false;
    }
  }
}
