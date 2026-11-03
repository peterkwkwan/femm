import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/petal_soft.dart';
import '../widgets/mark_led_app_bar.dart';
import 'lab_upload_screen.dart';

/// Signed-in home — Next-step hero (Petal Soft).
///
/// Greeting + quiet identity + one next-step card (Upload lab PDF) + thin Path A rail.
class SignedInHome extends StatelessWidget {
  const SignedInHome({
    super.key,
    required this.user,
    required this.busy,
    required this.error,
    required this.onSignOut,
    this.clock = DateTime.now,
  });

  final User user;
  final bool busy;
  final String? error;
  final VoidCallback onSignOut;

  /// Local wall clock; override in tests. Greeting uses [DateTime.toLocal].
  final DateTime Function() clock;

  /// Local-time greeting bands: morning before 12, afternoon before 17, else evening.
  static String greetingFor(DateTime now) {
    final hour = now.toLocal().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String firstNameOf({
    required String? displayName,
    required String? email,
  }) {
    final raw = displayName?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw.split(RegExp(r'\s+')).first;
    }
    final local = email?.split('@').first.trim();
    if (local != null && local.isNotEmpty) {
      return local[0].toUpperCase() + local.substring(1);
    }
    return 'there';
  }

  static String initialOf({
    required String? displayName,
    required String? email,
  }) {
    final first = firstNameOf(displayName: displayName, email: email);
    if (first.isEmpty) return '·';
    return first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final displayName = (meta['full_name'] ?? meta['name'])?.toString();
    final email = user.email;
    final first = firstNameOf(displayName: displayName, email: email);
    final fullName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (email ?? 'Signed in');
    final initial = initialOf(displayName: displayName, email: email);
    final greeting = greetingFor(clock().toLocal());

    return Scaffold(
      backgroundColor: PetalSoft.bg,
      body: SafeArea(
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarkLedTopBar(
              onSignOut: onSignOut,
              signOutBusy: busy,
              avatarInitial: initial,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      greeting.toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: PetalSoft.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$first, start with your labs',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: PetalSoft.displayFontFamily,
                        color: PetalSoft.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _IdentityQuiet(
                      initial: initial,
                      name: fullName,
                      email: email,
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      decoration: BoxDecoration(
                        color: PetalSoft.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PetalSoft.accentSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'YOUR NEXT STEP',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: PetalSoft.accent,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload a lab PDF',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: PetalSoft.displayFontFamily,
                              color: PetalSoft.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Path A begins with labs, then routine, symptoms, '
                            'and a calm match.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: PetalSoft.muted,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LabUploadScreen(),
                                ),
                              );
                            },
                            child: const Text('Upload lab PDF'),
                          ),
                        ],
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 5),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: i < 1
                                    ? PetalSoft.accent
                                    : PetalSoft.accentSoft,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Path A · Labs 1 of 4',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PetalSoft.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityQuiet extends StatelessWidget {
  const _IdentityQuiet({
    required this.initial,
    required this.name,
    required this.email,
  });

  final String initial;
  final String name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: PetalSoft.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFamily: PetalSoft.displayFontFamily,
              color: PetalSoft.ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: PetalSoft.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              if (email != null)
                Text(
                  email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: PetalSoft.muted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
