import 'package:hive/hive.dart';

class LikeStore {
  final String threadId;
  LikeStore(this.threadId);

  Box<dynamic>? _box;
  String get _boxName => 'likes_$threadId';
  static const _key = 'liked_keys'; // store as List<String>

  Future<void> open() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Future<Set<String>> load() async {
    await open();
    final list = (_box!.get(_key) as List?)?.cast<String>() ?? const <String>[];
    return list.toSet();
  }

  Future<void> save(Set<String> liked) async {
    await open();
    await _box!.put(_key, liked.toList(growable: false));
  }

  Future<void> toggle(String k) async {
    final cur = await load();
    if (cur.contains(k)) {
      cur.remove(k);
    } else {
      cur.add(k);
    }
    await save(cur);
  }
}
