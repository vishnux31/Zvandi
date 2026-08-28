import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/colors.dart';
import '../../services/auth_service.dart';

// Styling colors matching Compose
const Color _darkBlack = AppColors.darkBlack;
const Color _accentCopper = AppColors.accentCopper;
const Color _onPrimaryText = AppColors.onPrimaryText;
const Color _subtextZinc = AppColors.subtextZinc;
const Color _surfaceLight = AppColors.surfaceLight;
const Color _surfacePanel = AppColors.surfacePanel;
const Color _primaryOrange = AppColors.primaryOrange;
const Color _outlineGray = AppColors.outlineGray;
const Color _dangerRed = AppColors.dangerRed;

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _error;
  bool _showEmailForm = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authServiceProvider);
    await _run(() async {
      if (_isRegister) {
        await auth.registerWithEmail(_email.text, _password.text);
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
    });
  }

  Future<void> _google() async {
    final auth = ref.read(authServiceProvider);
    await _run(() => auth.signInWithGoogle());
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first, then tap reset.');
      return;
    }
    final auth = ref.read(authServiceProvider);
    await _run(() async {
      await auth.sendPasswordReset(_email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBlack,
      body: Stack(
        children: [
          // Futuristic cyber speed line background glow
          Positioned(
            top: -50,
            left: MediaQuery.of(context).size.width / 2 - 175,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _primaryOrange.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surfacePanel,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _outlineGray, width: 1.0),
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: AnimatedCrossFade(
                        crossFadeState: _showEmailForm
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                        firstChild: _buildSocialState(),
                        secondChild: _buildEmailFormState(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Motorcycle Circle Icon
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: _surfaceLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.two_wheeler,
            color: _accentCopper,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        // Heading "Z-Vandi"
        const Text(
          'Z-Vandi',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Tagline
        const Text(
          "Sign in to access your machine's telemetry.",
          style: TextStyle(
            fontSize: 16,
            color: _subtextZinc,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        // Continue with Google Button
        OutlinedButton(
          key: const ValueKey('continue_google_button'),
          onPressed: _busy ? null : _google,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            side: const BorderSide(color: _outlineGray),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.language,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // OR separator
        const Row(
          children: [
            Expanded(child: Divider(color: _outlineGray)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _subtextZinc,
                ),
              ),
            ),
            Expanded(child: Divider(color: _outlineGray)),
          ],
        ),
        const SizedBox(height: 16),
        // Continue with Email Button
        ElevatedButton(
          key: const ValueKey('continue_email_button'),
          onPressed: () => setState(() => _showEmailForm = true),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: _accentCopper,
            foregroundColor: _onPrimaryText,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email,
                color: _onPrimaryText,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Continue with Email',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _onPrimaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Footer agreement terms
        const Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _subtextZinc,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailFormState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _showEmailForm = false;
                        _error = null;
                      }),
            ),
          ],
        ),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: _surfaceLight,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.two_wheeler,
            color: _accentCopper,
            size: 24,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isRegister ? 'Create Account' : 'Sign In',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _isRegister
              ? "Create an account to track your machine's telemetry."
              : "Enter your email and password to sign in.",
          style: const TextStyle(
            fontSize: 14,
            color: _subtextZinc,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: const TextStyle(color: _subtextZinc),
            hintStyle: const TextStyle(color: _subtextZinc),
            filled: true,
            fillColor: _surfaceLight,
            prefixIcon: const Icon(Icons.email_outlined, color: _subtextZinc),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _outlineGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryOrange),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _outlineGray),
            ),
          ),
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return 'Required';
            if (!value.contains('@')) return 'Invalid email';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: _subtextZinc),
            hintStyle: const TextStyle(color: _subtextZinc),
            filled: true,
            fillColor: _surfaceLight,
            prefixIcon: const Icon(Icons.lock_outline, color: _subtextZinc),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _outlineGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryOrange),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _outlineGray),
            ),
          ),
          validator: (v) => (v == null || v.length < 6)
              ? 'At least 6 characters'
              : null,
        ),
        if (!_isRegister)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _forgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(color: _accentCopper),
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _dangerRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dangerRed.withValues(alpha: 0.4), width: 1.0),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: _dangerRed),
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _submitEmail,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: _accentCopper,
            foregroundColor: _onPrimaryText,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  _isRegister ? 'Create Account' : 'Sign In',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _isRegister = !_isRegister;
                    _error = null;
                  }),
          child: Text(
            _isRegister
                ? 'Already have an account? Sign in'
                : "Don't have an account? Create one",
            style: const TextStyle(color: _subtextZinc, fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        // Footer agreement terms
        const Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _subtextZinc,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
