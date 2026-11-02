import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/lab_service.dart';
import '../theme/petal_soft.dart';
import 'lab_confirm_screen.dart';

/// Phase 2: pick or load the synthetic demo PDF, upload, run extract.
class LabUploadScreen extends StatefulWidget {
  const LabUploadScreen({super.key, this.labService});

  final LabService? labService;

  @override
  State<LabUploadScreen> createState() => _LabUploadScreenState();
}

class _LabUploadScreenState extends State<LabUploadScreen> {
  late final LabService _labs = widget.labService ?? LabService();
  bool _busy = false;
  String? _error;
  String? _selectedName;
  Uint8List? _selectedBytes;

  Future<void> _runUpload({
    required Uint8List bytes,
    required String filename,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _selectedName = filename;
      _selectedBytes = bytes;
    });
    try {
      final result = await _labs.uploadAndExtract(
        bytes: bytes,
        originalFilename: filename,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LabConfirmScreen(
            document: result.document,
            initialRows: result.biomarkers,
            labService: _labs,
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

  Future<void> _pickPdf() async {
    if (_busy) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _error = 'Could not read PDF bytes from picker';
      });
      return;
    }
    final name = file.name.isEmpty ? 'lab-panel.pdf' : file.name;
    setState(() {
      _selectedName = name;
      _selectedBytes = bytes;
      _error = null;
    });
  }

  Future<void> _uploadSelected() async {
    final bytes = _selectedBytes;
    final name = _selectedName;
    if (bytes == null || name == null) {
      await _pickPdf();
      return;
    }
    await _runUpload(bytes: bytes, filename: name);
  }

  Future<void> _useDemoPdf() async {
    if (_busy) return;
    final data = await rootBundle.load(
      'assets/labs/synthetic-hk-womens-panel.pdf',
    );
    final bytes = data.buffer.asUint8List();
    setState(() {
      _selectedName = 'synthetic-hk-womens-panel.pdf';
      _selectedBytes = bytes;
      _error = null;
    });
  }

  void _clearSelection() {
    if (_busy) return;
    setState(() {
      _selectedName = null;
      _selectedBytes = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = _selectedName != null && _selectedBytes != null;
    final sizeLabel = hasSelection
        ? _formatBytes(_selectedBytes!.length)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('femm')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'LABS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: PetalSoft.accent,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: PetalSoft.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: PetalSoft.ink.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: PetalSoft.ink.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: PetalSoft.ink.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'Your health-check labs',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload a women’s health-check PDF. We extract the biomarker '
                  'table for you to confirm — not a diagnosis.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PetalSoft.muted,
                  ),
                ),
                const SizedBox(height: 24),
                Material(
                  color: PetalSoft.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: hasSelection
                          ? PetalSoft.accent.withValues(alpha: 0.45)
                          : PetalSoft.ink.withValues(alpha: 0.12),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _busy ? null : _pickPdf,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 28,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            hasSelection
                                ? Icons.picture_as_pdf_outlined
                                : Icons.upload_file_outlined,
                            size: 36,
                            color: PetalSoft.accent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasSelection
                                ? _selectedName!
                                : 'Tap to choose a PDF',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasSelection
                                ? '$sizeLabel · ready to extract'
                                : 'PDF from your health check',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: PetalSoft.muted,
                            ),
                          ),
                          if (hasSelection && !_busy) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _clearSelection,
                              child: const Text('Choose a different file'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
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
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : (hasSelection ? _uploadSelected : _pickPdf),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            hasSelection ? 'Upload & extract' : 'Choose PDF',
                          ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _busy ? null : _useDemoPdf,
                    child: Text(
                      'Use demo PDF instead',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PetalSoft.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
