/// One biomarker row from PDF extract / user confirm (Phase 2).
/// [flag] is only `H`, `L`, or null — never invent clinical meaning in UI.
class LabBiomarker {
  LabBiomarker({
    this.id,
    required this.sortOrder,
    required this.name,
    this.value,
    this.unit,
    this.refRange,
    this.flag,
    this.isDeleted = false,
  });

  final String? id;
  final int sortOrder;
  String name;
  double? value;
  String? unit;
  String? refRange;

  /// `H`, `L`, or null when the PDF/extract did not supply a flag.
  String? flag;
  bool isDeleted;

  factory LabBiomarker.fromJson(Map<String, dynamic> json) {
    return LabBiomarker(
      id: json['id']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      value: json['value'] == null ? null : (json['value'] as num).toDouble(),
      unit: json['unit']?.toString(),
      refRange: json['ref_range']?.toString(),
      flag: _normalizeFlag(json['flag']),
      isDeleted: json['is_deleted'] == true,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'sort_order': sortOrder,
      'name': name,
      'value': value,
      'unit': unit,
      'ref_range': refRange,
      'flag': flag,
      'is_deleted': isDeleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static String? _normalizeFlag(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toUpperCase();
    if (s == 'H' || s == 'L') return s;
    if (s.isEmpty) return null;
    // Unknown tokens are dropped — do not invent H/L.
    return null;
  }
}

class LabDocument {
  LabDocument({
    required this.id,
    required this.storagePath,
    required this.status,
    this.originalFilename,
    this.extractError,
  });

  final String id;
  final String storagePath;
  final String status;
  final String? originalFilename;
  final String? extractError;

  factory LabDocument.fromJson(Map<String, dynamic> json) {
    return LabDocument(
      id: json['id'].toString(),
      storagePath: (json['storage_path'] ?? '').toString(),
      status: (json['status'] ?? 'uploaded').toString(),
      originalFilename: json['original_filename']?.toString(),
      extractError: json['extract_error']?.toString(),
    );
  }
}
