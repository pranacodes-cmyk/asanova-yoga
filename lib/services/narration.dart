import 'dart:async';

import '../logic/logic.dart' show speechSeconds;
import 'audio_service.dart';

/// Speaks lines one at a time in the coach voice so the screen can caption the line being
/// spoken (web `src/lib/narration.ts`). With the voice off, each line stays up for its spoken
/// length. A safety timer moves on if a clip never reports its end. Pause stops the voice and
/// resume repeats the current line.
class Narration {
  Narration({
    required this.lines,
    required this.voiceOn,
    this.rate = 0.95,
    this.onLine,
    this.onDone,
  });

  final List<String> lines;
  final bool voiceOn;
  final double rate;
  final void Function(int index)? onLine;
  final void Function()? onDone;

  int index = 0;
  bool _active = false, _done = false;
  int _gen = 0;
  Timer? _timer, _safety;

  bool get isDone => _done;

  void start() {
    index = 0;
    _done = false;
    _play();
  }

  void pause() {
    _active = false;
    _gen++;
    _timer?.cancel();
    _safety?.cancel();
    if (voiceOn) Voice.stop();
  }

  void resume() {
    if (_done || _active) return;
    _play();
  }

  /// Stops without calling [onDone].
  void dispose() {
    pause();
    _done = true;
  }

  void _play() {
    _timer?.cancel();
    _safety?.cancel();
    final g = ++_gen;
    _active = true;
    while (index < lines.length && lines[index].trim().isEmpty) {
      index++;
    }
    if (index >= lines.length) {
      _active = false;
      _done = true;
      onDone?.call();
      return;
    }
    onLine?.call(index);
    final line = lines[index];
    final est = speechSeconds([line]);
    final started = DateTime.now();
    void next() {
      if (g != _gen) return;
      _gen++;
      _timer?.cancel();
      _safety?.cancel();
      // A voice that fails at once (no clip, no device voice) would flash the line past:
      // keep it on screen for at least half its reading time.
      final spent = DateTime.now().difference(started).inMilliseconds;
      final floor = voiceOn ? (est * 500).round() - spent : 0;
      _timer = Timer(Duration(milliseconds: 250 + (floor > 0 ? floor : 0)), () {
        index++;
        _play();
      });
    }

    if (voiceOn) {
      Voice.say([line], rate: rate, onDone: next);
      _safety = Timer(
        Duration(milliseconds: ((est * 2 + 4) * 1000).round()),
        next,
      );
    } else {
      _timer = Timer(Duration(milliseconds: (est * 1000).round()), next);
    }
  }
}
