import 'package:enso/logic/lesson_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected full flow plays once then holds; start and end share one cached film', () {
    expect(kTutorWelcomeFilm, 'yc-yoga-flow-v2');
    expect(kTutorCongratsFilm, kTutorWelcomeFilm);
    expect(filmPlaybackComplete(kTutorWelcomeFilm, 19.94), isFalse);
    expect(filmPlaybackComplete(kTutorWelcomeFilm, 19.95), isTrue);
    expect(filmPlaybackComplete(kTutorCongratsFilm, 20), isTrue);
    expect(filmPlaybackComplete('yf-mountain', 12), isFalse);
  });
}