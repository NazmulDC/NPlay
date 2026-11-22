import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'handler.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final p = handler.player;
  bool _shuffle = false;
  PlaylistMode _mode = PlaylistMode.none;
  double? _scrub;

  void _toggleMode() {
    setState(() {
      if (_mode == PlaylistMode.none) {
        _mode = PlaylistMode.loop;
      } else if (_mode == PlaylistMode.loop) {
        _mode = PlaylistMode.single;
      } else {
        _mode = PlaylistMode.none;
      }
    });
    p.setPlaylistMode(_mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Now Playing'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [C.deep, C.bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 240,
                  height: 240,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [C.blue, C.deep, C.blue2, C.deep, C.blue],
                    ),
                    boxShadow: [BoxShadow(color: Color(0x881E6BFF), blurRadius: 40)],
                  ),
                  child: const Icon(Icons.music_note_rounded, size: 96, color: Colors.white),
                ),
                const SizedBox(height: 32),
                ValueListenableBuilder<MediaEntry?>(
                  valueListenable: handler.current,
                  builder: (c, e, _) => Column(
                    children: [
                      Text(
                        e == null ? '' : cleanTitle(e.title),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(e?.folder ?? '', style: const TextStyle(color: C.mut)),
                    ],
                  ),
                ),
                const Spacer(),
                StreamBuilder<Duration>(
                  stream: p.stream.position,
                  initialData: p.state.position,
                  builder: (c, s) {
                    final pos = s.data ?? Duration.zero;
                    final dur = p.state.duration;
                    final max = dur.inMilliseconds.toDouble();
                    final cur = (_scrub ?? pos.inMilliseconds.toDouble());
                    return Column(
                      children: [
                        Slider(
                          value: max > 0 ? cur.clamp(0.0, max).toDouble() : 0.0,
                          min: 0,
                          max: max > 0 ? max : 1,
                          onChanged: (v) => setState(() => _scrub = v),
                          onChangeEnd: (v) {
                            p.seek(Duration(milliseconds: v.round()));
                            setState(() => _scrub = null);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmtDur(Duration(milliseconds: cur.round())),
                                style: const TextStyle(color: C.mut, fontSize: 12)),
                            Text(fmtDur(dur), style: const TextStyle(color: C.mut, fontSize: 12)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.shuffle_rounded, color: _shuffle ? C.blue2 : Colors.white70),
                      onPressed: () {
                        setState(() => _shuffle = !_shuffle);
                        p.setShuffle(_shuffle);
                      },
                    ),
                    IconButton(
                      iconSize: 38,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: () => handler.skipToPrevious(),
                    ),
                    StreamBuilder<bool>(
                      stream: p.stream.playing,
                      initialData: p.state.playing,
                      builder: (c, s) => IconButton(
                        iconSize: 72,
                        color: C.blue2,
                        icon: Icon((s.data ?? false)
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                        onPressed: () => p.playOrPause(),
                      ),
                    ),
                    IconButton(
                      iconSize: 38,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () => handler.skipToNext(),
                    ),
                    IconButton(
                      icon: Icon(
                        _mode == PlaylistMode.single ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                        color: _mode == PlaylistMode.none ? Colors.white70 : C.blue2,
                      ),
                      onPressed: _toggleMode,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
