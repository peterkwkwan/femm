import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';
import 'google_g_mark.dart';
import 'welcome_wave_clipper.dart';

const String kWelcomeHelperCopy =
    'After your health check or labs, we route you toward recovery care that fits.';

/// Brand-Forward femm login: wavy photo (~55%) + cream brand panel + Google CTA.
class BrandForwardWelcome extends StatelessWidget {
  const BrandForwardWelcome({
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: PetalSoft.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: PetalSoft.surface),
          const _WaveAtmosphere(),
          CustomPaint(
            painter: const WelcomeWaveEdgePainter(color: PetalSoft.surface),
            child: const SizedBox.expand(),
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
                  'femm',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: PetalSoft.displayFontFamily,
                    color: PetalSoft.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 1,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: null,
                    color: PetalSoft.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 28,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
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
                const SizedBox(height: 18),
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

class _WaveAtmosphere extends StatelessWidget {
  const _WaveAtmosphere();

  /// Portrait sunset yoga silhouette for Brand-Forward login.
  static const String assetPath = 'assets/images/login-yoga-silhouette.png';

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const WelcomeWaveClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: PetalSoft.bg),
          // Portrait asset under the wave: cover + slight downward bias so the
          // full dancer silhouette and beach reflection read clearly (not sky-only).
          const Positioned.fill(
            child: Image(
              image: AssetImage(assetPath),
              fit: BoxFit.cover,
              alignment: Alignment(0, 0.12),
              filterQuality: FilterQuality.medium,
            ),
          ),
          ColoredBox(
            color: PetalSoft.accent.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}
