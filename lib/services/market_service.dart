import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/logic.dart';
import 'meta_events.dart';

/// Market detection, default-off India funnel, installed UPI apps and the stable provider-neutral
/// checkout/status contract. Private installation capabilities verify access without login.
/// Mirrors src/lib/market.ts; the web prototype simulates payment.
class Market {
  Market._();
  static const _ch = MethodChannel('asanova/market');
  static const _api = 'https://mindful-motion-daily.lovable.app/api/public/upi';
  static bool india = false;
  static bool detectedIndia = false;
  static String deviceId = '';

  static Future<void> init() async {
    // An Android ID is not proof of ownership. A private, random installation capability
    // protects payment-status requests without accounts. Never log or send it to analytics.
    final preferences = await SharedPreferences.getInstance();
    const key = 'asanova-upi-installation-v1';
    final saved = preferences.getString(key);
    if (saved != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(saved)) {
      deviceId = saved;
    } else {
      final random = Random.secure();
      deviceId = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await preferences.setString(key, deviceId);
    }
    String? sim, net;
    if (Platform.isAndroid) {
      try {
        final m = Map<String, dynamic>.from(await _ch.invokeMethod('info') as Map);
        sim = '${m['simCountry'] ?? ''}';
        net = '${m['networkCountry'] ?? ''}';
      } catch (_) {}
    }
    final locale = Platform.localeName.replaceAll('-', '_').split('_');
    detectedIndia = Platform.isAndroid &&
        isIndiaMarket(
          simCountry: sim,
          networkCountry: net,
          region: locale.length > 1 ? locale[1] : null,
          timeZone: DateTime.now().timeZoneName == 'IST' ? 'Asia/Kolkata' : null,
        );
    // Resolve once before the language screen. Never reuse a stale ON value offline.
    Object? config;
    if (detectedIndia) {
      try {
        final response = await http.get(Uri.parse('$_api/config')).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) config = jsonDecode(response.body);
      } catch (_) {}
    }
    india = usesIndiaFlow(detectedIndia, config);
  }

  static Future<List<({String package, String name, Uint8List? icon})>> upiApps() async {
    try {
      final list = await _ch.invokeMethod('upiApps') as List;
      return [
        for (final a in list)
          (package: '${(a as Map)['package']}', name: '${a['name']}', icon: a['icon'] is Uint8List ? a['icon'] as Uint8List : null),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> openUpi(String url, String? package) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['upi', 'https'].contains(uri.scheme)) return false;
    try {
      // Hosted mandate approval opens in the browser; only actual UPI intents target an app.
      return await _ch.invokeMethod('openUpi', {'url': url, 'package': uri.scheme == 'upi' ? package : null}) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _post(String path, Map<String, Object?> body) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(deviceId)) return null;
    try {
      final res = await http
          .post(Uri.parse('$_api/$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'deviceId': deviceId, ...body}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Live India offer (price + monthly line), editable on the server without a new build.
  static Future<UpiOffer> offer() async {
    try {
      final res = await http.get(Uri.parse('$_api/offer')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return parseUpiOffer(jsonDecode(res.body));
    } catch (_) {}
    return upiOfferDefault;
  }

  /// `{configured, txnid, payUrl}` or null when the network/server failed.
  /// Meta's anonymous id goes along only while Usage statistics is on ([MetaEvents.anonymousId]
  /// returns null otherwise), so the server can report the confirmed ₹ trial/renewal to Meta.
  static Future<Map<String, dynamic>?> checkout() async {
    final anon = await MetaEvents.anonymousId();
    return _post('checkout', {'metaAnonId': ?anon});
  }

  /// Verify this installation's paid access. Reference-only restores require verified support.
  static Future<bool> hasAccess({String? reference}) async {
    final r = await _post('status', {'reference': ?reference});
    if (r == null) return false;
    final until = DateTime.tryParse('${r['paidUntil'] ?? ''}');
    return upiAccessActive(r['status'] as String?, until, DateTime.now());
  }
}
