// Mirrors src/lib/ota.test.ts — over-the-air content rules.
import 'dart:convert';
import 'dart:io';

import 'package:enso/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = <String, dynamic>{'schema': kContentSchema, 'seq': 3, 'files': {'en': 'aaa', 'hi': 'bbb'}};
  Map<String, dynamic> remote(int seq, [String hash = 'ccc', int schema = kContentSchema]) => {
        'schema': schema,
        'seq': seq,
        'files': {'en': {'hash': hash, 'bytes': 10}},
      };

  test('downloads only a newer server copy with a different file', () {
    expect(otaPick(base, remote(4), 'en', null), (hash: 'ccc', bytes: 10));
    expect(otaPick(base, remote(3), 'en', null), isNull);
    expect(otaPick(base, remote(2), 'en', null), isNull);
    expect(otaPick(base, remote(4, 'aaa'), 'en', null), isNull);
    expect(otaPick(base, remote(4), 'hi', null), isNull);
    expect(otaPick(base, null, 'en', null), isNull);
  });
  test('ignores another content schema', () {
    expect(otaPick(base, remote(9, 'ccc', kContentSchema + 1), 'en', null), isNull);
  });
  test('does not download what is already saved', () {
    expect(otaPick(base, remote(4), 'en', (schema: kContentSchema, seq: 4, hash: 'ccc')), isNull);
    expect(otaPick(base, remote(5, 'ddd'), 'en', (schema: kContentSchema, seq: 4, hash: 'ccc')), (hash: 'ddd', bytes: 10));
  });
  test('uses a saved update only when newer than the bundled content', () {
    expect(otaUseCached(base, (schema: kContentSchema, seq: 4, hash: 'x')), isTrue);
    expect(otaUseCached(base, (schema: kContentSchema, seq: 3, hash: 'x')), isFalse);
    expect(otaUseCached(base, (schema: kContentSchema + 1, seq: 9, hash: 'x')), isFalse);
    expect(otaUseCached(base, null), isFalse);
  });
  test('rejects incomplete content and accepts the shipped file', () {
    expect(otaValid(jsonDecode(File('assets/data/content.json').readAsStringSync())), isTrue);
    expect(otaValid({'exercises': [], 'plans': [1], 'meditations': [1], 'ui': {}}), isFalse);
    expect(otaValid(null), isFalse);
  });
  test('bundled baseline matches the content schema', () {
    final b = jsonDecode(File('assets/data/ota-base.json').readAsStringSync());
    expect(b['schema'], kContentSchema);
  });
}
