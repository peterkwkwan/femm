import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';
import 'calmness_mark.dart';

/// Mark-Led Calmness top-nav — larger bloom, quieter Cormorant Soft seasons.
///
/// Locked from Calmness nav mockups. Wordmark reuses Dawn Mist Cormorant Soft
/// italic (quieter nav scale). No path labels in the bar.
class MarkLedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MarkLedAppBar({
    super.key,
    this.automaticallyImplyLeading = true,
    this.onSignOut,
    this.signOutBusy = false,
    this.avatarInitial,
  });

  final bool automaticallyImplyLeading;
  final VoidCallback? onSignOut;
  final bool signOutBusy;

  /// When set with [onSignOut], shows the avatar chip (Mark-Led signed-in).
  final String? avatarInitial;

  static const double toolbarHeight = 64;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: toolbarHeight,
      backgroundColor: PetalSoft.surface,
      foregroundColor: PetalSoft.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: automaticallyImplyLeading,
      titleSpacing: 8,
      title: const MarkLedLockup(),
      actions: [
        if (onSignOut != null) ...[
          TextButton(
            onPressed: signOutBusy ? null : onSignOut,
            style: TextButton.styleFrom(
              foregroundColor: PetalSoft.muted,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Sign out',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (avatarInitial != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(child: MarkLedAvatar(initial: avatarInitial!)),
            ),
          ] else
            const SizedBox(width: 8),
        ],
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: ColoredBox(
          color: PetalSoft.accentSoft,
          child: SizedBox(height: 1, width: double.infinity),
        ),
      ),
    );
  }
}

/// Inline Mark-Led strip for screens that use a custom [SafeArea] body header
/// (login + signed-in home) instead of a Scaffold [appBar].
class MarkLedTopBar extends StatelessWidget {
  const MarkLedTopBar({
    super.key,
    this.onSignOut,
    this.signOutBusy = false,
    this.avatarInitial,
    this.includeBottomBorder = true,
  });

  final VoidCallback? onSignOut;
  final bool signOutBusy;
  final String? avatarInitial;
  final bool includeBottomBorder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PetalSoft.surface,
        border: includeBottomBorder
            ? const Border(
                bottom: BorderSide(color: PetalSoft.accentSoft, width: 1),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 14, 14),
        child: Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: MarkLedLockup(),
              ),
            ),
            if (onSignOut != null) ...[
              TextButton(
                onPressed: signOutBusy ? null : onSignOut,
                style: TextButton.styleFrom(
                  foregroundColor: PetalSoft.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Sign out',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (avatarInitial != null) ...[
                const SizedBox(width: 8),
                MarkLedAvatar(initial: avatarInitial!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 36px Calmness mark + quieter Cormorant Soft italic seasons (Dawn Mist face).
class MarkLedLockup extends StatelessWidget {
  const MarkLedLockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CalmnessMark(size: 36),
        const SizedBox(width: 10),
        Text(
          'seasons',
          style: PetalSoft.wordmarkTextStyle(),
        ),
      ],
    );
  }
}

class MarkLedAvatar extends StatelessWidget {
  const MarkLedAvatar({super.key, required this.initial, this.size = 32});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PetalSoft.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: PetalSoft.blush),
      ),
      child: Text(
        initial.isEmpty ? '·' : initial[0].toUpperCase(),
        style: TextStyle(
          fontFamily: PetalSoft.fontFamily,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: PetalSoft.ink,
          height: 1,
        ),
      ),
    );
  }
}
