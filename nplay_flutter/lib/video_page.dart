import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'brightness.dart';
import 'handler.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with WidgetsBindingObserver {
  final p = handler.player;

  bool _controls = true;
  bool _locked = false;
  bool _showUnlock = false;
  bool _landscape = true;
  bool _boost = false;
  bool _muted = false;
  bool _bg = Store.bg;
  double _speed = 1.0;
  double _bright = 0.5;
  double _vol = 100.0;
  int _sleepMin = 0;
  BoxFit _fit = BoxFit.contain;
  double? _scrub;

  String? _hud;
  IconData _hudIcon = Icons.info_outline_rounded;
  String? _seekFb;
  bool _seekLeft = false;

  Offset _dtPos = Offset.zero;
  Duration? _dragTarget;

  Timer? _hideT;
  Timer? _unlockT;
  Timer? _saveT;
  Timer? _fbT;
  Timer? _hudT;
  Timer? _sleepT;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vol = p.state.volume;
    Bright.current().then((b) {
      if (mounted) setState(() => _bright = b);
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyOrientation();
    WakelockPlus.enable();
    _saveT = Timer.periodic(const Duration(seconds: 3), (_) => _save());
    _armHide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideT?.cancel();
    _unlockT?.cancel();
    _saveT?.cancel();
    _fbT?.cancel();
    _hudT?.cancel();
    _sleepT?.cancel();
    _save();
    p.setRate(1.0);
    Bright.reset();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!handler.audioOnly.value) {
      p.pause();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (handler.audioOnly.value) return;
    if (state == AppLifecycleState.paused && _bg) {
      // save battery: stop decoding the picture, keep the sound
      p.setVideoTrack(VideoTrack.no());
    } else if (state == AppLifecycleState.resumed) {
      p.setVideoTrack(VideoTrack.auto());
    }
  }

  void _applyOrientation() {
    if (_landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _rotate() {
    setState(() => _landscape = !_landscape);
    _applyOrientation();
    _armHide();
  }

  void _save() {
    final e = handler.current.value;
    if (e == null || !e.isVideo) return;
    final pos = p.state.position.inMilliseconds;
    final dur = p.state.duration.inMilliseconds;
    if (dur > 0 && pos > dur - 5000) {
      Store.setPos(e.id, 0);
    } else if (pos > 0) {
      Store.setPos(e.id, pos);
    }
  }

  void _armHide() {
    _hideT?.cancel();
    _hideT = Timer(const Duration(seconds: 4), () {
      if (mounted && p.state.playing && _scrub == null) {
        setState(() => _controls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _armHide();
  }

  void _skip(int sec) {
    var t = p.state.position + Duration(seconds: sec);
    if (t < Duration.zero) t = Duration.zero;
    final d = p.state.duration;
    if (d > Duration.zero && t > d) t = d;
    p.seek(t);
    setState(() {
      _seekFb = sec < 0 ? '- 10 s' : '+ 10 s';
      _seekLeft = sec < 0;
    });
    _fbT?.cancel();
    _fbT = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekFb = null);
    });
  }

  void _showHud(IconData icon, String text) {
    setState(() {
      _hudIcon = icon;
      _hud = text;
    });
    _hudT?.cancel();
    _hudT = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _hud = null);
    });
  }

  void _flashUnlock() {
    setState(() => _showUnlock = true);
    _unlockT?.cancel();
    _unlockT = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showUnlock = false);
    });
  }

  void _lock() {
    setState(() {
      _locked = true;
      _controls = false;
    });
  }

  void _unlock() {
    setState(() {
      _locked = false;
      _showUnlock = false;
      _controls = true;
    });
    _armHide();
  }

  void _cycleFit() {
    setState(() {
      if (_fit == BoxFit.contain) {
        _fit = BoxFit.cover;
        _hudIcon = Icons.aspect_ratio_rounded;
        _hud = 'Fill screen';
      } else if (_fit == BoxFit.cover) {
        _fit = BoxFit.fill;
        _hudIcon = Icons.aspect_ratio_rounded;
        _hud = 'Stretch';
      } else {
        _fit = BoxFit.contain;
        _hudIcon = Icons.aspect_ratio_rounded;
        _hud = 'Fit';
      }
    });
    _hudT?.cancel();
    _hudT = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _hud = null);
    });
  }

  void _setSleep(int m) {
    _sleepT?.cancel();
    setState(() => _sleepMin = m);
    if (m > 0) {
      _sleepT = Timer(Duration(minutes: m), () {
        p.pause();
        if (mounted) setState(() => _sleepMin = 0);
      });
      _showHud(Icons.bedtime_rounded, 'Sleep in $m min');
    } else {
      _showHud(Icons.bedtime_off_rounded, 'Sleep timer off');
    }
  }

  Future<void> _speedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg2,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Playback speed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0])
                ListTile(
                  dense: true,
                  title: Text('${s}x'),
                  trailing: s == _speed ? const Icon(Icons.check_rounded, color: C.blue2) : null,
                  onTap: () {
                    setState(() => _speed = s);
                    p.setRate(s);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sleepSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg2,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Sleep timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              for (final m in const [0, 15, 30, 45, 60, 90])
                ListTile(
                  dense: true,
                  title: Text(m == 0 ? 'Off' : '$m minutes'),
                  trailing: m == _sleepMin ? const Icon(Icons.check_rounded, color: C.blue2) : null,
                  onTap: () {
                    _setSleep(m);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) {
      p.setVolume(0);
      _showHud(Icons.volume_off_rounded, 'Muted');
    } else {
      p.setVolume(_vol > 0 ? _vol : 100.0);
      _showHud(Icons.volume_up_rounded, '${(_vol > 0 ? _vol : 100.0).round()}%');
    }
  }

  Future<void> _queueSheet() async {
    final list = handler.entries;
    final cur = p.state.playlist.index;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg2,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: list.length,
          itemBuilder: (c, i) => ListTile(
            dense: true,
            selected: i == cur,
            selectedColor: C.blue2,
            leading: Text('${i + 1}'),
            title: Text(
              cleanTitle(list[i].title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.pop(ctx);
              p.jump(i);
            },
          ),
        ),
      ),
    );
  }

  Widget _gestureLayer() {
    if (_locked) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _flashUnlock,
        onDoubleTap: _flashUnlock,
        onVerticalDragStart: (_) => _flashUnlock(),
        onHorizontalDragStart: (_) => _flashUnlock(),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onDoubleTapDown: (d) => _dtPos = d.localPosition,
          onDoubleTap: () {
            final x = _dtPos.dx;
            if (x < w * 0.4) {
              _skip(-10);
            } else if (x > w * 0.6) {
              _skip(10);
            } else {
              p.playOrPause();
            }
          },
          onLongPressStart: (_) {
            p.setRate(2.0);
            setState(() => _boost = true);
          },
          onLongPressEnd: (_) {
            p.setRate(_speed);
            setState(() => _boost = false);
          },
          onLongPressCancel: () {
            if (_boost) {
              p.setRate(_speed);
              setState(() => _boost = false);
            }
          },
          onVerticalDragUpdate: (d) {
            final left = d.localPosition.dx < w / 2;
            final delta = -d.delta.dy / (h * 0.6);
            if (left) {
              _bright = (_bright + delta).clamp(0.02, 1.0).toDouble();
              Bright.set(_bright);
              _showHud(Icons.brightness_6_rounded, '${(_bright * 100).round()}%');
            } else {
              _vol = (_vol + delta * 200).clamp(0.0, 200.0).toDouble();
              p.setVolume(_vol);
              _showHud(
                _vol == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                '${_vol.round()}%',
              );
            }
          },
          onHorizontalDragStart: (_) => _dragTarget = p.state.position,
          onHorizontalDragUpdate: (d) {
            final cur = _dragTarget;
            if (cur == null) return;
            var t = cur + Duration(milliseconds: (d.delta.dx * 150).round());
            final dur = p.state.duration;
            if (t < Duration.zero) t = Duration.zero;
            if (dur > Duration.zero && t > dur) t = dur;
            _dragTarget = t;
            _showHud(Icons.swap_horiz_rounded, fmtDur(t));
          },
          onHorizontalDragEnd: (_) {
            final t = _dragTarget;
            if (t != null) p.seek(t);
            _dragTarget = null;
          },
        );
      },
    );
  }

  Widget _topBar() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: AnimatedOpacity(
        opacity: _controls ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controls,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xCC000000), Color(0x00000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Image.asset('assets/images/logo.png', height: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<MediaEntry?>(
                    valueListenable: handler.current,
                    builder: (c, e, _) => Text(
                      e == null ? '' : cleanTitle(e.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Audio only',
                  icon: const Icon(Icons.headphones_rounded, size: 28),
                  onPressed: () async {
                    await handler.setAudioOnly(true);
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
                IconButton(
                  tooltip: 'Playlist',
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 28),
                  onPressed: _queueSheet,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'sleep') {
                      await _sleepSheet();
                    } else if (v == 'info') {
                      final e = handler.current.value;
                      if (e != null) await showMediaInfo(context, e);
                    } else if (v == 'bg') {
                      await Store.setBg(!_bg);
                      if (mounted) setState(() => _bg = !_bg);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'sleep',
                      child: Text(_sleepMin == 0 ? 'Sleep timer' : 'Sleep timer ($_sleepMin min)'),
                    ),
                    const PopupMenuItem<String>(value: 'info', child: Text('Info')),
                    PopupMenuItem<String>(
                      value: 'bg',
                      child: Text(_bg ? 'Background play: ON' : 'Background play: OFF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sideButtons() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _controls ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controls,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Mute',
                      iconSize: 30,
                      icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                      onPressed: _toggleMute,
                    ),
                    const SizedBox(height: 18),
                    IconButton(
                      tooltip: 'Lock',
                      iconSize: 30,
                      icon: const Icon(Icons.lock_outline_rounded),
                      onPressed: _lock,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Rotate',
                      iconSize: 30,
                      icon: const Icon(Icons.screen_rotation_rounded),
                      onPressed: _rotate,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _controls ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controls,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x00000000), Color(0xDD000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration>(
                  stream: p.stream.position,
                  initialData: p.state.position,
                  builder: (c, s) {
                    final pos = s.data ?? Duration.zero;
                    final dur = p.state.duration;
                    final max = dur.inMilliseconds.toDouble();
                    final cur = _scrub ?? pos.inMilliseconds.toDouble();
                    return Row(
                      children: [
                        Text(fmtDur(Duration(milliseconds: cur.round())),
                            style: const TextStyle(fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: max > 0 ? cur.clamp(0.0, max).toDouble() : 0.0,
                            min: 0,
                            max: max > 0 ? max : 1,
                            onChangeStart: (v) => setState(() => _scrub = v),
                            onChanged: (v) => setState(() => _scrub = v),
                            onChangeEnd: (v) {
                              p.seek(Duration(milliseconds: v.round()));
                              setState(() => _scrub = null);
                              _armHide();
                            },
                          ),
                        ),
                        Text(fmtDur(dur), style: const TextStyle(fontSize: 13)),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    StreamBuilder<bool>(
                      stream: p.stream.playing,
                      initialData: p.state.playing,
                      builder: (c, s) => GestureDetector(
                        onTap: () {
                          p.playOrPause();
                          _armHide();
                        },
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            (s.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 22),
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: () => handler.skipToPrevious(),
                    ),
                    IconButton(
                      tooltip: '-10s',
                      iconSize: 30,
                      icon: const Icon(Icons.replay_10_rounded),
                      onPressed: () => _skip(-10),
                    ),
                    IconButton(
                      tooltip: '+10s',
                      iconSize: 30,
                      icon: const Icon(Icons.forward_10_rounded),
                      onPressed: () => _skip(10),
                    ),
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () => handler.skipToNext(),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _speedSheet,
                      child: Text(
                        _speed == 1.0 ? 'Speed' : '${_speed}x',
                        style: const TextStyle(color: Colors.white, fontSize: 17),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Screen fit',
                      iconSize: 30,
                      icon: const Icon(Icons.aspect_ratio_rounded),
                      onPressed: _cycleFit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _audioBackdrop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(colors: [Color(0xFF12358A), C.bg], radius: 0.9),
      ),
      child: const Center(
        child: Icon(Icons.headphones_rounded, size: 90, color: C.blue2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_locked,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<bool>(
          valueListenable: handler.audioOnly,
          builder: (context, audioOnly, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: audioOnly
                      ? _audioBackdrop()
                      : Video(
                          controller: handler.video,
                          controls: NoVideoControls,
                          fit: _fit,
                          fill: Colors.black,
                          pauseUponEnteringBackgroundMode: !_bg,
                        ),
                ),
                Positioned.fill(child: _gestureLayer()),
                if (!_locked) _sideButtons(),
                if (!_locked) _topBar(),
                if (!_locked) _bottomBar(),
                if (_boost)
                  Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xCC2C7BFF),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text('2x  >>', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                if (_seekFb != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: _seekLeft ? 40 : null,
                    right: _seekLeft ? null : 40,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xCC2C7BFF),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _seekFb!,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_hud != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_hudIcon, size: 28),
                              const SizedBox(width: 10),
                              Text(_hud!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_locked)
                  Positioned(
                    left: 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _showUnlock ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !_showUnlock,
                          child: Material(
                            color: C.blue,
                            shape: const CircleBorder(),
                            child: IconButton(
                              iconSize: 30,
                              icon: const Icon(Icons.lock_open_rounded),
                              onPressed: _unlock,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
