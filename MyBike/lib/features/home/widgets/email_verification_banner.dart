import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/colors.dart';
import '../../../services/auth_service.dart';

/// Non-blocking banner that nudges a signed-in user with an unverified
/// email to verify. User can keep using the app. Shown at the top of the
/// HomeScreen; collapses to zero height once the email is verified or the
/// user dismisses it for this session.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _dismissedForSession = false;
  bool _resending = false;

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resending = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerificationIfNeeded();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Verification email sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't send verification email. Try again later."),
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null || user.emailVerified || _dismissedForSession) {
      return const SizedBox.shrink();
    }
    // Google-signed-in users show up as emailVerified = true automatically,
    // so this effectively only addresses the email/password cohort.
    return Material(
      color: AppColors.warningAmber.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined,
                color: AppColors.warningAmber, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Verify your email to secure your account.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(
                _resending ? 'Sending…' : 'Resend',
                style: const TextStyle(color: AppColors.primaryOrange),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, size: 18, color: Colors.white),
              onPressed: () => setState(() => _dismissedForSession = true),
            ),
          ],
        ),
      ),
    );
  }
}
