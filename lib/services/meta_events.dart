import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Meta (Facebook) app events + install attribution, set up like the studio's other apps.
///
/// - The Android manifest / iOS Info.plist ship with auto-logging and advertiser-ID collection
///   OFF; [configure] switches them on at runtime only while Profile → Privacy → Usage statistics
///   is on (and, on iOS, advertiser tracking only when App Tracking Transparency is authorised).
/// - Trials and purchases are NOT logged here: RevenueCat's Meta integration is the single sender
///   of StartTrial / Purchase, so revenue is never double counted.
/// - Only funnel events with no health meaning are sent (install/open, onboarding completed,
///   paywall viewed, checkout started). Never screen names, answers, names or practice details.
/// - Inert when no Meta App ID is compiled in ([MetaConfig.appId] empty).
class MetaConfig {
  MetaConfig._();

  /// Asanova's own Meta app (developers.facebook.com). Also set in android/app/build.gradle.kts
  /// and ios/Runner/Info.plist — keep the three in step.
  static const String appId = String.fromEnvironment('META_APP_ID', defaultValue: '1586052573206218');
  static const String clientToken = String.fromEnvironment('META_CLIENT_TOKEN', defaultValue: 'fbce20a08f2b71933eb5c7cf244e29eb');
  static bool get isConfigured => appId.isNotEmpty && clientToken.isNotEmpty;
}

class MetaEvents {
  MetaEvents._();

  static FacebookAppEvents? _fb;
  static bool _enabled = false;

  static bool get _native => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Call at start-up and whenever the Usage statistics switch or the iOS tracking answer changes.
  static Future<void> configure({required bool enabled}) async {
    if (!_native || !MetaConfig.isConfigured) return;
    try {
      _fb ??= FacebookAppEvents();
      final fb = _fb!;
      if (!enabled) {
        _enabled = false;
        await fb.setAutoLogAppEventsEnabled(false);
        await fb.setAdvertiserIdCollectionEnabled(false);
        return;
      }
      var adIdAllowed = true;
      if (Platform.isIOS) {
        final att = await AppTrackingTransparency.trackingAuthorizationStatus;
        // Until the person has answered the iOS prompt, nothing is sent at all.
        if (att == TrackingStatus.notDetermined) return;
        adIdAllowed = att == TrackingStatus.authorized;
      }
      await fb.setAdvertiserIdCollectionEnabled(adIdAllowed);
      // Auto-logging stays off so the SDK never logs store purchases itself (RevenueCat sends
      // them); activateApp below reports the install/open Meta attributes ads with.
      await fb.setAutoLogAppEventsEnabled(false);
      final firstTime = !_enabled;
      _enabled = true;
      if (firstTime) {
        await fb.activateApp();
        await fb.flush();
      }
    } catch (e) {
      debugPrint('[MetaEvents] configure failed: $e');
    }
  }

  /// iOS App Tracking Transparency prompt (shown once; iOS never re-asks), then re-applies
  /// [configure] with the answer.
  static Future<void> askTrackingPermission({required bool enabled}) async {
    if (kIsWeb || !Platform.isIOS || !MetaConfig.isConfigured) return;
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // iOS ignores the request unless the app is fully active; give the first frame a moment.
        await Future<void>.delayed(const Duration(milliseconds: 900));
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      await configure(enabled: enabled);
    } catch (e) {
      debugPrint('[MetaEvents] tracking prompt failed: $e');
    }
  }

  /// Anonymous Meta id handed to RevenueCat so the server can attribute trials/purchases.
  static Future<String?> anonymousId() async {
    if (!_enabled) return null;
    try {
      return await _fb?.getAnonymousId();
    } catch (_) {
      return null;
    }
  }

  static bool get enabled => _enabled;

  static Future<void> _log(String name, [Map<String, dynamic>? params, bool flush = false]) async {
    final fb = _fb;
    if (fb == null || !_enabled) return;
    try {
      await fb.logEvent(name: name, parameters: params);
      if (flush) await fb.flush();
    } catch (e) {
      debugPrint('[MetaEvents] $name failed: $e');
    }
  }

  /// Mirrors the few named analytics events Meta optimises on (see AnalyticsService.event).
  static Future<void> fromAnalytics(String event, Map<String, Object>? props) async {
    switch (event) {
      case 'onboarding_completed':
        await _log('fb_mobile_complete_registration', {'fb_registration_method': 'onboarding'}, true);
      case 'paywall_viewed':
        await _log('fb_mobile_content_view', {'fb_content_type': 'paywall', 'fb_content_id': '${props?['variant'] ?? 'standard'}'});
      case 'purchase_started':
        await _log('fb_mobile_initiated_checkout', {'fb_content_type': 'subscription', 'fb_content_id': '${props?['plan'] ?? ''}'}, true);
    }
  }
}
