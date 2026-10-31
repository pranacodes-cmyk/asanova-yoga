import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../logic/lesson_media.dart';

/// Where a film or clip plays from: a downloaded file, a bundled asset, or the media server.
enum MediaOrigin { file, asset, network }

typedef MediaSource = ({MediaOrigin origin, String path});

/// Lesson films and coach clips downloaded from the Asanova media server and kept on the phone
/// for offline replay (web `src/lib/media-store.ts`). Onboarding, the breath cues and the tutor
/// films ship inside the app. Lookup order everywhere: downloaded → bundled → streamed (and then
/// saved in the background so it plays offline next time).
class MediaStore {
  MediaStore._();
  static Directory? _dir;
  static Directory? _voiceDir;

  /// Coach clips are cached apart from films (their own server namespace, web `mediaUrl`).
  static File? _fileFor(String path) {
    final d = path.startsWith('voice/') ? _voiceDir : _dir;
    return d == null ? null : File('${d.path}/$path');
  }
  static Set<String> _bundled = const {};
  static final Set<String> _saving = {};

  /// Files the media server reported as not there (404) this run: the lesson still opens and those
  /// lines use the device voice (a film shows its pose photo) instead of blocking on a retry loop.
  static final Set<String> _unavailable = {};

  static Future<void> init() async {
    try {
      final support = await getApplicationSupportDirectory();
      _dir = Directory('${support.path}/media/v1');
      await _dir!.create(recursive: true);
      _voiceDir = Directory('${support.path}/media/voice-aac-lc-64-v2');
      await _voiceDir!.create(recursive: true);
      // legacy HE-AAC clips are never played again: free their space
      final legacy = Directory('${_dir!.path}/voice');
      if (legacy.existsSync()) unawaited(legacy.delete(recursive: true).catchError((_) => legacy));
    } catch (e) {
      debugPrint('Asanova media dir: $e');
    }
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _bundled = manifest.listAssets().toSet();
    } catch (e) {
      debugPrint('Asanova asset manifest: $e');
    }
  }

  /// `video/x.mp4` ships in the app as `assets/video/x.mp4`.
  static bool isBundled(String path) => _bundled.contains('assets/$path');

  static String url(String path) => mediaUrlFor(path);

  /// The downloaded copy, or null.
  static File? cached(String path) {
    final d = _fileFor(path);
    if (d == null) return null;
    final f = d;
    return f.existsSync() && f.lengthSync() > 0 ? f : null;
  }

  /// Where [path] plays from right now; streaming starts a background save.
  static MediaSource source(String path) {
    final f = cached(path);
    if (f != null) return (origin: MediaOrigin.file, path: f.path);
    if (isBundled(path)) {
      return (origin: MediaOrigin.asset, path: 'assets/$path');
    }
    cacheInBackground(path);
    return (origin: MediaOrigin.network, path: url(path));
  }

  /// Paths that are neither bundled nor downloaded yet.
  static List<String> missing(Iterable<String> paths) => [
    for (final p in paths)
      if (!isBundled(p) && !_unavailable.contains(p) && cached(p) == null) p,
  ];

  /// Files fetched in parallel; a slow or broken file never holds up the others.
  static const parallel = 8;

  /// Tries per file: quick back-off retries cover flaky mobile networks.
  static const attempts = 4;

  /// Downloads [paths] ([parallel] at a time) with real per-file progress. Every file is checked
  /// against the server's byte count; files that still fail get one more pass at the end, and only
  /// then is an error thrown. Finished files stay saved, so a retry resumes.
  static Future<void> download(
    List<String> paths, {
    required void Function(int done, int total) onProgress,
    required bool Function() cancelled,
  }) async {
    final d = _dir;
    if (d == null) throw StateError('media storage unavailable');
    final client = http.Client();
    var done = 0;
    onProgress(0, paths.length);
    Future<List<String>> pass(List<String> list) async {
      final failed = <String>[];
      var next = 0;
      Future<void> worker() async {
        while (next < list.length) {
          if (cancelled()) return;
          final p = list[next++];
          try {
            await _fetch(client, d, p);
          } on _NotOnServer {
            _unavailable.add(p);
          } catch (e) {
            failed.add(p);
            continue;
          }
          done++;
          if (!cancelled()) onProgress(done, paths.length);
        }
      }

      await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
      return failed;
    }

    try {
      var failed = await pass(paths);
      if (failed.isNotEmpty && !cancelled()) failed = await pass(failed);
      if (failed.isNotEmpty && !cancelled()) {
        throw HttpException('${failed.length} files failed to download');
      }
    } finally {
      client.close();
    }
  }

  static Future<void> _fetch(http.Client client, Directory d, String p) async {
    Object? last;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt * attempt));
      }
      try {
        final res = await client
            .get(Uri.parse(url(p)))
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 404) throw const _NotOnServer();
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
          throw HttpException('HTTP ${res.statusCode} for $p');
        }
        final expected = res.contentLength;
        if (expected != null && expected > 0 && expected != res.bodyBytes.length) {
          throw HttpException('incomplete $p: ${res.bodyBytes.length}/$expected bytes');
        }
        final f = _fileFor(p) ?? File('${d.path}/$p');
        await f.parent.create(recursive: true);
        final tmp = File('${f.path}.part');
        await tmp.writeAsBytes(res.bodyBytes, flush: true);
        if (await tmp.length() != res.bodyBytes.length) {
          throw HttpException('write failed for $p');
        }
        await tmp.rename(f.path);
        return;
      } on _NotOnServer {
        rethrow;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? HttpException('download failed: $p');
  }

  /// Saves a streamed file in the background so it plays offline next time (best effort).
  static void cacheInBackground(String path) {
    final d = _dir;
    if (d == null || cached(path) != null || isBundled(path)) return;
    if (!_saving.add(path)) return;
    final client = http.Client();
    unawaited(
      _fetch(client, d, path).catchError((_) {}).whenComplete(() {
        client.close();
        _saving.remove(path);
      }),
    );
  }
}

/// The media server answered 404: retrying cannot help.
class _NotOnServer implements Exception {
  const _NotOnServer();
}
