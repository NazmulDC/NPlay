import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'library.dart';
import 'models.dart';
import 'nav.dart';
import 'open_intent.dart';
import 'pages.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tc = TabController(length: 2, vsync: this);
  int _nav = 0; // 0 = Video, 1 = Music, 2 = Playlist, 3 = Me
  List<MediaEntry> _videos = [];
  List<MediaEntry> _songs = [];
  bool _loading = true;
  bool _denied = false;
  bool _searching = false;
  bool _grid = true;
  String _q = '';
  String _sort = 'date';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    OpenIntent.getInitial().then((p) {
      if (p != null) _playFile(p);
    });
    OpenIntent.listen(_playFile);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-refresh every time NPlay comes back to the foreground, so a
    // video downloaded/copied while the app was in the background shows
    // up without the person having to tap Rescan.
    if (state == AppLifecycleState.resumed) {
      if (_denied) {
        _load();
      } else {
        _silentRefresh();
      }
    }
  }

  /// Rescans in the background without showing the loading spinner, so
  /// the current screen doesn't flicker every time the app is resumed.
  Future<void> _silentRefresh() async {
    OpenIntent.rescanSystem();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final v = await Library.scan(true);
    final s = await Library.scan(false);
    if (!mounted) return;
    setState(() {
      _videos = v;
      _songs = s;
      mediaById.clear();
      for (final e in v) {
        mediaById[e.id] = e;
      }
      for (final e in s) {
        mediaById[e.id] = e;
      }
    });
  }

  /// Plays a file handed to NPlay via "Open with" from another app, even
  /// when it isn't in the scanned library yet.
  Future<void> _playFile(String path) async {
    final e = adHocEntry(path);
    if (e == null) {
      if (mounted) snack(context, 'Ei file-ta play kora gelo na.');
      return;
    }
    mediaById[e.id] = e;
    if (!mounted) return;
    await playList(context, [e], 0);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    OpenIntent.rescanSystem();
    final ok = await Library.ask();
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }
    final v = await Library.scan(true);
    final s = await Library.scan(false);
    if (!mounted) return;
    setState(() {
      _videos = v;
      _songs = s;
      mediaById.clear();
      for (final e in v) {
        mediaById[e.id] = e;
      }
      for (final e in s) {
        mediaById[e.id] = e;
      }
      _loading = false;
      _denied = false;
    });
    Permission.notification.request();
  }

  List<MediaEntry> _view(List<MediaEntry> src) {
    final q = _q.toLowerCase();
    final l = src
        .where((e) => q.isEmpty || e.title.toLowerCase().contains(q))
        .toList();
    if (_sort == 'name') {
      l.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sort == 'duration') {
      l.sort((a, b) => b.durationSec.compareTo(a.durationSec));
    } else {
      l.sort((a, b) => b.added.compareTo(a.added));
    }
    return l;
  }

  Future<void> _open(List<MediaEntry> list, int i) async {
    await playList(context, list, i);
    if (mounted) setState(() {});
  }

  Future<void> _action(String a, List<MediaEntry> list, int i) async {
    final id = list[i].id;
    final deleted = await handleTileAction(context, a, list, i);
    if (!mounted) return;
    setState(() {
      if (deleted) {
        _videos.removeWhere((e) => e.id == id);
        _songs.removeWhere((e) => e.id == id);
      }
    });
  }

  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Clear history?'),
        content: const Text('Sob dekha-r history muche jabe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await Store.clearHistory();
      if (mounted) setState(() {});
    }
  }

  Widget _message(
    String text, {
    String? button,
    VoidCallback? onPressed,
    IconData icon = Icons.video_library_rounded,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: C.blue2),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.mut, height: 1.6),
            ),
            if (button != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onPressed, child: Text(button)),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Header: wavy blue banner, NPlay logo, search
  // ------------------------------------------------------------------
  Widget _header() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      height: 112 + top,
      padding: EdgeInsets.fromLTRB(16, top, 6, 0),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/header_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: _searching
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _q = v),
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 28),
                  onPressed: () => setState(() {
                    _searching = false;
                    _q = '';
                  }),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/images/logo.png', height: 46),
                      const SizedBox(height: 2),
                      const Text(
                        'by Md Nazmul Haque',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 30),
                  onPressed: () => setState(() => _searching = true),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------------
  // History row (always visible on the Video screen)
  // ------------------------------------------------------------------
  Widget _historyBlock() {
    final list = <MediaEntry>[];
    for (final id in Store.history) {
      final e = mediaById[id];
      if (e != null && e.isVideo) list.add(e);
      if (list.length >= 10) break;
    }
    final w = MediaQuery.of(context).size.width * 0.40;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 46,
                    height: 3,
                    decoration: BoxDecoration(
                      color: C.blue2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 28),
                onPressed: _confirmClear,
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Text(
              'Ekhono kono history nai. Kono video chalale ekhane dekhabe.',
              style: TextStyle(color: C.mut, fontSize: 12.5),
            ),
          )
        else
          SizedBox(
            height: w * 0.56 + 28,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (c, i) => const SizedBox(width: 14),
              itemBuilder: (c, i) => GestureDetector(
                onTap: () => _open(list, i),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.blue2, width: 1.4),
                    boxShadow: const [
                      BoxShadow(color: Color(0x662C7BFF), blurRadius: 10),
                    ],
                  ),
                  child: NThumb(
                    entry: list[i],
                    width: w,
                    height: w * 0.56,
                    progress: progressOf(list[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Tabs row: Video | Folder        [sort] [grid/list]
  // ------------------------------------------------------------------
  Widget _tabsRow() {
    return Row(
      children: [
        Expanded(
          child: TabBar(
            controller: _tc,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: C.blue2,
            indicatorWeight: 3,
            labelColor: C.blue2,
            unselectedLabelColor: Colors.white,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.only(left: 2),
            labelStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(text: 'Video'),
              Tab(text: 'Folder'),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.swap_vert_rounded, size: 30, color: C.blue2),
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (_) => const [
            PopupMenuItem<String>(value: 'date', child: Text('Newest')),
            PopupMenuItem<String>(value: 'name', child: Text('Name')),
            PopupMenuItem<String>(value: 'duration', child: Text('Longest')),
          ],
        ),
        IconButton(
          icon: Icon(
            _grid ? Icons.grid_view_rounded : Icons.view_list_rounded,
            size: 28,
            color: C.blue2,
          ),
          onPressed: () => setState(() => _grid = !_grid),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Video tab: Today / Yesterday ... groups, 2-column grid or list
  // ------------------------------------------------------------------
  Widget _gridTile(List<MediaEntry> list, int i) {
    return VideoGridTile(
      entry: list[i],
      onTap: () => _open(list, i),
      onAction: (a) => _action(a, list, i),
    );
  }

  Widget _videosTab() {
    final list = _view(_videos);
    if (list.isEmpty) {
      return _message(
        'Kono video paoa jayni.',
        button: 'Rescan',
        onPressed: _load,
      );
    }
    final per = _grid ? 2 : 1;
    final rows = <Object>[];
    String? last;
    List<int>? cur;
    for (int i = 0; i < list.length; i++) {
      if (_sort == 'date') {
        final m = dayLabel(list[i].added);
        if (m != last) {
          rows.add(m);
          last = m;
          cur = null;
        }
      }
      if (cur == null || cur.length >= per) {
        cur = <int>[];
        rows.add(cur);
      }
      cur!.add(i);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: rows.length,
      itemBuilder: (c, k) {
        final r = rows[k];
        if (r is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Text(
              r,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          );
        }
        final idx = r as List<int>;
        if (!_grid) {
          final i = idx.first;
          return MediaTile(
            entry: list[i],
            onTap: () => _open(list, i),
            onAction: (a) => _action(a, list, i),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _gridTile(list, idx[0])),
              const SizedBox(width: 12),
              Expanded(
                child: idx.length > 1
                    ? _gridTile(list, idx[1])
                    : const SizedBox(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _foldersTab() {
    final map = <String, List<MediaEntry>>{};
    for (final e in _view(_videos)) {
      map.putIfAbsent(e.folder, () => <MediaEntry>[]).add(e);
    }
    final keys = map.keys.toList()..sort();
    if (keys.isEmpty) {
      return _message(
        'Kono folder paoa jayni.',
        button: 'Rescan',
        onPressed: _load,
        icon: Icons.folder_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      itemCount: keys.length,
      itemBuilder: (c, i) {
        final k = keys[i];
        final l = map[k]!;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.folder_rounded, color: C.blue2, size: 28),
          ),
          title: Text(
            k,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          subtitle: Text(
            '${l.length} video',
            style: const TextStyle(color: C.mut, fontSize: 12.5),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: C.mut),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FolderPage(name: k, items: l),
              ),
            );
            if (mounted) await _silentRefresh();
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Playlist screen
  // ------------------------------------------------------------------
  Widget _bigRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: C.bg2,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: C.mut, fontSize: 12.5),
          ),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _playlistList() {
    final pls = Store.playlists;
    final favCount = (pls['Favorites'] ?? <String>[]).length;
    final recent = _view(_videos);
    final recentList = recent.length > 50 ? recent.sublist(0, 50) : recent;
    final names = pls.keys.where((n) => n != 'Favorites').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      children: [
        _bigRow(
          icon: Icons.add_rounded,
          color: C.blue,
          title: 'New playlist',
          subtitle: 'Nijer playlist banao',
          onTap: () async {
            final n = await askPlaylistName(context);
            if (n != null && n.isNotEmpty) {
              await Store.createPlaylist(n);
              if (mounted) setState(() {});
            }
          },
        ),
        _bigRow(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFE5484D),
          title: 'Favorites',
          subtitle: '$favCount items',
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PlaylistPage(name: 'Favorites'),
              ),
            );
            if (mounted) await _silentRefresh();
          },
        ),
        _bigRow(
          icon: Icons.schedule_rounded,
          color: C.deep,
          title: 'Recently added',
          subtitle: '${recentList.length} videos',
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    FolderPage(name: 'Recently added', items: recentList),
              ),
            );
            if (mounted) await _silentRefresh();
          },
        ),
        for (final name in names)
          _bigRow(
            icon: Icons.queue_music_rounded,
            color: C.card,
            title: name,
            subtitle: '${pls[name]!.length} items',
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: C.mut),
              onSelected: (v) async {
                if (v == 'delete') {
                  await Store.deletePlaylist(name);
                  if (mounted) setState(() {});
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete playlist'),
                ),
              ],
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlaylistPage(name: name)),
              );
              if (mounted) await _silentRefresh();
            },
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Me screen
  // ------------------------------------------------------------------
  Widget _meRow(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? sub,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: C.blue2, size: 23),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: sub == null
          ? null
          : Text(sub, style: const TextStyle(color: C.mut, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: C.mut),
      onTap: onTap,
    );
  }

  Widget _meScreen() {
    final top = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.only(top: top + 8, bottom: 16),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [C.deep, C.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/nazmul.jpg',
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/images/logo.png', height: 38),
                    const SizedBox(height: 6),
                    const Text(
                      'by Md Nazmul Haque',
                      style: TextStyle(fontSize: 13.5, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ad-free video & music player',
                      style: TextStyle(fontSize: 11.5, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          value: Store.bg,
          title: const Text(
            'Background play',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: const Text(
            'App theke ber hole-o sound chalu thakbe',
            style: TextStyle(color: C.mut, fontSize: 12),
          ),
          onChanged: (v) async {
            await Store.setBg(v);
            if (mounted) setState(() {});
          },
        ),
        _meRow(Icons.refresh_rounded, 'Rescan library', () {
          setState(() => _nav = 0);
          _load();
        }, sub: '${_videos.length} videos, ${_songs.length} songs'),
        _meRow(Icons.history_rounded, 'Clear history', _confirmClear),
        _meRow(Icons.info_outline_rounded, 'About NPlay', () {
          showAboutDialog(
            context: context,
            applicationName: 'NPlay',
            applicationVersion: '1.3.0',
            children: const [
              Text('Ad-free video & music player.\nMade by Md Nazmul Haque.'),
            ],
          );
        }),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Screens
  // ------------------------------------------------------------------
  Widget _videoScreen() {
    return Column(
      children: [
        _header(),
        if (!_searching) _historyBlock(),
        _tabsRow(),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [_videosTab(), _foldersTab()],
          ),
        ),
      ],
    );
  }

  Widget _musicScreen() {
    final list = _view(_songs);
    return Column(
      children: [
        _header(),
        const SizedBox(height: 6),
        Expanded(
          child: list.isEmpty
              ? _message(
                  'Kono music paoa jayni.',
                  button: 'Rescan',
                  onPressed: _load,
                  icon: Icons.library_music_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: list.length,
                  itemBuilder: (c, i) => MediaTile(
                    entry: list[i],
                    onTap: () => _open(list, i),
                    onAction: (a) => _action(a, list, i),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _playlistScreen() {
    return Column(
      children: [
        _header(),
        Expanded(child: _playlistList()),
      ],
    );
  }

  Widget _content() {
    if (_loading) {
      return Column(
        children: [
          _header(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (_denied) {
      return Column(
        children: [
          _header(),
          Expanded(
            child: _message(
              'Video ar music dekhar jonno permission dorkar.',
              button: 'Permission dao',
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        ],
      );
    }
    if (_nav == 1) return _musicScreen();
    if (_nav == 2) return _playlistScreen();
    if (_nav == 3) return _meScreen();
    return _videoScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF081634), C.bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(child: _content()),
            const MiniPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: NavBar(
        index: _nav,
        onTap: (i) => setState(() {
          _nav = i;
          _searching = false;
          _q = '';
        }),
      ),
    );
  }
}
