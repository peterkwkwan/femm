import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';
import 'deep_accent_dusk_hills.dart';
import 'google_g_mark.dart';

const String kWelcomeHelperCopy =
    'After your health check or labs, we route you toward recovery care that fits.';

/// Deep Accent Dusk login — animated flat hills, ink wordmark, Google CTA.
class DeepAccentDuskWelcome extends StatelessWidget {
  const DeepAccentDuskWelcome({
    super.key,
    required this.busy,
    required this.error,
    required this.usingPlaceholders,
    required this.onGoogleSignIn,
  });

  final bool busy;
  final String? error;
  final bool usingPlaceholders;
  final VoidCallback onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hillsHeight = size.height * 0.58;

    return Scaffold(
      backgroundColor: PetalSoft.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: PetalSoft.surface),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: hillsHeight,
            child: const DeepAccentDuskHills(),
          ),
          Positioned(
            top: topInset + 12,
            left: 22,
            child: const Text(
              'femm',
              style: TextStyle(
                // Solid ink — do not inherit theme/accent tint via copyWith.
                color: Color(0xFF2A1F1C),
                fontWeight: FontWeight.w700,
                fontSize: 24,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28 + bottomInset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: PetalSoft.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    height: 1.1,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    kWelcomeHelperCopy,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: PetalSoft.muted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
                if (usingPlaceholders) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Supabase placeholders active — set env defines to sign in.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PetalSoft.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PetalSoft.ink,
                    foregroundColor: PetalSoft.surface,
                    disabledBackgroundColor:
                        PetalSoft.ink.withValues(alpha: 0.45),
                    disabledForegroundColor: PetalSoft.surface,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: busy ? null : onGoogleSignIn,
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PetalSoft.surface,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GoogleGMark(size: 16),
                            SizedBox(width: 10),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
