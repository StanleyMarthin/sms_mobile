import 'dart:convert';

/// A local draft saved when the mechanic presses "Mulai".
///
/// Stores only `startTime` and optional `photoBefore` path.
/// When the mechanic is ready to finish, the sheet loads this draft,
/// pre-fills the start data, and lets the mechanic complete the rest.
///
/// After a successful POST to the API, the draft is deleted from local storage.
class TaskDraft {
  /// Reference to the daily assignment (trx_jobdesc_plandaily.id).
  final String plandailyId;

  /// ISO 8601 timestamp when the mechanic pressed "Mulai".
  final String startTime;

  /// Local file path to the "Before" photo (optional).
  final String? photoBeforePath;
  final String? photoProcessPath;
  final String? photoAfterPath;
  final String? notes;
  final double? progressPercent;

  /// ISO 8601 timestamp when the draft was created.
  final String createdAt;

  TaskDraft({
    required this.plandailyId,
    required this.startTime,
    this.photoBeforePath,
    this.photoProcessPath,
    this.photoAfterPath,
    this.notes,
    this.progressPercent,
    required this.createdAt,
  });

  TaskDraft copyWith({
    String? plandailyId,
    String? startTime,
    String? photoBeforePath,
    String? photoProcessPath,
    String? photoAfterPath,
    String? notes,
    double? progressPercent,
    String? createdAt,
  }) {
    return TaskDraft(
      plandailyId: plandailyId ?? this.plandailyId,
      startTime: startTime ?? this.startTime,
      photoBeforePath: photoBeforePath ?? this.photoBeforePath,
      photoProcessPath: photoProcessPath ?? this.photoProcessPath,
      photoAfterPath: photoAfterPath ?? this.photoAfterPath,
      notes: notes ?? this.notes,
      progressPercent: progressPercent ?? this.progressPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serialize to JSON string for SharedPreferences storage.
  String toJson() => jsonEncode({
        'plandailyId': plandailyId,
        'startTime': startTime,
        'photoBeforePath': photoBeforePath,
        'photoProcessPath': photoProcessPath,
        'photoAfterPath': photoAfterPath,
        'notes': notes,
        'progressPercent': progressPercent,
        'createdAt': createdAt,
      });

  /// Deserialize from JSON string.
  factory TaskDraft.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return TaskDraft(
      plandailyId: map['plandailyId'] as String,
      startTime: map['startTime'] as String,
      photoBeforePath: map['photoBeforePath'] as String?,
      photoProcessPath: map['photoProcessPath'] as String?,
      photoAfterPath: map['photoAfterPath'] as String?,
      notes: map['notes'] as String?,
      progressPercent: (map['progressPercent'] as num?)?.toDouble(),
      createdAt:
          map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
