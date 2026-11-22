import 'package:flutter/material.dart';

import 'models.dart';
import 'nav.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

void snack(BuildContext c, String t) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));
}

Future<String?> askPlaylistName(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.card,
      title: const Text('New playlist'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

Future<void> showAddToPlaylist(BuildContext context, MediaEntry e) async {
  final pls = Store.playlists;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add to playlist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: C.blue2),
              title: const Text('New playlist'),
              onTap: () async {
                Navigator.pop(ctx);
                final n = await askPlaylistName(context);
                if (n != null && n.isNotEmpty) {
                  await Store.addToPlaylist(n, e.id);
                  if (context.mounted) snack(context, 'Added to $n');
                }
              },
            ),
            for (final name in pls.keys)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: C.blue2),
                title: Text(name),
                subtitle: Text('${pls[name]!.length} items', style: const TextStyle(color: C.mut)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Store.addToPlaylist(name, e.id);
                  if (context.mounted) snack(context, 'Added to $name');
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Handles the 3-dot menu actions that are common to every list.
Future<void> handleTileAction(
  BuildContext context,
  String action,
  List<MediaEntry> list,
  int i,
) async {
  if (action == 'play') {
    await playList(context, list, i);
  } else if (action == 'audio') {
    await playAudioOnly(context, list, i);
  } else if (action == 'playlist') {
    await showAddToPlaylist(context, list[i]);
  } else if (action == 'fav') {
    await Store.addToPlaylist('Favorites', list[i].id);
    if (context.mounted) snack(context, 'Added to Favorites');
  } else if (action == 'info') {
    await showMediaInfo(context, list[i]);
  }
}

class FolderPage extends StatefulWidget {
  final String name;
  final List<MediaEntry> items;
  const FolderPage({super.key, required this.name, required this.items});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: C.deep,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 6),
              itemCount: items.length,
              itemBuilder: (c, i) => MediaTile(
                entry: items[i],
                onTap: () async {
                  await playList(context, items, i);
                  if (mounted) setState(() {});
                },
                onAction: (a) async {
                  await handleTileAction(context, a, items, i);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}

class PlaylistPage extends StatefulWidget {
  final String name;
  const PlaylistPage({super.key, required this.name});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List<MediaEntry> _items() {
    final ids = Store.playlists[widget.name] ?? <String>[];
    final l = <MediaEntry>[];
    for (final id in ids) {
      final e = mediaById[id];
      if (e != null) l.add(e);
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: C.deep,
        actions: [
          IconButton(
            tooltip: 'Play all',
            icon: const Icon(Icons.play_circle_fill_rounded),
            onPressed: items.isEmpty
                ? null
                : () async {
                    await playList(context, items, 0);
                    if (mounted) setState(() {});
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Playlist khali.\nVideo-r 3-dot menu theke "Add to playlist" chaap.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: C.mut, height: 1.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 6),
                    itemCount: items.length,
                    itemBuilder: (c, i) => MediaTile(
                      entry: items[i],
                      inPlaylist: true,
                      onTap: () async {
                        await playList(context, items, i);
                        if (mounted) setState(() {});
                      },
                      onAction: (a) async {
                        if (a == 'remove') {
                          await Store.removeFromPlaylist(widget.name, items[i].id);
                        } else {
                          await handleTileAction(context, a, items, i);
                        }
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
