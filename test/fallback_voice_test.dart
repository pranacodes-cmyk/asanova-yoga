import 'package:enso/services/fallback_voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS fallback prefers premium female voice over compact voice', () {
    final picked = bestIosVoice([
      {'identifier': 'compact', 'gender': 'female', 'quality': 'default'},
      {'identifier': 'enhanced', 'gender': 'female', 'quality': 'enhanced'},
      {'identifier': 'premium', 'gender': 'female', 'quality': 'premium'},
    ]);
    expect(picked?['identifier'], 'premium');
  });
  test('no installed voices is safe', () {
    expect(bestIosVoice([]), isNull);
  });
}