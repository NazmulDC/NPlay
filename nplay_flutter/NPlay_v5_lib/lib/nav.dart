import 'package:flutter/material.dart';

import 'handler.dart';
import 'models.dart';
import 'music_page.dart';
import 'video_page.dart';

/// Opens [list] starting at [i] and shows the right player screen.
Future<void> playList(BuildContext context, List<MediaEntry> list, int i) async {
  final s = i - 20 < 0 ? 0 : i - 20;
  final e = i + 200 > list.length ? list.length : i + 200;
  final video = list[i].isVideo;
  await handler.setAudioOnly(false);
  await handler.openQueue(list.sublist(s, e), i - s);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => video ? const VideoPage() : const MusicPage(),
    ),
  );
}

/// Plays a video's sound only (audio-only mode) and opens the music screen.
Future<void> playAudioOnly(BuildContext context, List<MediaEntry> list, int i) async {
  final s = i - 20 < 0 ? 0 : i - 20;
  final e = i + 200 > list.length ? list.length : i + 200;
  await handler.setAudioOnly(true);
  await handler.openQueue(list.sublist(s, e), i - s);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const MusicPage()),
  );
}
