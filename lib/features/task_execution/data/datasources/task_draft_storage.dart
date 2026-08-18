import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/task_draft.dart';

/// Persists [TaskDraft] data in SharedPreferences.
///
/// Each draft is stored under key `task_draft_{plandailyId}`.
/// This ensures one draft per task assignment.
///
/// Flow:
/// 1. Mechanic taps "Mulai" → [saveDraft] stores startTime + photoBefore
/// 2. Mechanic taps on an in-progress task → [getDraft] loads saved data
/// 3. Mechanic submits → API POST succeeds → [deleteDraft] clears local data
class TaskDraftStorage {
  static final _keyPrefix = 'task_draft_';

  /// Save a draft for the given task.
  Future<void> saveDraft(TaskDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${draft.plandailyId}', draft.toJson());
  }

  /// Load a draft for the given plandailyId. Returns null if none exists.
  Future<TaskDraft?> getDraft(String plandailyId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_keyPrefix$plandailyId');
    if (json == null) return null;
    try {
      return TaskDraft.fromJson(json);
    } catch (_) {
      // Corrupted data — remove it
      await prefs.remove('$_keyPrefix$plandailyId');
      return null;
    }
  }

  /// Delete the draft after a successful API submission.
  Future<void> deleteDraft(String plandailyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$plandailyId');
  }

  /// Check if a draft exists for the given plandailyId.
  Future<bool> hasDraft(String plandailyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_keyPrefix$plandailyId');
  }

  /// Get all saved drafts (useful for checking which tasks have been started).
  Future<Map<String, TaskDraft>> getAllDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = <String, TaskDraft>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_keyPrefix)) {
        final json = prefs.getString(key);
        if (json != null) {
          try {
            final draft = TaskDraft.fromJson(json);
            drafts[draft.plandailyId] = draft;
          } catch (_) {
            // skip corrupted entries
          }
        }
      }
    }
    return drafts;
  }

  /// Delete all saved drafts, used when switching accounts during testing.
  Future<void> clearAllDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
