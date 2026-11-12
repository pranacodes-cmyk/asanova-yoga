import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../logic/logic.dart';

/// Which market the phone is in (SIM first, see `isIndiaMarket`) plus the India UPI plumbing:
/// installed UPI apps, the Easebuzz checkout and access lookup by Android ID (no login).
/// Mirrors src/lib/market.ts; the web prototype simulates payment.
class Market {
  Market._();
  static const _ch = MethodChannel('asanova/market');
  static const _api = 'https://mindful-motion-daily.lovable.app/api/public/upi';
  static bool india = false;
  static String deviceId = '';

  static Future<void> init() async {
    String? sim, net;
    if (Platform.isAndroid) {
      try {
        final m = Map<String, dynamic>.from(await _ch.invokeMethod('info') as Map);
        deviceId = '${m['deviceId'] ?? ''}';
        sim = '${m['simCountry'] ?? ''}';
        net = '${m['networkCountry'] ?? ''}';
      } catch (_) {}
    }
    final locale = Platform.localeName.replaceAll('-', '_').split('_');
    india = Platform.isAndroid &&
        isIndiaMarket(
          simCountry: sim,
          networkCountry: net,
          region: locale.length > 1 ? locale[1] : null,
          timeZone: DateTime.now().timeZoneName == 'IST' ? 'Asia/Kolkata' : null,
        );
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
    try {
      return await _ch.invokeMethod('openUpi', {'url': url, 'package': package}) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _post(String path, Map<String, Object?> body) async {
    if (deviceId.length < 8) return null;
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
  static Future<Map<String, dynamic>?> checkout() => _post('checkout', {});

  /// True when this phone (or, with [reference], the paid UTR/mandate) has Plus right now.
  static Future<bool> hasAccess({String? reference}) async {
    final r = await _post('status', {'reference': ?reference});
    if (r == null) return false;
    final until = DateTime.tryParse('${r['paidUntil'] ?? ''}');
    return upiAccessActive(r['status'] as String?, until, DateTime.now());
  }
}
