import 'package:flutter/material.dart';

import '../models/path_a_session.dart';
import '../models/symptom_chip.dart';
import '../services/intake_service.dart';
import '../theme/petal_soft.dart';
import '../widgets/path_a_step_header.dart';
import 'match_gate_screen.dart';

/// Path A symptoms multi-select (replaces the short 8-question survey).
class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({
    super.key,
    required this.session,
    this.intakeService,
  });

  final PathASession session;
  final IntakeService? intakeService;

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  late final IntakeService _intake = widget.intakeService ?? IntakeService();
  late final Set<String> _selected = selectedSymptomKeysFromAnswers(
    widget.session.surveyAnswers,
  );
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_selected.isEmpty) {
      setState(() {
        _error = 'Tap at least one symptom that fits.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _intake.saveSymptoms(
        sessionId: widget.session.id,
        selectedKeys: Set<String>.from(_selected),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MatchGateScreen(
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

  void _toggle(String key) {
    if (_busy) return;
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
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
          const PathAStepHeader(step: 2, label: 'Symptoms'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'What are you dealing with right now?',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap everything that fits. This helps us match you with the '
                  'right specialist.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PetalSoft.muted,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in kSymptomChips)
                      FilterChip(
                        label: Text(chip.label),
                        selected: _selected.contains(chip.key),
                        onSelected: _busy ? null : (_) => _toggle(chip.key),
                        showCheckmark: false,
                        selectedColor: PetalSoft.accent,
                        labelStyle: TextStyle(
                          color: _selected.contains(chip.key)
                              ? Colors.white
                              : PetalSoft.ink,
                          fontSize: 13,
                        ),
                        backgroundColor: PetalSoft.surface,
                        side: BorderSide(
                          color: _selected.contains(chip.key)
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
