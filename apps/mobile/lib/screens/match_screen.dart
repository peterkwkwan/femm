import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/disclaimers.dart';
import '../models/clinic.dart';
import '../models/match_result.dart';
import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import '../services/match_service.dart';
import '../theme/petal_soft.dart';
import '../widgets/path_a_step_header.dart';

/// Phase 4 — clinical recommendation (15-min hold) + same-bucket upsell.
/// Phase 6 — hold expire/release, double-confirm, leave-and-return hardening.
/// Clinical and upsell book independently. Sticky not-a-diagnosis disclaimer.
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.session,
    this.matchService,
  });

  final PathASession session;
  final MatchService? matchService;

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

  String _formatCountdown(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSlot(AppointmentSlot? slot) {
    if (slot == null) return 'Slot unavailable';
    final local = slot.startsAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi (local)';
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
      appBar: AppBar(title: const Text('femm')),
      body: Column(
        children: [
          const PathAStepHeader(step: 3, label: 'Match'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _bootstrap,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Your next step, held for you',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        _buildClinicalSection(context),
                        const SizedBox(height: 24),
                        Text(
                          'Optional extras in your routine',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: PetalSoft.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_partners.isEmpty)
                          Text(
                            'No routine categories selected.',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          for (final partner in _partners) ...[
                            _buildUpsellTile(context, partner),
                            const SizedBox(height: 12),
                          ],
                        const SizedBox(height: 8),
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
          Material(
            color: PetalSoft.accentSoft,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  FemmDisclaimers.stickyMatch,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PetalSoft.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalSection(BuildContext context) {
    final theme = Theme.of(context);
    final match = _matchRow;
    final clinic = match?.clinic;
    final holdAlive = _clinical == null &&
        match != null &&
        !_holdExpiredLocal &&
        match.hasActiveHold &&
        _remaining > Duration.zero;
    // Show re-hold even after release_expired cleared slot_id / expires_at.
    final holdExpired = _clinical == null &&
        match != null &&
        !holdAlive &&
        (_holdExpiredLocal ||
            match.slotId != null ||
            match.holdExpiresAt != null);

    if (match == null) {
      return Text('No match yet.', style: theme.textTheme.bodyMedium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PetalSoft.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PetalSoft.ink.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _clinical != null
                    ? 'Clinical · booked'
                    : holdAlive
                        ? 'Clinical · reserved ${_formatCountdown(_remaining)}'
                        : 'Clinical recommendation',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: PetalSoft.accent,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                match.specialty.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (clinic != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${clinic.name} · ${clinic.district}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: PetalSoft.muted,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                match.whyCopy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PetalSoft.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Slot: ${_formatSlot(match.slot)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_clinical != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PetalSoft.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Appointment booked.',
              style: theme.textTheme.titleSmall,
            ),
          )
        else if (holdAlive) ...[
          FilledButton(
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
          ),
          const SizedBox(height: 6),
          Text(
            'Booking is optional. You can still choose extras below.',
            style: theme.textTheme.bodySmall,
          ),
        ] else if (holdExpired) ...[
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
      ],
    );
  }

  Widget _buildUpsellTile(BuildContext context, UpsellPartner partner) {
    final theme = Theme.of(context);
    final bucket = SpendBucket.tryParse(partner.spendBucketDb);
    final booked = _bookedPartnerIds.contains(partner.id);
    final skipped = _skippedPartnerIds.contains(partner.id);
    final busy = _busyPartnerId == partner.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PetalSoft.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${partner.name} · fits your ${bucket?.chipLabel.toLowerCase() ?? 'routine'}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${partner.district} · ${partner.tagline}',
            style: theme.textTheme.bodySmall?.copyWith(color: PetalSoft.muted),
          ),
          const SizedBox(height: 8),
          if (booked)
            Text(
              'Partner booking saved.',
              style: TextStyle(
                color: PetalSoft.accent,
                fontWeight: FontWeight.w600,
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
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: busy ? null : () => _bookPartner(partner),
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Book'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: busy ? null : () => _skipPartner(partner),
                  child: const Text('Skip'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
