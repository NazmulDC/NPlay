import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'handler.dart';
import 'models.dart';
import 'music_page.dart';
import 'store.dart';
import 'theme.dart';
import 'video_page.dart';

String fmtDur(Duration d) {
  String t(int x) => x.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${t(m)}:${t(s)}' : '${t(m)}:${t(s)}';
}

/// Saved watch progress (0..1) or null if none.
double? progressOf(MediaEntry e) {
  final total = e.durationSec * 1000;
  final saved = Store.pos(e.id);
  if (!e.isVideo || total <= 0 || saved <= 3000) return null;
  return (saved / total).clamp(0.0, 1.0).toDouble();
}

/// True for videos added in the last 3 days that were never played.
bool isNewMedia(MediaEntry e) {
  if (!e.isVideo) return false;
  if (DateTime.now().difference(e.added).inDays >= 3) return false;
  if (Store.pos(e.id) > 0) return false;
  return !Store.history.contains(e.id);
}

String _two(int n) => n.toString().padLeft(2, '0');

Future<void> showMediaInfo(BuildContext context, MediaEntry e) {
  final rows = <MapEntry<String, String>>[
    MapEntry('Name', e.title),
    MapEntry('Duration', fmtDur(Duration(seconds: e.durationSec))),
    if (e.width > 0) MapEntry('Resolution', '${e.width} x ${e.height}'),
    if (e.sizeText().isNotEmpty) MapEntry('Size', e.sizeText()),
    MapEntry('Folder', e.folder),
    MapEntry('Added', '${e.added.year}-${_two(e.added.month)}-${_two(e.added.day)}'),
  ];
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.card,
      title: const Text('Info'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.key, style: const TextStyle(fontSize: 11.5, color: C.mut)),
                    Text(r.value, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}

class Thumb extends StatefulWidget {
  final MediaEntry entry;
  final double width;
  final double height;
  final double? progress;
  final bool isNew;
  const Thumb({
    super.key,
    required this.entry,
    this.width = 124,
    this.height = 72,
    this.progress,
    this.isNew = false,
  });

  @override
  State<Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<Thumb> {
  Future<Uint8List?>? _f;

  @override
  void initState() {
    super.initState();
    final a = widget.entry.asset;
    if (a != null && widget.entry.isVideo) {
      _f = a.thumbnailDataWithSize(const ThumbnailSize(400, 240));
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Center(
      child: Icon(
        widget.entry.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
        color: C.blue2,
        size: 28,
      ),
    );
    final big = widget.width > 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [C.deep, C.card],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_f == null)
              icon
            else
              FutureBuilder<Uint8List?>(
                future: _f,
                builder: (c, s) => s.data != null
                    ? Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true)
                    : icon,
              ),
            if (widget.entry.durationSec > 0 && widget.entry.isVideo)
              Positioned(
                right: 6,
                bottom: widget.progress != null ? 9 : 6,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: big ? 6 : 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: big ? 15 : 12, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        fmtDur(Duration(seconds: widget.entry.durationSec)),
                        style: TextStyle(fontSize: big ? 11.5 : 10, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.isNew)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(
                    color: C.blue,
                    borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
                  ),
                  child: const Text(
                    'New',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            if (widget.progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: widget.progress,
                  minHeight: 3,
                  backgroundColor: Colors.black45,
                  color: C.blue2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small chip showing where the file comes from (VidMate, Camera, Movies...).
class SourceChip extends StatelessWidget {
  final String name;
  const SourceChip({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final n = name.toLowerCase();
    Widget icon;
    if (n.contains('vidmate')) {
      icon = Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Text(
          'V',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    } else if (n.contains('camera')) {
      icon = const Icon(Icons.photo_camera_rounded, size: 17, color: C.mut);
    } else if (n.contains('movie')) {
      icon = const Icon(Icons.movie_rounded, size: 17, color: C.mut);
    } else if (n.contains('download')) {
      icon = const Icon(Icons.download_rounded, size: 17, color: C.mut);
    } else if (n.contains('whatsapp')) {
      icon = const Icon(Icons.chat_rounded, size: 17, color: C.mut);
    } else {
      icon = const Icon(Icons.folder_rounded, size: 17, color: C.mut);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFCFE0FF)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row used for videos (big thumbnail) and songs (small thumbnail).
class MediaTile extends StatelessWidget {
  final MediaEntry entry;
  final VoidCallback onTap;
  final void Function(String action)? onAction;
  final bool inPlaylist;
  const MediaTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onAction,
    this.inPlaylist = false,
  });

  Widget _menu() {
    if (onAction == null) return const SizedBox(width: 8);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: C.mut),
      onSelected: onAction,
      itemBuilder: (_) => [
        const PopupMenuItem<String>(value: 'play', child: Text('Play')),
        if (entry.isVideo) const PopupMenuItem<String>(value: 'audio', child: Text('Play as audio')),
        const PopupMenuItem<String>(value: 'fav', child: Text('Add to favorites')),
        if (inPlaylist)
          const PopupMenuItem<String>(value: 'remove', child: Text('Remove from playlist'))
        else
          const PopupMenuItem<String>(value: 'playlist', child: Text('Add to playlist')),
        const PopupMenuItem<String>(value: 'info', child: Text('Info')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!entry.isVideo) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 4, 7),
          child: Row(
            children: [
              Thumb(entry: entry, width: 54, height: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanTitle(entry.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.folder} • ${fmtDur(Duration(seconds: entry.durationSec))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: C.mut),
                    ),
                  ],
                ),
              ),
              _menu(),
            ],
          ),
        ),
      );
    }
    final w = MediaQuery.of(context).size.width * 0.42;
    final meta = [entry.quality, entry.sizeText()].where((s) => s.isNotEmpty).join(' | ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Thumb(
              entry: entry,
              width: w,
              height: w * 0.6,
              progress: progressOf(entry),
              isNew: isNewMedia(entry),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanTitle(entry.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meta, style: const TextStyle(fontSize: 12.5, color: C.mut)),
                  ],
                  const SizedBox(height: 6),
                  SourceChip(name: entry.folder),
                ],
              ),
            ),
            _menu(),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the actions for one media item (long press in grid).
Future<void> showTileMenu(
  BuildContext context,
  MediaEntry e,
  void Function(String action) onAction, {
  bool inPlaylist = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      Widget item(IconData icon, String label, String action) {
        return ListTile(
          leading: Icon(icon, color: C.blue2),
          title: Text(label),
          onTap: () {
            Navigator.pop(ctx);
            onAction(action);
          },
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  cleanTitle(e.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              item(Icons.play_arrow_rounded, 'Play', 'play'),
              if (e.isVideo) item(Icons.headphones_rounded, 'Play as audio', 'audio'),
              item(Icons.favorite_border_rounded, 'Add to favorites', 'fav'),
              if (inPlaylist)
                item(Icons.playlist_remove_rounded, 'Remove from playlist', 'remove')
              else
                item(Icons.playlist_add_rounded, 'Add to playlist', 'playlist'),
              item(Icons.info_outline_rounded, 'Info', 'info'),
            ],
          ),
        ),
      );
    },
  );
}

/// Grid cell: big rounded thumbnail with duration, title under it.
class VideoGridTile extends StatelessWidget {
  final MediaEntry entry;
  final VoidCallback onTap;
  final void Function(String action) onAction;
  const VideoGridTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return GestureDetector(
          onTap: onTap,
          onLongPress: () => showTileMenu(context, entry, onAction),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Thumb(
                entry: entry,
                width: w,
                height: w * 0.57,
                progress: progressOf(entry),
                isNew: isNewMedia(entry),
              ),
              const SizedBox(height: 8),
              Text(
                cleanTitle(entry.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom navigation bar with the glowing blue pill (like the design).
class NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const NavBar({super.key, required this.index, required this.onTap});

  static const List<IconData> _icons = [
    Icons.smart_display_rounded,
    Icons.music_note_rounded,
    Icons.queue_music_rounded,
    Icons.person_rounded,
  ];
  static const List<String> _labels = ['VIDEO', 'MUSIC', 'PLAYLIST', 'ME'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: const Color(0x992C7BFF), width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x552C7BFF), blurRadius: 18)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Row(
            children: [
              for (int i = 0; i < _icons.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: i == index
                            ? const LinearGradient(
                                colors: [Color(0x662C7BFF), Color(0x1A2C7BFF)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        border: i == index
                            ? Border.all(color: const Color(0x884D9BFF), width: 1)
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icons[i],
                            size: 30,
                            color: i == index ? C.blue2 : Colors.white70,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _labels[i],
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: i == index ? C.blue2 : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar that shows what is playing (music, or video in audio-only mode).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MediaEntry?>(
      valueListenable: handler.current,
      builder: (context, e, _) {
        if (e == null) return const SizedBox.shrink();
        return StreamBuilder<bool>(
          stream: handler.player.stream.playing,
          initialData: handler.player.state.playing,
          builder: (context, s) {
            final playing = s.data ?? false;
            if (e.isVideo && !playing) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Material(
                color: C.card,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => e.isVideo && !handler.audioOnly.value
                          ? const VideoPage()
                          : const MusicPage(),
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: C.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cleanTitle(e.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: () => handler.skipToPrevious(),
                        ),
                        IconButton(
                          icon: Icon(
                            playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 36,
                            color: C.blue2,
                          ),
                          onPressed: () => handler.player.playOrPause(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: () => handler.skipToNext(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
