import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'models.dart';
import 'store.dart';

late NPlayHandler handler;

/// One media_kit player for everything (video + music) and an
/// audio_service handler so playback and notification controls keep
/// working when the app is in the background.
class NPlayHandler extends BaseAudioHandler with SeekHandler {
  final Player player = Player();
  late final VideoController video = VideoController(player);

  List<MediaEntry> entries = [];
  final ValueNotifier<MediaEntry?> current = ValueNotifier<MediaEntry?>(null);
  final ValueNotifier<bool> audioOnly = ValueNotifier<bool>(false);
  int _lastPush = 0;

  NPlayHandler() {
    _initVolume();
    player.stream.playing.listen((_) => _push());
    player.stream.rate.listen((_) => _push());
    player.stream.playlist.listen((pl) => _onIndex(pl.index));
    player.stream.position.listen((_) {
      final n = DateTime.now().millisecondsSinceEpoch;
      if (n - _lastPush > 4000) _push();
    });
  }

  /// Allow volume up to 200% (double) and start at normal 100%.
  Future<void> _initVolume() async {
    try {
      await (player.platform as dynamic).setProperty('volume-max', '200');
    } catch (_) {}
    try {
      await player.setVolume(100.0);
    } catch (_) {}
  }

  void _onIndex(int i) {
    if (i < 0 || i >= entries.length) return;
    final e = entries[i];
    current.value = e;
    Store.addHistory(e.id);
    mediaItem.add(MediaItem(
      id: e.id,
      title: cleanTitle(e.title),
      album: 'NPlay',
      artist: e.folder,
      duration: e.durationSec > 0 ? Duration(seconds: e.durationSec) : null,
    ));
    if (audioOnly.value) _applyTrack();
    _push();
  }

  Future<void> _applyTrack() async {
    await player.setVideoTrack(
      audioOnly.value ? VideoTrack.no() : VideoTrack.auto(),
    );
  }

  Future<void> setAudioOnly(bool v) async {
    audioOnly.value = v;
    await _applyTrack();
  }

  Future<void> openQueue(List<MediaEntry> list, int index) async {
    final paths = await Future.wait(list.map((e) => e.resolvePath()));
    final medias = <Media>[];
    final ok = <MediaEntry>[];
    int start = 0;
    for (int i = 0; i < list.length; i++) {
      final p = paths[i];
      if (p == null) continue;
      if (i == index) start = ok.length;
      medias.add(Media(p));
      ok.add(list[i]);
    }
    if (ok.isEmpty) return;
    entries = ok;
    await player.open(Playlist(medias, index: start), play: true);
    _onIndex(start);
    final e = ok[start];
    if (e.isVideo) {
      // fire and forget: resume where the user stopped
      _resume(e);
    }
  }

  Future<void> _resume(MediaEntry e) async {
    // Imported lazily to keep this file independent of Store ordering.
    final saved = _savedPos?.call(e.id) ?? 0;
    if (saved < 3000) return;
    final target = Duration(milliseconds: saved);
    await Future.delayed(const Duration(milliseconds: 300));
    for (int i = 0; i < 40; i++) {
      if (current.value?.id != e.id) return;
      if (player.state.duration > target + const Duration(seconds: 5)) {
        await player.seek(target);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Set from main.dart (reads saved positions).
  int Function(String id)? _savedPos;
  void setSavedPosReader(int Function(String id) f) {
    _savedPos = f;
  }

  void _push() {
    _lastPush = DateTime.now().millisecondsSinceEpoch;
    final playing = player.state.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: entries.isEmpty
          ? AudioProcessingState.idle
          : AudioProcessingState.ready,
      playing: playing,
      updatePosition: player.state.position,
      speed: player.state.rate,
      queueIndex: player.state.playlist.index,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.next();

  @override
  Future<void> skipToPrevious() => player.previous();

  @override
  Future<void> stop() async {
    await player.pause();
  }
}
