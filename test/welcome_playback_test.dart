import 'package:enso/logic/lesson_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('course cinematic loops the v3 film without holding; start and end share it', () {
    expect(kTutorWelcomeFilm, 'yc-yoga-flow-v3');
    expect(kTutorCongratsFilm, kTutorWelcomeFilm);
    expect(filmPlaybackComplete(kTutorWelcomeFilm, 20), isFalse);
  });
}
