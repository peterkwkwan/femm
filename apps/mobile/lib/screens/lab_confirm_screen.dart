import 'package:flutter/material.dart';

import '../models/lab_biomarker.dart';
import '../services/intake_service.dart';
import '../services/lab_service.dart';
import '../theme/petal_soft.dart';
import 'spend_screen.dart';

/// Editable biomarker list after extract. Flags shown only when present.
class LabConfirmScreen extends StatefulWidget {
  const LabConfirmScreen({
    super.key,
    required this.document,
    required this.initialRows,
    this.labService,
  });

  final LabDocument document;
  final List<LabBiomarker> initialRows;
  final LabService? labService;

  @override
  State<LabConfirmScreen> createState() => _LabConfirmScreenState();
}

class _LabConfirmScreenState extends State<LabConfirmScreen> {
  late final LabService _labs = widget.labService ?? LabService();
  final IntakeService _intake = IntakeService();
  late List<LabBiomarker> _rows;
  bool _busy = false;
  String? _error;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows
        .where((r) => !r.isDeleted)
        .map(
          (r) => LabBiomarker(
            id: r.id,
            sortOrder: r.sortOrder,
            name: r.name,
            value: r.value,
            unit: r.unit,
            refRange: r.refRange,
            flag: r.flag,
          ),
        )
        .toList();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _labs.confirmLabs(documentId: widget.document.id, rows: _rows);
      final session = await _intake.ensureSessionForLab(
        labDocumentId: widget.document.id,
      );
      if (!mounted) return;
      setState(() {
        _confirmed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Labs confirmed and saved')),
      );
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SpendScreen(
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

  Future<void> _continueToSpend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _intake.ensureSessionForLab(
        labDocumentId: widget.document.id,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SpendScreen(
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

  void _markDeleted(int index) {
    setState(() {
      _rows[index].isDeleted = true;
    });
  }

  List<LabBiomarker> get _visible =>
      _rows.where((r) => !r.isDeleted).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('femm'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your health-check labs',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirm the extracted rows. We only flag H/L when the '
                  'report includes a range — not a diagnosis.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PetalSoft.muted,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_confirmed)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Confirmed. Continue to your routine and symptoms.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final row = visible[index];
                final masterIndex = _rows.indexOf(row);
                return _BiomarkerEditor(
                  key: ValueKey(row.id ?? '${row.name}-$masterIndex'),
                  row: row,
                  onDelete: _confirmed || _busy
                      ? null
                      : () => _markDeleted(masterIndex),
                  readOnly: _confirmed || _busy,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: (_busy || _confirmed || visible.isEmpty)
                        ? null
                        : _confirm,
                    child: _busy && !_confirmed
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _confirmed
                                ? 'Labs confirmed'
                                : 'Confirm labs',
                          ),
                  ),
                  if (_confirmed) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : _continueToSpend,
                      child: const Text('Continue to routine'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiomarkerEditor extends StatefulWidget {
  const _BiomarkerEditor({
    super.key,
    required this.row,
    required this.onDelete,
    required this.readOnly,
  });

  final LabBiomarker row;
  final VoidCallback? onDelete;
  final bool readOnly;

  @override
  State<_BiomarkerEditor> createState() => _BiomarkerEditorState();
}

class _BiomarkerEditorState extends State<_BiomarkerEditor> {
  LabBiomarker get row => widget.row;

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    final valueText = [
      if (row.value != null) row.value.toString(),
      if (row.unit != null && row.unit!.isNotEmpty) row.unit,
    ].join(' ');
    final flagSuffix =
        row.flag == null || row.flag!.isEmpty ? '' : ' · ${row.flag}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PetalSoft.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: PetalSoft.ink.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: readOnly
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row.name}  $valueText$flagSuffix',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: row.name,
                            decoration: const InputDecoration(
                              labelText: 'Test',
                              isDense: true,
                            ),
                            onChanged: (v) => row.name = v,
                          ),
                        ),
                        if (widget.onDelete != null)
                          IconButton(
                            tooltip: 'Remove row',
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: row.value?.toString() ?? '',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Result',
                              isDense: true,
                            ),
                            onChanged: (v) {
                              final t = v.trim();
                              if (t.isEmpty) {
                                row.value = null;
                                return;
                              }
                              row.value = double.tryParse(t);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: row.unit ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              isDense: true,
                            ),
                            onChanged: (v) => row.unit =
                                v.trim().isEmpty ? null : v.trim(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Flag',
                              isDense: true,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: row.flag,
                                items: const [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('—'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'H',
                                    child: Text('H'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'L',
                                    child: Text('L'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    row.flag = v;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: row.refRange ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Reference range',
                        isDense: true,
                        helperText:
                            'Flag is H/L only when present — empty means no flag, not “normal”.',
                      ),
                      onChanged: (v) => row.refRange =
                          v.trim().isEmpty ? null : v.trim(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
