import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/disclaimers.dart';
import '../models/clinic.dart';
import '../models/match_result.dart';
import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import '../services/match_service.dart';

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
      setState(() => _remaining = Duration.zero);
      return;
    }
    void tick() {
      final left = until.difference(DateTime.now().toUtc());
      if (!mounted) return;
      setState(() {
        _remaining = left.isNegative ? Duration.zero : left;
      });
      if (left.isNegative || left == Duration.zero) {
        _ticker?.cancel();
        unawaited(_onHoldCountdownExpired());
      }
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
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
    return Scaffold(
      appBar: AppBar(title: const Text('Your match')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _bootstrap,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildClinicalSection(context),
                        const SizedBox(height: 28),
                        Text(
                          'Aligned partners',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Only categories you already spend on. Book or skip '
                          'independently of the clinical hold.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (_partners.isEmpty)
                          Text(
                            'No spend categories selected.',
                            style: Theme.of(context).textTheme.bodyMedium,
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
            elevation: 6,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  FemmDisclaimers.stickyMatch,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Clinical recommendation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (match == null)
          const Text('No match yet.')
        else ...[
          Text(
            match.specialty.label,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (clinic != null) ...[
            const SizedBox(height: 4),
            Text(
              clinic.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${clinic.district} · ${clinic.addressLine}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Why this match',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(match.whyCopy),
          const SizedBox(height: 12),
          Text(
            'Recommended slot: ${_formatSlot(match.slot)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (_clinical != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                'Clinical booking confirmed.',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            )
          else if (holdAlive) ...[
            Text(
              'Hold expires in ${_formatCountdown(_remaining)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busyClinical ? null : _confirmClinical,
              child: _busyClinical
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm clinical booking'),
            ),
            const SizedBox(height: 4),
            Text(
              'Confirm is optional. You can book partners below without confirming.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (holdExpired) ...[
            Text(
              'Hold expired — slot released.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : _rehold,
              child: const Text('Hold another slot'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildUpsellTile(BuildContext context, UpsellPartner partner) {
    final bucket = SpendBucket.tryParse(partner.spendBucketDb);
    final booked = _bookedPartnerIds.contains(partner.id);
    final skipped = _skippedPartnerIds.contains(partner.id);
    final busy = _busyPartnerId == partner.id;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              partner.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${bucket?.label ?? partner.spendBucketDb} · ${partner.district}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(partner.tagline),
            const SizedBox(height: 8),
            if (booked)
              Text(
                'Partner booking saved.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (skipped)
              Row(
                children: [
                  Text(
                    'Skipped',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                  FilledButton.tonal(
                    onPressed: busy ? null : () => _bookPartner(partner),
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }
}
