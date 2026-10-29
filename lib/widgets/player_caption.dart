import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full captions stay readable within the space left above the player controls.
/// The reading window advances automatically; dragging takes over for this line.
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
  final _scroll = ScrollController();
  Timer? _timer;
  double _elapsed = 0;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!widget.running || _manual || !_scroll.hasClients ||
          MediaQuery.disableAnimationsOf(context)) return;
      final position = _scroll.position;
      if (position.maxScrollExtent <= 0) return;
      _elapsed += 0.08;
      final total = math.max(1.0, widget.readingSeconds);
      final visible = position.viewportDimension /
          (position.viewportDimension + position.maxScrollExtent);
      final hold = total * visible * 0.7;
      final progress = ((_elapsed - hold) / (total - hold)).clamp(0.0, 1.0);
      _scroll.jumpTo(position.maxScrollExtent * progress);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      if (notification is ScrollStartNotification &&
          notification.dragDetails != null) {
        _manual = true;
      }
      return false;
    },
    child: SingleChildScrollView(
      controller: _scroll,
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: widget.style,
      ),
    ),
  );
}