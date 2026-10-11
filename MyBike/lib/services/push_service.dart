import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Server-sent push on top of the local reminder notifications.
///
/// Scope of this file is intentionally narrow: register for FCM, store the
/// device token under `users/{uid}/devices/{token}`, and emit a stream of
/// taps so the UI can drive navigation (e.g. switch to the Reminders tab).
/// Actual push *sending* is out of scope for the client — a Cloud Function
/// or admin backend produces the messages.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  FirebaseMessaging get _fm => FirebaseMessaging.instance;
  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _started = false;
  String? _uid;

  /// Call after sign-in. Idempotent for the same uid.
  Future<void> start(String uid) async {
    if (_started && _uid == uid) return;
    await stop();
    _uid = uid;
    _started = true;

    if (kIsWeb) return; // FCM web needs a VAPID key we don't ship yet.

    try {
      await _fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await _fm.getToken();
      if (token != null && _uid != null) {
        await _writeToken(_uid!, token);
      }
      _tokenRefreshSub = _fm.onTokenRefresh.listen((t) {
        if (_uid != null) _writeToken(_uid!, t);
      });
      // Foreground: FirebaseMessaging doesn't auto-show. We rely on
      // flutter_local_notifications already firing for maintenance due dates,
      // so a redundant native toast here would double-notify the user.
      // Instead, we just record it for Crashlytics-shaped diagnostics.
      _foregroundSub = FirebaseMessaging.onMessage.listen((_) {});
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((_) {
        // Switch to the Reminders tab when a push is tapped.
        _ref.read(homeTabIndexProvider.notifier).state = 2;
      });
    } catch (e, s) {
      FirebaseCrashlytics.instance
          .recordError(e, s, reason: 'PushService.start', fatal: false);
    }
  }

  Future<void> _writeToken(String uid, String token) async {
    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(token)
          .set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'PushService._writeToken',
        fatal: false,
      );
    }
  }

  /// Call on sign-out or account deletion.
  Future<void> stop() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _openedSub?.cancel();
    _openedSub = null;
    _started = false;
    _uid = null;
  }
}

final pushServiceProvider =
    Provider<PushService>((ref) => PushService(ref));
