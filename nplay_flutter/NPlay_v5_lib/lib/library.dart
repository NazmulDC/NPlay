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
    final type = video ? RequestType.video : RequestType.audio;
    final paths = await PhotoManager.getAssetPathList(
      type: type,
      onlyAll: true,
    );
    if (paths.isEmpty) return [];
    final all = paths.first;
    final n = await all.assetCountAsync;
    final out = <MediaEntry>[];
    const step = 500;
    for (int s = 0; s < n; s += step) {
      final end = s + step > n ? n : s + step;
      final list = await all.getAssetListRange(start: s, end: end);
      for (final a in list) {
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
      }
    }
    return out;
  }

  static String _folderName(String rel) {
    final parts = rel.split('/').where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'Internal storage' : parts.last;
  }
}
