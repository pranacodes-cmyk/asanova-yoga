import 'package:flutter_test/flutter_test.dart';
import 'package:enso/services/legal_service.dart';

void main() {
  test('accepts complete server document', () {
    expect(validLegal({'updated': '22 November 2026', 'contact': 'public@example.com', 'terms': {
      'title': 'Terms', 'intro': 'Updated policy', 'sections': [{'h': 'Renewal', 'p': ['Cancel anytime']}]
    }}, 'terms'), isTrue);
  });
  test('rejects broken server documents so installed copy is retained', () {
    expect(validLegal(null, 'privacy'), isFalse);
    expect(validLegal({'updated': 'today', 'contact': 'public@example.com', 'privacy': {'title': '', 'intro': '', 'sections': []}}, 'privacy'), isFalse);
  });
}