import 'dart:io';

import 'package:flutter/services.dart';

import 'models.dart';

const _videoExt = {
  'mp4',
  'mkv',
  'webm',
  'avi',
  'mov',
  '3gp',
  'm4v',
  'flv',
  'ts',
  'wmv',
};
const _audioExt = {'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus', 'wma'};

bool? isVideoPath(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0) return null;
  final ext = path.substring(i + 1).toLowerCase();
  if (_videoExt.contains(ext)) return true;
  if (_audioExt.contains(ext)) return false;
  return null;
}

/// Builds a playable [MediaEntry] straight from a file path, without
/// needing it to already be in the scanned library. Used for files opened
/// via "Open with" from another app (file manager, VidMate, etc.) that
/// Android's MediaStore may not have indexed yet.
MediaEntry? adHocEntry(String path) {
  final video = isVideoPath(path);
  if (video == null) return null;
  if (!File(path).existsSync()) return null;
  final name = path.split('/').last;
  return MediaEntry(
    id: 'file:$path',
    title: cleanTitle(name),
    folder: 'Opened file',
    durationSec: 0,
    isVideo: video,
    path: path,
  );
}

/// Talks to the native side about the app being launched/resumed via
/// "Open with" on a media file.
class OpenIntent {
  static const _ch = MethodChannel('nplay/open');
  static const _scanCh = MethodChannel('nplay/mediascan');

  /// Path passed to the launching intent (cold start), if any.
  static Future<String?> getInitial() async {
    try {
      return await _ch.invokeMethod<String>('getInitial');
    } catch (_) {
      return null;
    }
  }

  /// Called for every later "Open with" while the app is already running.
  static void listen(void Function(String path) onOpen) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'open') {
        final p = call.arguments;
        if (p is String) onOpen(p);
      }
      return null;
    });
  }

  /// Asks Android to (re)index new files on disk, so a freshly downloaded
  /// video shows up in the library right away instead of waiting for the
  /// system's own background media scan.
  static Future<void> rescanSystem() async {
    try {
      await _scanCh.invokeMethod('scan');
    } catch (_) {}
  }
}
