import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:enso/services/purchase_service.dart';

void main() {
  // The store scripts live next to the app only in the full project; the standalone store repository
  // (CI) has just the app, so the cross-checks against them are skipped there.
  final pricingFile = File('../scripts/store/pricing.json');
  final productsFile = File('../scripts/store/products.py');
  final pricing = pricingFile.existsSync()
      ? jsonDecode(pricingFile.readAsStringSync()) as Map<String, dynamic>
      : null;
  double usd(String s) => double.parse(s.replaceAll(RegExp('[^0-9.]'), ''));

  test('only the regular yearly plan carries a trial, and it is 7 days', () {
    expect(regularOffers.firstWhere((o) => o.id == 'yearly').trialDays, 7);
    expect(regularOffers.firstWhere((o) => o.id == 'monthly').trialDays, 0);
    expect(regularOffers.firstWhere((o) => o.id == 'lifetime').trialDays, 0);
  });

  test('the first paywall is the normal price with no trial at all', () {
    expect(standardOffers.map((o) => o.id).toList(), [
      'standardYearly',
      'monthly',
      'lifetime',
    ]);
    expect(standardOffers.map((o) => o.trialDays).toList(), [0, 0, 0]);
  });

  test('both yearly plans cost the same; only the trial differs', () {
    final standard = standardOffers.first;
    final trial = regularOffers.first;
    expect(usd(standard.price), usd(trial.price));
    expect(usd(standard.price), 59.99);
  });

  test('every main paywall offers Lifetime', () {
    for (final offers in [standardOffers, regularOffers, giftOffers]) {
      expect(offers.map((o) => o.id), contains('lifetime'));
    }
  });

  test('discounted offers (gift and exit) never have a trial', () {
    expect([...giftOffers, exitOffer].every((o) => o.trialDays == 0), isTrue);
  });

  test('the regular paywall has no weekly plan', () {
    expect(regularOffers.any((o) => o.id == 'weekly'), isFalse);
  });

  test('the gift screen offers yearly, monthly and lifetime', () {
    expect(giftOffers.map((o) => o.id).toList(), [
      'gift',
      'monthly',
      'lifetime',
    ]);
  });

  test(
    'the exit offer is a cheaper yearly than the gift and the regular yearly',
    () {
      final yearly = regularOffers.firstWhere((o) => o.id == 'yearly');
      final gift = giftOffers.firstWhere((o) => o.id == 'gift');
      expect(usd(exitOffer.price), lessThan(usd(gift.price)));
      expect(usd(gift.price), lessThan(usd(yearly.price)));
    },
  );

  test('placeholder prices are the US store prices: yearly 59.99, monthly 7.99, gift 39.99, exit 34.99, lifetime 99.99', () {
    final all = [...regularOffers, ...giftOffers, exitOffer];
    if (pricing != null) {
      for (final o in all) {
        expect(
          usd(o.price),
          (pricing['plans'][o.id]['tier1'] as num).toDouble(),
          reason: o.id,
        );
      }
    }
    expect(usd(all.firstWhere((o) => o.id == 'yearly').price), 59.99);
    expect(usd(all.firstWhere((o) => o.id == 'monthly').price), 7.99);
    expect(usd(all.firstWhere((o) => o.id == 'gift').price), 39.99);
    expect(usd(exitOffer.price), 34.99);
    expect(usd(all.firstWhere((o) => o.id == 'lifetime').price), 99.99);
    expect(usd(standardOffers.first.price), 59.99);
  });

  test(
    'every plan maps to a RevenueCat package that exists in scripts/store/products.py',
    () {
      final products = productsFile.readAsStringSync();
      for (final plan in [
        'standardYearly',
        'yearly',
        'monthly',
        'gift',
        'exit',
        'lifetime',
      ]) {
        final candidates = planPackages[plan]!;
        expect(candidates, isNotEmpty, reason: plan);
        for (final (_, id) in candidates) {
          expect(products.contains("'$id'"), isTrue, reason: '$plan → $id');
        }
      }
      expect(products.contains("'standard'"), isTrue);
    },
    skip: productsFile.existsSync()
        ? false
        : 'store scripts not in this checkout',
  );

  test('store product ids map back to the right plan', () {
    expect(PurchaseService.planForProduct('asanova_plus_lifetime'), 'lifetime');
    expect(PurchaseService.planForProduct('asanova_plus:monthly'), 'monthly');
    expect(PurchaseService.planForProduct('asanova_plus_yearly_exit'), 'exit');
    expect(PurchaseService.planForProduct('asanova_plus:yearly-gift'), 'gift');
    expect(PurchaseService.planForProduct('asanova_plus_yearly'), 'yearly');
    expect(
      PurchaseService.planForProduct('asanova_plus_yearly_standard'),
      'standardYearly',
    );
    expect(
      PurchaseService.planForProduct('asanova_plus:yearly-standard'),
      'standardYearly',
    );
  });

  test('per-week prices keep the store format', () {
    expect(PurchaseService.money(1.538, 'USD', r'$79.99'), r'$1.54');
    expect(PurchaseService.money(1.538, 'EUR', '79,99 €'), '1,54 €');
    expect(PurchaseService.money(57.69, 'INR', '₹3,000'), '₹58');
    expect(PurchaseService.money(230.7, 'JPY', '¥12,000'), '¥231');
  });

  test('RevenueCat public SDK keys are well-formed (no pasted whitespace)', () {
    final src = File('lib/services/purchase_service.dart').readAsStringSync();
    final android = RegExp(r"_androidKey = '([^']*)'")
        .firstMatch(src)!
        .group(1)!;
    final ios = RegExp(r"_iosKey = '([^']*)'").firstMatch(src)!.group(1)!;
    expect(android, matches(RegExp(r'^goog_[A-Za-z0-9]{27}$')));
    expect(ios, matches(RegExp(r'^appl_[A-Za-z0-9]{27}$')));
  });
}
