import 'package:flutter_test/flutter_test.dart';
import 'package:enso/widgets/player_caption.dart';

void main() {
  test('short line stays one page', () {
    expect(captionPages('Breathe in slowly.'), ['Breathe in slowly.']);
  });
  test('long line splits into pages of at most 90 characters', () {
    const text = "For the next thirty days I'll be your teacher. We'll start gently, with breath and simple shapes, and build up one or two new poses a day, always on top of what you already know.";
    final pages = captionPages(text);
    expect(pages.length, greaterThan(1));
    for (final p in pages) {
      expect(p.length, lessThanOrEqualTo(90));
    }
    expect(pages.join(' '), text);
  });
  test('Japanese text without spaces splits', () {
    expect(captionPages('あ' * 200).length, 3);
  });
}
