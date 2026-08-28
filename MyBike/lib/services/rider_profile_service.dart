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

  Future<void> save(String uid, RiderProfile profile) {
    return _doc(uid).set(
      {
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

final riderProfileServiceProvider =
    Provider<RiderProfileService>((ref) => RiderProfileService());
