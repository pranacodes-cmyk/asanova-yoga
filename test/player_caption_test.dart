import 'package:enso/widgets/player_caption.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long caption auto-scrolls, pauses and reveals the end', (tester) async {
    Widget view(bool running) => MaterialApp(
      home: Center(child: SizedBox(width: 200, height: 80,
        child: PlayerCaption(text: List.filled(80, 'Breathe gently.').join(' '),
          style: const TextStyle(fontSize: 16), running: running, readingSeconds: 10),
      )),
    );
    await tester.pumpWidget(view(true));
    final state = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.pump(const Duration(seconds: 4));
    final offset = state.position.pixels;
    expect(offset, greaterThan(0));
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(seconds: 4));
    expect(state.position.pixels, offset);
    await tester.pumpWidget(view(true));
    await tester.pump(const Duration(seconds: 10));
    expect(state.position.pixels, state.position.maxScrollExtent);
    await tester.pumpWidget(const SizedBox());
  });
}