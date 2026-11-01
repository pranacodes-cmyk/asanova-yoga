import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'meta_events.dart';

/// Anonymous usage analytics (PostHog, US cloud).
///
/// Privacy rules (mirrors web `src/lib/analytics.ts`):
/// - screen views plus named product events (onboarding funnel, paywall, purchases,
///   lessons, meditations, downloads, performance) are sent;
/// - health answers (pain zones, limitations) and free text (name, feedback) are
///   never sent — see `analyticsAnswer` in logic;
/// - no session replay, no autocapture of taps or inputs.
class AnalyticsService {
  static const _token = 'phc_zyCAsMHT43ctrr4TYxDnStwoB2yp7SJT5JhEe4bSHXmA';
  static const _host = 'https://us.i.posthog.com';

  static bool _ready = false;

  static Future<void> init({bool enabled = true}) async {
    if (_ready) return;
    _ready = true;
    final config = PostHogConfig(_token)
      ..host = _host
      ..captureApplicationLifecycleEvents = true
      ..debug = false;
    await Posthog().setup(config);
    if (!enabled) await Posthog().optOut();
  }

  /// Profile → Privacy → Usage statistics switch — also switches Meta ad measurement.
  static Future<void> setEnabled(bool on) async {
    await MetaEvents.configure(enabled: on);
    if (!_ready) return;
    if (on) {
      await Posthog().optIn();
    } else {
      await Posthog().optOut();
    }
  }

  /// Properties attached to every later event (language, premium, …).
  static void register(Map<String, Object> props) {
    if (!_ready) return;
    props.forEach((k, v) => Posthog().register(k, v));
  }

  static void screen(String name) {
    if (!_ready) return;
    Posthog().screen(screenName: name);
  }

  static void event(String name, [Map<String, Object>? properties]) {
    MetaEvents.fromAnalytics(name, properties);
    if (!_ready) return;
    Posthog().capture(eventName: name, properties: properties);
  }

  /// Anonymous PostHog id, handed to RevenueCat so billing events join the same person.
  static Future<String?> distinctId() async {
    if (!_ready) return null;
    try {
      return await Posthog().getDistinctId();
    } catch (_) {
      return null;
    }
  }

  /// Profile → Reset all data: start a fresh anonymous identity.
  static Future<void> reset() async {
    if (!_ready) return;
    await Posthog().reset();
  }
}

/// Reports every pushed/replaced route as a PostHog screen view.
class AnalyticsObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) AnalyticsService.screen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);
}
