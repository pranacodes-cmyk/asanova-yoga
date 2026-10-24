/// Local preview purchases only. No store SDK, billing request or advertising connection.
/// Replace this adapter when the new app's own products are configured.
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

/// Regular paywall plans. The yearly plan carries the 7-day trial.
const regularOffers = [
  Offer(
    id: 'yearly',
    title: 'Yearly',
    price: r'$79.99',
    period: 'year',
    perWeek: r'$1.54',
    badge: 'Best value',
    trialDays: 7,
    save: 'Save 67%',
  ),
  Offer(
    id: 'monthly',
    title: 'Monthly',
    price: r'$9.99',
    period: 'month',
    perWeek: r'$2.50',
  ),
];

/// "View all plans" gift screen — discounted, no trial.
const giftOffers = [
  Offer(
    id: 'gift',
    title: 'Yearly · New user gift',
    price: r'$39.99',
    period: 'year',
    perWeek: r'$0.77',
    badge: '50% off first year',
    strike: r'$79.99',
    save: '50% OFF',
  ),
  Offer(
    id: 'monthly',
    title: 'Monthly',
    price: r'$9.99',
    period: 'month',
    perWeek: r'$2.50',
  ),
  Offer(
    id: 'lifetime',
    title: 'Lifetime',
    price: r'$99.99',
    period: 'once',
    perWeek: 'Pay once',
    badge: 'One-time payment',
  ),
];

/// Shown after the exit survey answer "the price feels high" — no trial.
const exitOffer = Offer(
  id: 'exit',
  title: 'Yearly · Special price',
  price: r'$34.99',
  period: 'year',
  perWeek: r'$0.67',
  strike: r'$79.99',
  save: 'Save 56%',
);

class PurchaseService {
  PurchaseService._();
  static String? lastError;
  static Future<void> init() async {}
  static Future<bool> hasPlus() async => false;
  static Future<bool?> plusStatus() async => null;
  static Future<String?> supportCode() async => null;
  static String planForProduct(String productId) {
    final id = productId.toLowerCase();
    if (id.contains('lifetime')) return 'lifetime';
    if (id.contains('month')) return 'monthly';
    if (id.contains('exit')) return 'exit';
    if (id.contains('gift')) return 'gift';
    return 'yearly';
  }

  static Future<void> syncEntitlement({
    required bool Function() isActive,
    required void Function(String plan) grant,
    required void Function() revoke,
  }) async {}
  static Future<void> warmUp() async {}
  static Offer localized(Offer offer) => offer;
  static Future<bool> purchase(String plan) async {
    lastError = null;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return true;
  }

  static Future<bool> restore() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return false;
  }
}
