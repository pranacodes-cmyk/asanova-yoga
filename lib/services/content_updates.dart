import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../logic/lesson_media.dart';
import '../logic/logic.dart';

/// Over-the-air lesson content (web mirror in `src/data/content.ts`). A newer content file
/// published by `scripts/content/publish-ota.py` downloads quietly in the background and is used
/// from the next launch on; anything missing, older or unreadable falls back to the bundled file.
class ContentUpdates {
  ContentUpdates._();
  static Map<String, dynamic>? _base;

  static Future<Map<String, dynamic>> base() async {
    if (_base != null) return _base!;
    try {
      _base = jsonDecode(await rootBundle.loadString('assets/data/ota-base.json')) as Map<String, dynamic>;
    } catch (_) {
      _base = {'schema': kContentSchema, 'seq': 0, 'files': <String, dynamic>{}};
    }
    return _base!;
  }

  static Future<Directory?> _dir() async {
    try {
      final d = Directory('${(await getApplicationSupportDirectory()).path}/content');
      await d.create(recursive: true);
      return d;
    } catch (_) {
      return null;
    }
  }

  static Future<OtaCached?> _meta(Directory d, String lang) async {
    final f = File('${d.path}/$lang.meta');
    if (!f.existsSync()) return null;
    try {
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (schema: (m['schema'] as num).toInt(), seq: (m['seq'] as num).toInt(), hash: m['hash'] as String);
    } catch (_) {
      return null;
    }
  }

  /// The downloaded content for [lang] when it is newer than the bundled one, else null.
  static Future<String?> cached(String lang) async {
    final d = await _dir();
    if (d == null) return null;
    final meta = await _meta(d, lang);
    if (!otaUseCached(await base(), meta)) return null;
    final f = File('${d.path}/$lang.json');
    if (!f.existsSync()) return null;
    try {
      final raw = await f.readAsString();
      return otaValid(jsonDecode(raw)) ? raw : null;
    } catch (_) {
      return null;
    }
  }

  /// Checks the server and downloads a newer content file for [lang]. True when one was saved.
  static Future<bool> check(String lang) async {
    final d = await _dir();
    if (d == null) return false;
    try {
      final r = await http
          .get(Uri.parse('$kMediaBase/content/ota.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return false;
      final remote = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final pick = otaPick(await base(), remote, lang, await _meta(d, lang));
      if (pick == null) return false;
      final res = await http
          .get(Uri.parse('$kMediaBase/content/$lang.${pick.hash}.json'))
          .timeout(const Duration(seconds: 90));
      if (res.statusCode != 200 || res.bodyBytes.length != pick.bytes) return false;
      final text = utf8.decode(res.bodyBytes);
      if (!otaValid(jsonDecode(text))) return false;
      // Body first, then the meta that makes it count, so a half-written update is never used.
      final tmp = File('${d.path}/$lang.json.part');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename('${d.path}/$lang.json');
      await File('${d.path}/$lang.meta').writeAsString(
        jsonEncode({'schema': remote['schema'], 'seq': remote['seq'], 'hash': pick.hash}),
        flush: true,
      );
      return true;
    } catch (e) {
      debugPrint('Asanova content update: $e');
      return false;
    }
  }
}
