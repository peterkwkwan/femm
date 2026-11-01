import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/lab_service.dart';
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

  Future<void> _runUpload({
    required Uint8List bytes,
    required String filename,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
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
    await _runUpload(
      bytes: bytes,
      filename: file.name.isEmpty ? 'lab-panel.pdf' : file.name,
    );
  }

  Future<void> _useDemoPdf() async {
    final data = await rootBundle.load(
      'assets/labs/synthetic-hk-womens-panel.pdf',
    );
    await _runUpload(
      bytes: data.buffer.asUint8List(),
      filename: 'synthetic-hk-womens-panel.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload lab PDF')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Path A — labs',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a women’s health-check PDF. We extract the biomarker '
                'table for you to confirm. Not a diagnosis.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton(
                  onPressed: _pickPdf,
                  child: const Text('Choose PDF'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _useDemoPdf,
                  child: const Text('Use synthetic demo PDF'),
                ),
              ],
              const Spacer(),
              Text(
                'Original PDF is stored privately for later Path C download. '
                'H/L flags appear only when present on the report.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
