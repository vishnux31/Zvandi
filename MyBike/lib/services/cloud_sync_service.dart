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

  /// Pushes local docs to Firestore only when they are new or newer than the
  /// remote copy. Prevents the "last device signs in" overwrite footgun where
  /// an unconditional batch set stomps the authoritative server data.
  Future<void> _pushAllLocal() async {
    const chunkSize = 400; // Firestore batches cap at 500.
    for (final name in _collections.keys) {
      final box = Hive.box<String>(name);
      if (box.isEmpty) continue;

      // Fetch the remote view once per collection; cheap on small datasets
      // (the only ones we have today) and avoids N round-trips.
      final remoteSnap = await _col(name).get();
      final remoteUpdatedAt = <String, DateTime?>{};
      for (final doc in remoteSnap.docs) {
        final data = doc.data();
        remoteUpdatedAt[doc.id] = _parseUpdatedAt(data['updatedAt']);
      }

      final pending = <MapEntry<String, Map<String, dynamic>>>[];
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null) continue;
        final data = json.decode(raw) as Map<String, dynamic>;
        final remote = remoteUpdatedAt[key as String];
        if (remote == null) {
          pending.add(MapEntry(key, data));
          continue;
        }
        final local = _parseUpdatedAt(data['updatedAt']);
        if (local != null && local.isAfter(remote)) {
          pending.add(MapEntry(key, data));
        }
      }

      for (var i = 0; i < pending.length; i += chunkSize) {
        final batch = _fs.batch();
        final end = (i + chunkSize).clamp(0, pending.length);
        for (final entry in pending.sublist(i, end)) {
          batch.set(_col(name).doc(entry.key), entry.value);
        }
        await batch.commit();
      }
    }
  }

  DateTime? _parseUpdatedAt(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is Timestamp) return raw.toDate();
    return null;
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

  /// Deletes every document under `users/{uid}` on Firestore. Used by the
  /// "Delete account" flow before `FirebaseAuth.currentUser.delete()`.
  /// Must be called while the user is still authenticated.
  Future<void> deleteRemoteUserData() async {
    final uid = _uid;
    if (uid == null) return;
    final fs = _fs;

    for (final name in _collections.keys) {
      final snap = await fs.collection('users').doc(uid).collection(name).get();
      // Firestore batches cap at 500 writes; chunk conservatively.
      const chunkSize = 400;
      for (var i = 0; i < snap.docs.length; i += chunkSize) {
        final batch = fs.batch();
        final end = (i + chunkSize).clamp(0, snap.docs.length);
        for (final doc in snap.docs.sublist(i, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // Rider profile sub-collection.
    final profileSnap =
        await fs.collection('users').doc(uid).collection('profile').get();
    for (final doc in profileSnap.docs) {
      await doc.reference.delete();
    }
    // Devices sub-collection (for FCM tokens; may not exist yet).
    final deviceSnap =
        await fs.collection('users').doc(uid).collection('devices').get();
    for (final doc in deviceSnap.docs) {
      await doc.reference.delete();
    }
  }
}

final cloudSyncProvider =
    Provider<CloudSyncService>((ref) => CloudSyncService(ref));
