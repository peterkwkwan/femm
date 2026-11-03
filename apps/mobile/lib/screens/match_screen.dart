import 'dart:async';

import 'package:flutter/material.dart';

import '../models/clinic.dart';
import '../models/clinical_specialty.dart';
import '../models/match_result.dart';
import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import '../services/match_service.dart';
import '../theme/petal_soft.dart';
import '../widgets/mark_led_app_bar.dart';
import '../widgets/path_a_step_header.dart';

/// Unified Match · step 4 of 4 — Sheet stack (Petal Soft).
///
/// Clinical reservation sheet + Book this appointment + optional extras.
/// Hold countdown stays live. No separate gate CTA on this screen.
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.session,
    this.matchService,
  });

  final PathASession session;
  final MatchService? matchService;

  /// Demo doctor labels for seed clinics (not real practitioners).
  static String demoDoctorName(ClinicalSpecialty specialty) {
    switch (specialty) {
      case ClinicalSpecialty.menopauseAwareGp:
        return 'Dr. Ava Wong';
      case ClinicalSpecialty.gynaeEndocrine:
        return 'Dr. Mei Chen';
      case ClinicalSpecialty.sleepMood:
        return 'Dr. Priya Shah';
      case ClinicalSpecialty.boneHeartRisk:
        return 'Dr. Leo Tan';
    }
  }

  /// Local slot label with am/pm, e.g. `4 Nov · 10:30 am`.
  static String formatSlotAmPm(AppointmentSlot? slot) {
    if (slot == null) return 'Slot unavailable';
    final local = slot.startsAt.toLocal();
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = local.day;
    final month = months[local.month - 1];
    var hour = local.hour % 12;
    if (hour == 0) hour = 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'pm' : 'am';
    return '$day $month · $hour:$minute $period';
  }

  /// `mm:ss` hold remaining (clamped at zero).
  static String formatHoldCountdown(Duration remaining) {
    final total = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Right-side hold caption beside the live countdown.
  static String holdCountdownCaption(Duration remaining) =>
      'Current booking held for: ${formatHoldCountdown(remaining)}';

  /// Sheet header left label for clinical hold / booked states.
  static String clinicalHeaderLabel({
    required bool booked,
    required bool holdAlive,
  }) {
    if (booked) return 'Clinical · booked';
    if (holdAlive) return 'Clinical booking';
    return 'Clinical';
  }

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with WidgetsBindingObserver {
  late final MatchService _match = widget.matchService ?? MatchService();

  PathAMatch? _matchRow;
  ClinicalBooking? _clinical;
  List<UpsellPartner> _partners = const <UpsellPartner>[];
  final Set<String> _bookedPartnerIds = <String>{};
  final Set<String> _skippedPartnerIds = <String>{};

  bool _loading = true;
  bool _busyClinical = false;
  bool _releasingHold = false;
  /// Local flag so UI still offers re-hold after RPC cleared slot_id / expires_at.
  bool _holdExpiredLocal = false;
  bool _sheetExpanded = false;
  String? _busyPartnerId;
  String? _error;
  Duration _remaining = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  /// Leave-and-return: refresh hold / booking state when app resumes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !_busyClinical) {
      unawaited(_resumeFromBackground());
    }
  }

  Future<void> _resumeFromBackground() async {
    try {
      final resumed = await _match.resumeMatchState(widget.session);
      final upsellBookings =
          await _match.fetchUpsellBookings(widget.session.id);
      if (!mounted) return;
      setState(() {
        if (resumed.match != null) {
          _matchRow = resumed.match;
        }
        _clinical = resumed.clinical;
        _holdExpiredLocal =
            resumed.clinical == null && resumed.holdExpired;
        _bookedPartnerIds
          ..clear()
          ..addAll(upsellBookings.map((b) => b.partnerId));
        _error = null;
      });
      _syncCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final started = await _match.startOrResumeMatch(widget.session);
      final partners = await _match.partnersForSpend(widget.session.spendBuckets);
      final upsellBookings =
          await _match.fetchUpsellBookings(widget.session.id);
      if (!mounted) return;
      setState(() {
        _matchRow = started.match;
        _clinical = started.clinical;
        _partners = partners;
        _bookedPartnerIds
          ..clear()
          ..addAll(upsellBookings.map((b) => b.partnerId));
        _holdExpiredLocal = started.clinical == null &&
            !started.match.hasActiveHold &&
            (started.match.holdExpiresAt != null ||
                started.match.slotId != null);
        _loading = false;
        _error = null;
      });
      _syncCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _syncCountdown() {
    _ticker?.cancel();
    final match = _matchRow;
    final until = match?.holdExpiresAt;
    if (_clinical != null || until == null || _holdExpiredLocal) {
      if (_remaining != Duration.zero && mounted) {
        setState(() => _remaining = Duration.zero);
      }
      return;
    }
    void tick() {
      final left = until.difference(DateTime.now().toUtc());
      if (!mounted) return;
      final next = left.isNegative ? Duration.zero : left;
      if (next != _remaining) {
        setState(() => _remaining = next);
      }
      if (left.isNegative || left == Duration.zero) {
        _ticker?.cancel();
        unawaited(_onHoldCountdownExpired());
      }
    }

    // Defer the first tick so we never setState during the bootstrap build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tick();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    });
  }

  /// Expire/release: free inventory promptly when countdown hits zero on-screen.
  Future<void> _onHoldCountdownExpired() async {
    if (_clinical != null || _releasingHold || _holdExpiredLocal) return;
    setState(() {
      _holdExpiredLocal = true;
      _remaining = Duration.zero;
    });
    _releasingHold = true;
    try {
      await _match.releaseExpiredHolds();
      final refreshed = await _match.fetchMatch(widget.session.id);
      if (!mounted) return;
      if (refreshed != null) {
        setState(() => _matchRow = refreshed);
      }
    } catch (_) {
      // UI already shows expired; next re-hold / resume will release again.
    } finally {
      _releasingHold = false;
    }
  }

  Future<void> _confirmClinical() async {
    // Double-confirm: already booked → no-op success path.
    if (_clinical != null || _busyClinical) return;
    if (_holdExpiredLocal || _remaining == Duration.zero) {
      setState(() {
        _error = 'Hold expired — hold another slot before confirming.';
        _holdExpiredLocal = true;
      });
      return;
    }
    setState(() {
      _busyClinical = true;
      _error = null;
    });
    try {
      // RPC is idempotent: second confirm returns the existing booking.
      final booking = await _match.confirmClinical(widget.session.id);
      if (!mounted) return;
      setState(() {
        _clinical = booking;
        _busyClinical = false;
        _holdExpiredLocal = false;
      });
      _ticker?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busyClinical = false;
      });
      await _bootstrap();
    }
  }

  Future<void> _rehold() async {
    setState(() {
      _loading = true;
      _error = null;
      _holdExpiredLocal = false;
    });
    try {
      await _match.releaseExpiredHolds();
      // Clear stale client state; startOrResume will pick a new slot.
      final started = await _match.startOrResumeMatch(widget.session);
      if (!mounted) return;
      setState(() {
        _matchRow = started.match;
        _clinical = started.clinical;
        _holdExpiredLocal = false;
        _loading = false;
      });
      _syncCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _bookPartner(UpsellPartner partner) async {
    setState(() {
      _busyPartnerId = partner.id;
      _error = null;
    });
    try {
      await _match.bookUpsell(
        sessionId: widget.session.id,
        partnerId: partner.id,
      );
      if (!mounted) return;
      setState(() {
        _bookedPartnerIds.add(partner.id);
        _skippedPartnerIds.remove(partner.id);
        _busyPartnerId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busyPartnerId = null;
      });
    }
  }

  void _skipPartner(UpsellPartner partner) {
    setState(() {
      _skippedPartnerIds.add(partner.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: PetalSoft.bg,
      appBar: const MarkLedAppBar(),
      body: Column(
        children: [
          const PathAStepHeader(step: PathAStep.match),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _bootstrap,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildSheetStack(context),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                          child: const Text('Back to home'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetStack(BuildContext context) {
    final theme = Theme.of(context);
    final match = _matchRow;
    if (match == null) {
      return Text('No match yet.', style: theme.textTheme.bodyMedium);
    }

    final clinic = match.clinic;
    final holdAlive = _clinical == null &&
        !_holdExpiredLocal &&
        match.hasActiveHold &&
        _remaining > Duration.zero;
    final holdExpired = _clinical == null &&
        !holdAlive &&
        (_holdExpiredLocal ||
            match.slotId != null ||
            match.holdExpiresAt != null);

    final holdLabel = MatchScreen.clinicalHeaderLabel(
      booked: _clinical != null,
      holdAlive: holdAlive,
    );
    final countdownText =
        holdAlive ? MatchScreen.formatHoldCountdown(_remaining) : null;

    return Container(
      decoration: BoxDecoration(
        color: PetalSoft.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PetalSoft.accentSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Text(
                  holdLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: PetalSoft.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                if (countdownText != null) ...[
                  Text(
                    'Current booking held for: ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: PetalSoft.ink,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    countdownText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: PetalSoft.fontFamily,
                      color: PetalSoft.ink,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: PetalSoft.accentSoft),
          Material(
            color: PetalSoft.surface,
            child: InkWell(
              onTap: () => setState(() => _sheetExpanded = !_sheetExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      MatchScreen.demoDoctorName(match.specialty),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: PetalSoft.fontFamily,
                        color: PetalSoft.ink,
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                        height: 1.2,
                        letterSpacing: PetalSoft.letterSpacingEm(
                          20,
                          PetalSoft.welcomeTrackingEm,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clinic?.name ?? match.specialty.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PetalSoft.muted,
                        fontSize: 11,
                      ),
                    ),
                    if (clinic != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        clinic.addressLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: PetalSoft.ink.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_sheetExpanded) ...[
                      const SizedBox(height: 14),
                      Text(
                        'YOUR PATH A',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: PetalSoft.muted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Routine',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: PetalSoft.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final bucket in widget.session.spendBuckets)
                            _PathChip(label: bucket.chipLabel),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Symptoms',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: PetalSoft.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final label
                              in widget.session.selectedSymptomLabels)
                            _PathChip(label: label),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Slot · ${MatchScreen.formatSlotAmPm(match.slot)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: PetalSoft.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _sheetExpanded
                              ? 'Hide Path A summary'
                              : 'Tap for summary',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: PetalSoft.muted,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _sheetExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: PetalSoft.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _buildClinicalActions(
              context,
              holdAlive: holdAlive,
              holdExpired: holdExpired,
            ),
          ),
          Container(
            color: PetalSoft.bg,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'OPTIONAL EXTRAS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: PetalSoft.muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                if (_partners.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No routine categories selected.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PetalSoft.muted,
                      ),
                    ),
                  )
                else
                  for (final partner in _partners)
                    _buildUpsellRow(context, partner),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalActions(
    BuildContext context, {
    required bool holdAlive,
    required bool holdExpired,
  }) {
    final theme = Theme.of(context);
    if (_clinical != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PetalSoft.accentSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Appointment booked.',
          style: theme.textTheme.titleSmall,
        ),
      );
    }
    if (holdAlive) {
      return FilledButton(
        onPressed: _busyClinical ? null : _confirmClinical,
        child: _busyClinical
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Book this appointment'),
      );
    }
    if (holdExpired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hold expired — slot released.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loading ? null : _rehold,
            child: const Text('Hold another slot'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildUpsellRow(BuildContext context, UpsellPartner partner) {
    final theme = Theme.of(context);
    final bucket = SpendBucket.tryParse(partner.spendBucketDb);
    final booked = _bookedPartnerIds.contains(partner.id);
    final skipped = _skippedPartnerIds.contains(partner.id);
    final busy = _busyPartnerId == partner.id;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PetalSoft.accentSoft),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            partner.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: PetalSoft.ink,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${partner.district} · fits ${bucket?.chipLabel.toLowerCase() ?? 'routine'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: PetalSoft.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          if (booked)
            Text(
              'Partner booking saved.',
              style: TextStyle(
                color: PetalSoft.accent,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            )
          else if (skipped)
            Row(
              children: [
                Text('Skipped', style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: busy ? null : () => _bookPartner(partner),
                  child: const Text('Book instead'),
                ),
              ],
            )
          else
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: busy ? null : () => _bookPartner(partner),
                  child: busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Book'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: busy ? null : () => _skipPartner(partner),
                  style: TextButton.styleFrom(
                    foregroundColor: PetalSoft.muted,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PathChip extends StatelessWidget {
  const _PathChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PetalSoft.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PetalSoft.ink,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
