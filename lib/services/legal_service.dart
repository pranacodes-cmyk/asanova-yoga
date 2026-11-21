import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../data/content.dart';

/// Read fresh policies on every open; any failure uses the installed legal copy.
class LegalService {
  static Future<({Legal legal, LegalDoc document})> load(String doc) async {
    final bundled = jsonDecode(await rootBundle.loadString('assets/data/legal.json')) as Map<String, dynamic>;
    var source = bundled;
    try {
      final response = await http.get(Uri.parse('https://mindful-motion-daily.lovable.app/api/public/legal'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final remote = jsonDecode(response.body);
        if (validLegal(remote, doc)) {
          final data = remote as Map;
          source = { ...bundled, 'updated': data['updated'], 'contact': data['contact'], doc: data[doc] };
        }
      }
    } catch (_) {}
    return (legal: Legal.fromJson(source), document: LegalDoc.fromJson(Map<String, dynamic>.from(source[doc] as Map)));
  }
}

bool validLegal(Object? value, String doc) {
  if (value is! Map || value['updated'] is! String || value['contact'] is! String) return false;
  final d = value[doc];
  if (d is! Map || d['title'] is! String || (d['title'] as String).trim().isEmpty || d['intro'] is! String) return false;
  final sections = d['sections'];
  return sections is List && sections.isNotEmpty && sections.every((s) =>
      s is Map && s['h'] is String && s['p'] is List && (s['p'] as List).every((p) => p is String));
}