import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/lab_service.dart';
import '../theme/petal_soft.dart';
import '../widgets/path_a_step_header.dart';
import 'lab_confirm_screen.dart';

/// Path A Labs step — stacked Upload PDF / Take a photo action cards.
class LabUploadScreen extends StatefulWidget {
  const LabUploadScreen({super.key, this.labService});

  final LabService? labService;

  /// Footer helper under the Labs chooser.
  static const String storageHelperCopy =
      'Encrypted storage keeps your lab PDF secure and confidential.';

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
        _error = LabService.userFacingError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPdf() async {
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
    await _runUpload(bytes: bytes, filename: name);
  }

  Future<void> _useDemoPdf() async {
    if (_busy) return;
    final data = await rootBundle.load(
      'assets/labs/synthetic-hk-womens-panel.pdf',
    );
    await _runUpload(
      bytes: data.buffer.asUint8List(),
      filename: 'synthetic-hk-womens-panel.pdf',
    );
  }

  void _onTakePhotoDummy() {
    if (_busy) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera isn’t wired in this prototype.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = _selectedName != null && _selectedBytes != null;

    return Scaffold(
      backgroundColor: PetalSoft.bg,
      appBar: AppBar(
        title: const Text('femm'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Path A',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PetalSoft.muted,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PathAStepHeader(step: PathAStep.labs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Text(
                'Your health-check labs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: PetalSoft.displayFontFamily,
                  fontSize: 26,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your lab results as a PDF. We extract the biomarker table '
                'for you to confirm — not a diagnosis.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: PetalSoft.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              _ActionCard(
                emphasized: true,
                icon: Icons.picture_as_pdf_outlined,
                title: hasSelection ? _selectedName! : 'Upload PDF',
                subtitle: hasSelection
                    ? (_busy
                        ? 'Uploading & extracting…'
                        : 'Selected — extracting biomarkers')
                    : 'Primary path — choose a lab report file',
                onTap: _busy ? null : _pickAndUploadPdf,
                trailing: _busy && hasSelection
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PetalSoft.accent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _ActionCard(
                emphasized: false,
                icon: Icons.photo_camera_outlined,
                title: 'Take a photo',
                subtitle: 'Visual peer option for the prototype',
                badge: 'Prototype · camera won’t open',
                onTap: _busy ? null : _onTakePhotoDummy,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _useDemoPdf,
                child: Text(
                  'Use demo PDF instead',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: PetalSoft.muted,
                  ),
                ),
              ),
              Text(
                LabUploadScreen.storageHelperCopy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PetalSoft.muted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.emphasized,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.trailing,
  });

  final bool emphasized;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: PetalSoft.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: emphasized
              ? PetalSoft.accent
              : PetalSoft.ink.withValues(alpha: 0.14),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: emphasized ? PetalSoft.accentSoft : PetalSoft.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: emphasized
                      ? null
                      : Border.all(
                          color: PetalSoft.ink.withValues(alpha: 0.10),
                        ),
                ),
                child: Icon(
                  icon,
                  color: emphasized ? PetalSoft.accent : PetalSoft.muted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: PetalSoft.displayFontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PetalSoft.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: PetalSoft.muted,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
