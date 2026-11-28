import 'dart:io';
import 'package:photo_manager/photo_manager.dart';

/// All scanned media by id (filled by the home page).
final Map<String, MediaEntry> mediaById = <String, MediaEntry>{};

class MediaEntry {
  final String id;
  final String title;
  final String folder;
  final int durationSec;
  final bool isVideo;
  final int width;
  final int height;
  final AssetEntity? asset;
  final String? path;
  final DateTime added;
  String? _resolved;
  String? _sizeText;

  MediaEntry({
    required this.id,
    required this.title,
    required this.folder,
    required this.durationSec,
    required this.isVideo,
    this.width = 0,
    this.height = 0,
    this.asset,
    this.path,
    DateTime? added,
  }) : added = added ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// "1080p" style label (empty if unknown).
  String get quality {
    final m = width < height ? width : height;
    if (m <= 0) return '';
    return '${m}p';
  }

  /// "484.41MB" style label, computed lazily and cached.
  String sizeText() {
    final cached = _sizeText;
    if (cached != null) return cached;
    int? b;
    try {
      String? p = path;
      final a = asset;
      if (p == null && a != null) {
        final rel = a.relativePath;
        final t = a.title;
        if (rel != null && t != null) p = '/storage/emulated/0/$rel$t';
      }
      if (p != null) {
        final f = File(p);
        if (f.existsSync()) b = f.lengthSync();
      }
    } catch (_) {}
    _sizeText = b == null ? '' : fmtSize(b);
    return _sizeText!;
  }

  /// Real file path on the phone (fast guess first, MediaStore fallback).
  Future<String?> resolvePath() async {
    if (_resolved != null) return _resolved;
    if (path != null) {
      _resolved = path;
      return _resolved;
    }
    final a = asset;
    if (a == null) return null;
    final rel = a.relativePath;
    final t = a.title;
    if (rel != null && t != null) {
      final guess = '/storage/emulated/0/$rel$t';
      if (File(guess).existsSync()) {
        _resolved = guess;
        return _resolved;
      }
    }
    // originFile can hang for a long time (or forever on some devices) when
    // the MediaStore entry is stale or the asset is a cloud-backed photo
    // item that was never fully downloaded, which used to freeze the whole
    // "open video" flow. Bound it so a single bad file can't block playback.
    try {
      final f = await a.originFile.timeout(const Duration(seconds: 8));
      _resolved = f?.path;
    } catch (_) {
      _resolved = null;
    }
    return _resolved;
  }
}

String fmtSize(int b) {
  if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(2)}GB';
  return '${(b / 1048576).toStringAsFixed(2)}MB';
}

String cleanTitle(String t) {
  final i = t.lastIndexOf('.');
  if (i > 0 && t.length - i <= 5) return t.substring(0, i);
  return t;
}

String monthLabel(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final name = m[d.month - 1];
  return d.year == DateTime.now().year ? name : '$name ${d.year}';
}

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = a.difference(b).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return 'This week';
  return monthLabel(d);
}
