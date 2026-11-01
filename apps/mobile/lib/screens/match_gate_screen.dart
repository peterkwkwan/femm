import 'package:flutter/material.dart';

import '../constants/disclaimers.dart';
import '../models/path_a_session.dart';
import '../models/survey_question.dart';
import '../services/intake_service.dart';
import 'match_screen.dart';
import 'spend_screen.dart';
import 'survey_screen.dart';

/// Phase 3.3 — Match entry is gated until spend + survey are complete.
/// Phase 4 — ready state opens rule-based match + 15-min hold + upsell.
class MatchGateScreen extends StatefulWidget {
  const MatchGateScreen({
    super.key,
    required this.session,
    this.intakeService,
  });

  final PathASession session;
  final IntakeService? intakeService;

  @override
  State<MatchGateScreen> createState() => _MatchGateScreenState();
}

class _MatchGateScreenState extends State<MatchGateScreen> {
  late final IntakeService _intake = widget.intakeService ?? IntakeService();
  PathASession? _session;
  bool _labsConfirmed = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fresh = await _intake.fetchSession(widget.session.id);
      final session = fresh ?? widget.session;
      final labsOk = await _intake.labsConfirmedForSession(session);
      if (!mounted) return;
      setState(() {
        _session = session;
        _labsConfirmed = labsOk;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _session = widget.session;
        _labsConfirmed = false;
        _loading = false;
      });
    }
  }

  Future<void> _openSpend() async {
    final session = _session ?? widget.session;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SpendScreen(
          session: session,
          intakeService: _intake,
        ),
      ),
    );
  }

  Future<void> _openSurvey() async {
    final session = _session ?? widget.session;
    if (!session.hasSpend) {
      await _openSpend();
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SurveyScreen(
          session: session,
          intakeService: _intake,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session ?? widget.session;
    final ready = _labsConfirmed && session.readyForMatch;

    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          FemmDisclaimers.oneLiner,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!ready) ...[
                      Text(
                        'Match is locked',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Labs must be confirmed, then finish spend categories '
                        'and the short survey before matching can start.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _GateRow(
                        label: 'Labs confirmed',
                        done: _labsConfirmed,
                        onFix: null,
                      ),
                      const SizedBox(height: 8),
                      _GateRow(
                        label: 'Spend categories',
                        done: session.hasSpend,
                        onFix: _labsConfirmed ? _busyGuard(_openSpend) : null,
                      ),
                      const SizedBox(height: 8),
                      _GateRow(
                        label: 'Survey (8 questions)',
                        done: session.hasSurvey,
                        onFix: (_labsConfirmed && session.hasSpend)
                            ? _busyGuard(_openSurvey)
                            : null,
                      ),
                    ] else ...[
                      Text(
                        'Ready for match',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Spend and survey are saved. Next: rule-based clinical '
                        'recommendation with a 15-minute slot hold and '
                        'same-bucket upsell — book either path independently.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Spend: ${session.spendBuckets.map((b) => b.label).join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Survey answers: ${session.surveyAnswers.length}/${kSurveyQuestions.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MatchScreen(session: session),
                            ),
                          );
                        },
                        child: const Text('Start match'),
                      ),
                    ],
                    const Spacer(),
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
    );
  }

  VoidCallback? _busyGuard(Future<void> Function() action) {
    return () {
      action();
    };
  }
}

class _GateRow extends StatelessWidget {
  const _GateRow({
    required this.label,
    required this.done,
    required this.onFix,
  });

  final String label;
  final bool done;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        if (!done)
          TextButton(
            onPressed: onFix,
            child: const Text('Complete'),
          ),
      ],
    );
  }
}
