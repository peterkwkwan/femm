import 'package:flutter/material.dart';

import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import '../services/intake_service.dart';
import '../theme/petal_soft.dart';
import '../widgets/path_a_step_header.dart';
import 'symptoms_screen.dart';

/// Path A routine / spend — multi-select the six locked buckets (≥1 required).
class SpendScreen extends StatefulWidget {
  const SpendScreen({
    super.key,
    required this.session,
    this.intakeService,
  });

  final PathASession session;
  final IntakeService? intakeService;

  @override
  State<SpendScreen> createState() => _SpendScreenState();
}

class _SpendScreenState extends State<SpendScreen> {
  late final IntakeService _intake = widget.intakeService ?? IntakeService();
  late final Set<SpendBucket> _selected = {
    ...widget.session.spendBuckets,
  };
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_selected.isEmpty) {
      setState(() {
        _error = 'Select at least one part of your routine.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _intake.saveSpend(
        sessionId: widget.session.id,
        buckets: _selected,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SymptomsScreen(
            session: session,
            intakeService: _intake,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _toggle(SpendBucket bucket) {
    if (_busy) return;
    setState(() {
      if (_selected.contains(bucket)) {
        _selected.remove(bucket);
      } else {
        _selected.add(bucket);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('femm')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PathAStepHeader(step: 1, label: 'Routine'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'How do you look after yourself currently?',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your routine helps us tailor your recovery plan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PetalSoft.muted,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final bucket in SpendBucket.all)
                      FilterChip(
                        label: Text(bucket.chipLabel),
                        selected: _selected.contains(bucket),
                        onSelected: _busy ? null : (_) => _toggle(bucket),
                        showCheckmark: false,
                        selectedColor: PetalSoft.accent,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _selected.contains(bucket)
                              ? Colors.white
                              : PetalSoft.ink,
                          fontSize: 13,
                        ),
                        backgroundColor: PetalSoft.surface,
                        side: BorderSide(
                          color: _selected.contains(bucket)
                              ? Colors.transparent
                              : PetalSoft.ink.withValues(alpha: 0.18),
                        ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_selected.length} selected',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PetalSoft.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy || _selected.isEmpty ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
