import 'package:photo_manager/photo_manager.dart';
import 'models.dart';

class Library {
  static Future<bool> ask() async {
    final ps = await PhotoManager.requestPermissionExtend(
      requestOption: PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.video | RequestType.audio,
          mediaLocation: false,
        ),
      ),
    );
    return ps.hasAccess;
  }

  static Future<List<MediaEntry>> scan(bool video) async {
    final out = <MediaEntry>[];
    try {
      final type = video ? RequestType.video : RequestType.audio;
      final paths = await PhotoManager.getAssetPathList(
        type: type,
        onlyAll: true,
      ).timeout(const Duration(seconds: 20));
      if (paths.isEmpty) return out;
      final all = paths.first;
      final n = await all.assetCountAsync.timeout(const Duration(seconds: 10));
      const step = 500;
      for (int s = 0; s < n; s += step) {
        final end = s + step > n ? n : s + step;
        final list = await all
            .getAssetListRange(start: s, end: end)
            .timeout(const Duration(seconds: 15));
        for (final a in list) {
          // A single corrupted/odd MediaStore row shouldn't take down the
          // whole scan and leave the app stuck on the loading spinner.
          try {
            out.add(MediaEntry(
              id: a.id,
              title: a.title ?? 'Unknown',
              folder: _folderName(a.relativePath ?? ''),
              durationSec: a.duration,
              isVideo: video,
              width: a.width,
              height: a.height,
              asset: a,
              added: a.createDateTime,
            ));
          } catch (_) {
            // skip this one entry, keep scanning
          }
        }
      }
    } catch (_) {
      // Scanning failed or timed out partway through (stale permission,
      // a flaky device MediaStore, etc.) — return whatever was collected
      // so far instead of leaving the caller hanging forever.
    }
    return out;
  }

  static String _folderName(String rel) {
    final parts = rel.split('/').where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'Internal storage' : parts.last;
  }
}
