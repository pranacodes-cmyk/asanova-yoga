import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

const _max = 90;

/// Splits a line into short subtitle pages: sentences first, then words (or characters).
List<String> captionPages(String text, {int max = _max}) {
  final sentences = RegExp(r'[^.!?।。！？]+[.!?।。！？]*["”’)]?\s*')
      .allMatches(text)
      .map((m) => m.group(0)!.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (sentences.isEmpty) sentences.add(text);
  final pieces = <String>[];
  for (final s in sentences) {
    if (s.length <= max) {
      pieces.add(s);
      continue;
    }
    final spaced = s.contains(' ');
    final words = spaced ? s.split(' ') : s.characters.toList();
    final joiner = spaced ? ' ' : '';
    var cur = '';
    for (final w in words) {
      final next = cur.isEmpty ? w : '$cur$joiner$w';
      if (next.length > max && cur.isNotEmpty) {
        pieces.add(cur);
        cur = w;
      } else {
        cur = next;
      }
    }
    if (cur.isNotEmpty) pieces.add(cur);
  }
  final pages = <String>[];
  for (final p in pieces) {
    if (pages.isNotEmpty && pages.last.length + p.length + 1 <= max) {
      pages[pages.length - 1] = '${pages.last} $p';
    } else {
      pages.add(p);
    }
  }
  return pages.isEmpty ? [text] : pages;
}

/// Subtitle pages that change by themselves in time with the voice, like film subtitles.
class PlayerCaption extends StatefulWidget {
  const PlayerCaption({
    super.key,
    required this.text,
    required this.style,
    required this.running,
    required this.readingSeconds,
  });

  final String text;
  final TextStyle style;
  final bool running;
  final double readingSeconds;

  @override
  State<PlayerCaption> createState() => _PlayerCaptionState();
}

class _PlayerCaptionState extends State<PlayerCaption> {
  Timer? _timer;
  double _elapsed = 0;
  int _page = 0;
  late List<String> _pages = captionPages(widget.text);

  @override
  void didUpdateWidget(PlayerCaption old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _pages = captionPages(widget.text);
      _elapsed = 0;
      _page = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!widget.running || _pages.length < 2) return;
      _elapsed += 0.1;
      final total = math.max(1.0, widget.readingSeconds);
      final chars = _pages.fold<int>(0, (n, p) => n + p.length);
      var t = 0.0;
      var i = 0;
      for (; i < _pages.length - 1; i++) {
        t += total * _pages[i].length / chars;
        if (_elapsed < t) break;
      }
      if (i != _page) setState(() => _page = i);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: Text(
      _pages[_page],
      key: ValueKey(_page),
      textAlign: TextAlign.center,
      style: widget.style,
    ),
  );
}
