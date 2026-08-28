import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mybike/features/auth/sign_in_screen.dart';
import 'package:mybike/services/auth_service.dart';

// A mock auth service that implements the abstract interface.
// Because it does not extend concrete FirebaseAuthService, it does not attempt 
// to initialize Firebase Core, which is required for widget tests.
class FakeAuthService implements AuthService {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> registerWithEmail(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  Future<UserCredential> signInWithGoogle() async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('SignInScreen builds correctly and transitions to email form state', (WidgetTester tester) async {
    // Render the SignInScreen inside a ProviderScope with our FakeAuthService.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(FakeAuthService()),
        ],
        child: const MaterialApp(
          home: SignInScreen(),
        ),
      ),
    );

    // Verify visual branding elements in the initial social-login state.
    expect(find.text('Z-Vandi'), findsOneWidget);
    expect(find.text("Sign in to access your machine's telemetry."), findsOneWidget);
    expect(find.byKey(const ValueKey('continue_google_button')), findsOneWidget);
    
    final continueEmailButton = find.byKey(const ValueKey('continue_email_button'));
    expect(continueEmailButton, findsOneWidget);

    // Perform tap to transition to email form
    await tester.tap(continueEmailButton);
    await tester.pumpAndSettle();

    // Verify that the email/password input form state is now active.
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
