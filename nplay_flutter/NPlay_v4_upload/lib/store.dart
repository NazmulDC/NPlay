import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Store {
  static late SharedPreferences p;

  static Future<void> init() async {
    p = await SharedPreferences.getInstance();
  }

  static int pos(String id) => p.getInt('pos:$id') ?? 0;

  static Future<void> setPos(String id, int ms) async {
    await p.setInt('pos:$id', ms);
  }

  static bool get bg => p.getBool('bg') ?? true;

  static Future<void> setBg(bool v) async {
    await p.setBool('bg', v);
  }

  /// Recently played ids, newest first.
  static List<String> get history => List<String>.from(p.getStringList('hist') ?? <String>[]);

  static Future<void> addHistory(String id) async {
    final l = history;
    l.remove(id);
    l.insert(0, id);
    if (l.length > 150) l.removeRange(150, l.length);
    await p.setStringList('hist', l);
  }

  static Future<void> clearHistory() async {
    await p.setStringList('hist', <String>[]);
  }

  // ---------- playlists ----------
  static Map<String, List<String>> get playlists {
    final raw = p.getString('playlists');
    if (raw == null) return <String, List<String>>{};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, List<String>.from(v as List)));
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  static Future<void> _savePl(Map<String, List<String>> m) async {
    await p.setString('playlists', jsonEncode(m));
  }

  static Future<void> createPlaylist(String name) async {
    final m = playlists;
    m.putIfAbsent(name, () => <String>[]);
    await _savePl(m);
  }

  static Future<void> addToPlaylist(String name, String id) async {
    final m = playlists;
    final l = m.putIfAbsent(name, () => <String>[]);
    if (!l.contains(id)) l.add(id);
    await _savePl(m);
  }

  static Future<void> removeFromPlaylist(String name, String id) async {
    final m = playlists;
    m[name]?.remove(id);
    await _savePl(m);
  }

  static Future<void> deletePlaylist(String name) async {
    final m = playlists;
    m.remove(name);
    await _savePl(m);
  }
}
