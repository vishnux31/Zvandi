import 'dart:convert';

import 'package:hive/hive.dart';

/// Generic CRUD repository backed by a Hive box of JSON strings.
///
/// This is intentionally interface-light so a cloud-backed implementation
/// (e.g. Firestore) can later expose the same surface.
abstract class BaseRepository<T> {
  BaseRepository(this._box);

  final Box<String> _box;

  String idOf(T entity);
  Map<String, dynamic> toMap(T entity);
  T fromMap(Map<String, dynamic> map);

  List<T> getAll() => _box.values
      .map((s) => fromMap(json.decode(s) as Map<String, dynamic>))
      .toList();

  T? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return fromMap(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> put(T entity) =>
      _box.put(idOf(entity), json.encode(toMap(entity)));

  Future<void> delete(String id) => _box.delete(id);

  Future<void> deleteWhere(bool Function(T) test) async {
    final toRemove = <String>[];
    for (final raw in _box.toMap().entries) {
      final entity = fromMap(json.decode(raw.value) as Map<String, dynamic>);
      if (test(entity)) toRemove.add(raw.key as String);
    }
    await _box.deleteAll(toRemove);
  }
}
