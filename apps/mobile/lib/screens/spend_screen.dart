import 'package:flutter/material.dart';

import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import '../services/intake_service.dart';
import 'survey_screen.dart';

/// Phase 3.1 — multi-select the six locked spend buckets (≥1 required).
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
        _error = 'Select at least one category you already spend on.';
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
          builder: (_) => SurveyScreen(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spend categories')),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Select categories you already spend on. Upsell later stays '
                'inside these buckets only. Care-navigation — not a diagnosis.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                for (final bucket in SpendBucket.all)
                  CheckboxListTile(
                    value: _selected.contains(bucket),
                    title: Text(bucket.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: _busy
                        ? null
                        : (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(bucket);
                              } else {
                                _selected.remove(bucket);
                              }
                            });
                          },
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _busy || _selected.isEmpty ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Continue (${_selected.length} selected)',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
