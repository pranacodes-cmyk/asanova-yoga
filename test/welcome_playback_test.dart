import 'package:enso/logic/lesson_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Namaste holds once eyes close, not before; other films keep playing', () {
    expect(filmPlaybackComplete(kTutorWelcomeFilm, 9.59), isFalse);
    expect(filmPlaybackComplete(kTutorWelcomeFilm, 9.6), isTrue);
    expect(filmPlaybackComplete(kTutorWelcomeFilm, 12), isTrue);
    expect(filmPlaybackComplete(kTutorCongratsFilm, 12), isFalse);
    expect(filmPlaybackComplete('yf-mountain', 12), isFalse);
  });
}