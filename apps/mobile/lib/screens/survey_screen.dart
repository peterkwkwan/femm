import 'package:flutter/material.dart';

import '../models/path_a_session.dart';
import '../models/survey_question.dart';
import '../services/intake_service.dart';
import 'match_gate_screen.dart';

/// Phase 3.2 — ≤8 clinical + skin/hair questions; answers persisted.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({
    super.key,
    required this.session,
    this.intakeService,
  });

  final PathASession session;
  final IntakeService? intakeService;

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  late final IntakeService _intake = widget.intakeService ?? IntakeService();
  late final Map<String, String> _answers = Map<String, String>.from(
    widget.session.surveyAnswers,
  );
  bool _busy = false;
  String? _error;

  bool get _complete =>
      kSurveyQuestions.every((q) => (_answers[q.key] ?? '').isNotEmpty);

  Future<void> _save() async {
    if (!_complete) {
      setState(() {
        _error = 'Please answer every question.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _intake.saveSurvey(
        sessionId: widget.session.id,
        answers: Map<String, String>.from(_answers),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Short survey')),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${kSurveyQuestions.length} questions on symptoms, goals, '
                'skin, and hair. Used for care-navigation matching only — '
                'not a diagnosis.',
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
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: kSurveyQuestions.length,
              itemBuilder: (context, index) {
                final q = kSurveyQuestions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${index + 1}. ${q.prompt}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      for (final option in q.options)
                        RadioListTile<String>(
                          dense: true,
                          title: Text(option),
                          value: option,
                          groupValue: _answers[q.key],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _answers[q.key] = v;
                                  });
                                },
                        ),
                      const Divider(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _busy || !_complete ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save survey & continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
