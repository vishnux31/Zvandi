import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web OAuth client id used by google_sign_in on Android to obtain an idToken
/// whose audience Firebase Auth will accept. This is the auto-created
/// "Web client" (client_type 3) for the mybike-865b8 project.
const String kGoogleServerClientId =
    '901311202194-k79c48uqigeanom0vh7pr2msg87c8suv.apps.googleusercontent.com';

/// Abstract interface for AuthService to support easy mocking in testing.
abstract class AuthService {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<UserCredential> registerWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> updateDisplayName(String name);
  Future<UserCredential> signInWithGoogle();
  Future<void> signOut();
}

/// Firebase implementation of AuthService.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();
  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  @override
  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name.trim());
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Web uses a popup-based flow via Firebase directly.
      return _auth.signInWithPopup(GoogleAuthProvider());
    }
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(serverClientId: kGoogleServerClientId);
      _googleInitialized = true;
    }
    final account = await google.authenticate();
    final auth = account.authentication;
    final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore: user may not have signed in with Google.
      }
    }
    await _auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());

/// Emits the current Firebase user (null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});
