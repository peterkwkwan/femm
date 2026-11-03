import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';
import 'calmness_mark.dart';
import 'dawn_mist_atmosphere.dart';
import 'google_g_mark.dart';

const String kWelcomeHelperCopy =
    'After your health check or labs, we route you toward recovery care that fits.';

/// Dawn Mist login — centered Calmness + Cormorant Soft femm, mist wash,
/// bottom Welcome + full-width soft Continue with Google.
///
/// No app bar / navbar. Layout from centered-login Dawn Mist; wordmark from
/// Cormorant Soft (italic, majestic). Inter Air for Welcome / helper / CTA.
class DawnMistWelcome extends StatelessWidget {
  const DawnMistWelcome({
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

  /// Quieter centered mark (Dawn Mist mockup markSize 78).
  static const double centeredMarkSize = 78;

  /// Cormorant Soft majestic wordmark (canvas wordSize 44).
  static const double majesticWordSize = PetalSoft.majesticWordmarkSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: PetalSoft.mist,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DawnMistAtmosphere(),
          // Centered brand — middle field, lifted slightly above true center
          // so it clears the bottom Welcome stack (Mentra geometry).
          const Align(
            alignment: Alignment(0, -0.12),
            child: _CenteredBrand(
              markSize: centeredMarkSize,
              wordSize: majesticWordSize,
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32 + bottomInset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome',
                  textAlign: TextAlign.center,
                  style: PetalSoft.welcomeTextStyle(),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    kWelcomeHelperCopy,
                    textAlign: TextAlign.center,
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
                    textAlign: TextAlign.center,
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _SoftGoogleCta(
                  busy: busy,
                  onPressed: busy ? null : onGoogleSignIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calmness bloom stacked above italic Cormorant Soft femm — centered hero.
class _CenteredBrand extends StatelessWidget {
  const _CenteredBrand({
    required this.markSize,
    required this.wordSize,
  });

  final double markSize;
  final double wordSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CalmnessMark(size: markSize),
        const SizedBox(height: 14),
        Text(
          'femm',
          style: PetalSoft.majesticWordmarkTextStyle(size: wordSize),
        ),
      ],
    );
  }
}

/// Dawn Mist full-width soft Google control (cream + blush border).
class _SoftGoogleCta extends StatelessWidget {
  const _SoftGoogleCta({
    required this.busy,
    required this.onPressed,
  });

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: PetalSoft.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PetalSoft.blush),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Center(
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PetalSoft.ink,
                    ),
                  )
                : Opacity(
                    opacity: enabled ? 1 : 0.45,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GoogleGMark(size: 18),
                        SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontFamily: PetalSoft.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PetalSoft.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
