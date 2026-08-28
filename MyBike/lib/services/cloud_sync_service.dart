import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/local_store.dart';
import '../providers/app_providers.dart';

/// Mirrors the local Hive store to Firestore under `users/{uid}/...`.
///
/// Design: Hive stays the synchronous source of truth for the UI (offline
/// first). Every local write is pushed to Firestore, and a realtime listener
/// writes remote changes back into Hive so multiple devices stay in sync.
class CloudSyncService {
  CloudSyncService(this._ref);

  final Ref _ref;
  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  String? _uid;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Hive box name -> notifier reload callback.
  Map<String, void Function()> get _collections => {
        Boxes.bikes: () => _ref.read(bikesProvider.notifier).reload(),
        Boxes.items: () => _ref.read(itemsProvider.notifier).reload(),
        Boxes.records: () => _ref.read(recordsProvider.notifier).reload(),
        Boxes.fuel: () => _ref.read(fuelProvider.notifier).reload(),
      };

  bool get isActive => _uid != null;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _fs.collection('users').doc(_uid).collection(name);

  /// Begin syncing for [uid]: upload local-only data, then attach listeners.
  Future<void> start(String uid) async {
    if (_uid == uid) return;
    await stop(keepLocal: true);
    _uid = uid;
    await _pushAllLocal();
    _collections.forEach(_listen);
  }

  void _listen(String name, void Function() reload) {
    final box = Hive.box<String>(name);
    final sub = _col(name).snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final id = change.doc.id;
        if (change.type == DocumentChangeType.removed) {
          box.delete(id);
        } else {
          box.put(id, json.encode(change.doc.data()));
        }
      }
      reload();
    });
    _subs.add(sub);
  }

  Future<void> _pushAllLocal() async {
    for (final name in _collections.keys) {
      final box = Hive.box<String>(name);
      if (box.isEmpty) continue;
      final batch = _fs.batch();
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null) continue;
        final data = json.decode(raw) as Map<String, dynamic>;
        batch.set(_col(name).doc(key as String), data);
      }
      await batch.commit();
    }
  }

  /// Push a single document upsert (no-op when signed out).
  Future<void> push(String collection, String id, Map<String, dynamic> data) {
    if (_uid == null) return Future.value();
    return _col(collection).doc(id).set(data);
  }

  /// Delete a single document (no-op when signed out).
  Future<void> remove(String collection, String id) {
    if (_uid == null) return Future.value();
    return _col(collection).doc(id).delete();
  }

  /// Stop syncing. When [keepLocal] is false, clears local data (sign-out).
  Future<void> stop({bool keepLocal = false}) async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _uid = null;
    if (!keepLocal) {
      final reloads = _collections.values.toList();
      for (final name in _collections.keys) {
        await Hive.box<String>(name).clear();
      }
      for (final reload in reloads) {
        reload();
      }
    }
  }
}

final cloudSyncProvider =
    Provider<CloudSyncService>((ref) => CloudSyncService(ref));
