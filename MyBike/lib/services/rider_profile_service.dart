import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/rider_profile.dart';

/// Persists rider profile per Firebase account at `users/{uid}/profile/rider`.
class RiderProfileService {
  RiderProfileService({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _fs
      .collection('users')
      .doc(uid)
      .collection('profile')
      .doc('rider');

  Stream<RiderProfile?> watch(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return RiderProfile.fromMap(snap.data()!);
    });
  }

  Future<RiderProfile?> get(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return RiderProfile.fromMap(snap.data()!);
  }

  /// Writes [profile] to Firestore. Fields set on [profile] are written as
  /// their value; optional fields that are explicitly null are written as
  /// `FieldValue.delete()` so that clearing a field in the UI actually
  /// removes it on the server (instead of being silently ignored by the
  /// merge, which was the pre-existing bug).
  Future<void> save(String uid, RiderProfile profile) {
    final map = profile.toMap();
    final payload = <String, dynamic>{
      ...map,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Optional fields that may legitimately be cleared.
    for (final field in const [
      'phone',
      'profession',
      'pincode',
      'state',
      'city',
    ]) {
      if (!map.containsKey(field)) {
        payload[field] = FieldValue.delete();
      }
    }
    return _doc(uid).set(payload, SetOptions(merge: true));
  }
}

final riderProfileServiceProvider =
    Provider<RiderProfileService>((ref) => RiderProfileService());
