import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/entities/task_execution_log.dart';

/// **Step 2: Selesaikan Pekerjaan** — full form for submitting task progress.
///
/// When a [draft] is provided (from local storage), start time and
/// photo-before are pre-filled from the draft so the mechanic only needs
/// to fill finish time, progress, status, remaining photos, and notes.
///
/// Sections (top → bottom):
/// 1. Informasi Task (read-only)
/// 2. Waktu Kerja (start pre-filled from draft, finish, break)
/// 3. Progress Pekerjaan (manual input + status dropdown)
/// 4. Dokumentasi (photo before pre-filled, process/after)
/// 5. Catatan (optional notes)
/// 6. Submit button (with confirmation dialog)
class TaskExecutionSheet extends StatefulWidget {
  final TaskEntity task;
  final TaskDraft? draft;
  final void Function(TaskExecutionLog log) onSubmit;

  const TaskExecutionSheet({
    super.key,
    required this.task,
    this.draft,
    required this.onSubmit,
  });

  /// Show this sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required TaskEntity task,
    TaskDraft? draft,
    required void Function(TaskExecutionLog log) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskExecutionSheet(
        task: task,
        draft: draft,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<TaskExecutionSheet> createState() => _TaskExecutionSheetState();
}

class _TaskExecutionSheetState extends State<TaskExecutionSheet> {
  late TimeOfDay _startTime;
  late TimeOfDay _finishTime;
  int _breakMinutes = 0;
  double _progressPercent = 0;
  String _status = 'pending';

  final _notesController = TextEditingController();
  final _breakController = TextEditingController(text: '0');
  final _progressController = TextEditingController(text: '0');

  String? _photoBeforePath;
  String? _photoProcessPath;
  String? _photoAfterPath;

  final _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    final currentProgress = widget.task.progressPercent.clamp(0.0, 100.0);

    // Pre-fill from current task state without forcing completion.
    final draft = widget.draft;
    if (draft != null) {
      final draftStart = _parseTimeFromIso(draft.startTime);
      _startTime = draftStart ?? now;
      _finishTime = _nextValidFinishTime(_startTime, now);
      _photoBeforePath = draft.photoBeforePath;
      _status = 'onprogress';
      _progressPercent = currentProgress;
      _progressController.text = currentProgress.toInt().toString();
    } else if (widget.task.isInProgress) {
      _startTime = _parseTimeFromIso(widget.task.startedAt) ?? now;
      _finishTime = _nextValidFinishTime(_startTime, now);
      _status = 'onprogress';
      _progressPercent = currentProgress;
      _progressController.text = currentProgress.toInt().toString();
    } else {
      _startTime = now;
      _finishTime = TimeOfDay(
        hour: (now.hour + 1) % 24,
        minute: now.minute,
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _breakController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeFromIso(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay _nextValidFinishTime(TimeOfDay startTime, TimeOfDay candidate) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final candidateMinutes = candidate.hour * 60 + candidate.minute;
    if (candidateMinutes > startMinutes) {
      return candidate;
    }

    final nextMinutes = (startMinutes + 1) % (24 * 60);
    return TimeOfDay(
      hour: nextMinutes ~/ 60,
      minute: nextMinutes % 60,
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: AppColors.gold, width: 2),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _dragHandle(),
              const SizedBox(height: 8),
              _header(),
              const SizedBox(height: 20),

              // Section 1: Informasi Task
              _sectionLabel('Informasi Task', Icons.info_outline),
              const SizedBox(height: 10),
              _taskInfoCard(),
              const SizedBox(height: 24),

              // Section 2: Waktu Kerja
              _sectionLabel('Waktu Kerja', Icons.schedule),
              const SizedBox(height: 10),
              _timeRow(),
              const SizedBox(height: 12),
              _breakField(),
              const SizedBox(height: 24),

              // Section 3: Progress Pekerjaan
              _sectionLabel('Progress Pekerjaan', Icons.trending_up),
              const SizedBox(height: 10),
              _progressInput(),
              const SizedBox(height: 14),
              _statusDropdown(),
              const SizedBox(height: 24),

              // Section 4: Dokumentasi
              _sectionLabel('Dokumentasi', Icons.camera_alt_outlined),
              const SizedBox(height: 4),
              const Text(
                'Semua foto opsional.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              _photoRow(),
              const SizedBox(height: 24),

              // Section 5: Catatan
              _sectionLabel('Catatan', Icons.note_alt_outlined),
              const SizedBox(height: 10),
              _notesField(),
              const SizedBox(height: 28),

              // Submit
              _submitButton(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────
  // DRAG HANDLE + HEADER
  // ─────────────────────────────────────────────────────

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _header() {
    final isUpdatingProgress = widget.draft != null || widget.task.isInProgress;
    return Row(
      children: [
        Icon(
          isUpdatingProgress ? Icons.edit_note : Icons.check_circle_outline,
          color: AppColors.gold,
          size: 24,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isUpdatingProgress ? 'Update Progress' : 'Submit Progress',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // SECTION 1: INFORMASI TASK (READ-ONLY)
  // ─────────────────────────────────────────────────────

  Widget _taskInfoCard() {
    final t = widget.task;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _readOnlyField('Unit', t.unitName, Icons.directions_car_outlined),
          const Divider(color: AppColors.border, height: 16),
          _readOnlyField('Panel', t.panelName, Icons.dashboard_outlined),
          const Divider(color: AppColors.border, height: 16),
          _readOnlyField('Pekerjaan', t.jobName, Icons.build_outlined),
          if (t.customDescription.isNotEmpty) ...[
            const Divider(color: AppColors.border, height: 16),
            _readOnlyField(
                'Keterangan', t.customDescription, Icons.description_outlined),
          ],
        ],
      ),
    );
  }

  Widget _readOnlyField(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // SECTION 2: WAKTU KERJA
  // ─────────────────────────────────────────────────────

  Widget _timeRow() {
    return Row(
      children: [
        Expanded(
          child: _TimeTile(
            label: 'Start Time',
            time: _startTime,
            icon: Icons.login,
            onTap: () => _pickTime(isStart: true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 18, color: AppColors.textMuted),
        ),
        Expanded(
          child: _TimeTile(
            label: 'Finish Time',
            time: _finishTime,
            icon: Icons.logout,
            onTap: () => _pickTime(isStart: false),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _finishTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.background,
              surface: AppColors.surfaceCard,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _finishTime = picked;
        }
      });
    }
  }

  Widget _breakField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.coffee, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Break Duration',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                SizedBox(height: 1),
                Text(
                  'Durasi istirahat (menit)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _breakController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
                suffixText: 'min',
                suffixStyle:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              onChanged: (v) {
                _breakMinutes = int.tryParse(v) ?? 0;
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // SECTION 3: PROGRESS
  // ─────────────────────────────────────────────────────

  Widget _progressInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.percent, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                SizedBox(height: 1),
                Text(
                  'Persentase pekerjaan (0–100)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _progressController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
                suffixText: '%',
                suffixStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                setState(() {
                  _progressPercent = parsed.clamp(0, 100).toDouble();
                  if (_status != 'cancel') {
                    if (_progressPercent >= 100) {
                      _status = 'done';
                    } else if (_status == 'done') {
                      _status = _progressPercent > 0 ? 'onprogress' : 'pending';
                    }
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'done':
        return Icons.check_circle;
      case 'onprogress':
        return Icons.autorenew;
      case 'cancel':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'done':
        return AppColors.statusDone;
      case 'onprogress':
        return AppColors.gold;
      case 'cancel':
        return AppColors.statusLocked;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _statusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            _statusIcon(_status),
            size: 18,
            color: _statusColor(_status),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Status',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              dropdownColor: AppColors.surfaceCard,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              icon: const Icon(Icons.expand_more,
                  color: AppColors.textMuted, size: 20),
              items: const [
                DropdownMenuItem(
                  value: 'pending',
                  child: Text('Pending'),
                ),
                DropdownMenuItem(
                  value: 'onprogress',
                  child: Text('On Progress'),
                ),
                DropdownMenuItem(
                  value: 'done',
                  child: Text('Done'),
                ),
                DropdownMenuItem(
                  value: 'cancel',
                  child: Text('Cancel'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _status = v;
                    if (v == 'done' && _progressPercent < 100) {
                      _progressPercent = 100;
                      _progressController.text = '100';
                    } else if (v == 'pending' && _progressPercent > 0) {
                      _progressPercent = 0;
                      _progressController.text = '0';
                    }
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // SECTION 4: DOKUMENTASI
  // ─────────────────────────────────────────────────────

  Widget _photoRow() {
    return Row(
      children: [
        Expanded(
          child: _PhotoSlot(
            label: 'Before',
            imagePath: _photoBeforePath,
            isRequired: false,
            onPick: () => _pickPhoto('before'),
            onRemove: () => setState(() => _photoBeforePath = null),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PhotoSlot(
            label: 'Process',
            imagePath: _photoProcessPath,
            isRequired: false,
            onPick: () => _pickPhoto('process'),
            onRemove: () => setState(() => _photoProcessPath = null),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PhotoSlot(
            label: 'After',
            imagePath: _photoAfterPath,
            isRequired: false,
            onPick: () => _pickPhoto('after'),
            onRemove: () => setState(() => _photoAfterPath = null),
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhoto(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.gold),
                title: const Text('Kamera',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: AppColors.gold),
                title: const Text('Galeri',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (!mounted || picked == null) return;

      setState(() {
        switch (type) {
          case 'before':
            _photoBeforePath = picked.path;
            break;
          case 'process':
            _photoProcessPath = picked.path;
            break;
          case 'after':
            _photoAfterPath = picked.path;
            break;
        }
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuka ${source == ImageSource.camera ? 'kamera' : 'galeri'}: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kendala saat mengambil foto.'),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────
  // SECTION 5: CATATAN
  // ─────────────────────────────────────────────────────

  Widget _notesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Tulis catatan harian (opsional)...',
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surfaceInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // VALIDATION + SUBMIT
  // ─────────────────────────────────────────────────────

  String? _validate() {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final finishMin = _finishTime.hour * 60 + _finishTime.minute;

    if (finishMin <= startMin) {
      return 'Finish time harus lebih dari start time';
    }
    return null;
  }

  Widget _submitButton() {
    final isDone = _status == 'done';
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSubmitting ? null : _showConfirmation,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.background),
              )
            : const Icon(Icons.send, size: 20),
        label: Text(
          _isSubmitting
              ? 'Mengirim...'
              : (isDone ? 'Selesaikan Pekerjaan' : 'Simpan Progress'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isDone ? AppColors.statusDone : AppColors.gold,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// Show confirmation dialog before actually submitting.
  void _showConfirmation() {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.statusLocked.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final startStr =
        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final finishStr =
        '${_finishTime.hour.toString().padLeft(2, '0')}:${_finishTime.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Konfirmasi Submit',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waktu: $startStr — $finishStr',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (_breakMinutes > 0)
              Text(
                'Break: $_breakMinutes menit',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            Text(
              'Progress: ${_progressPercent.toInt()}%  •  Status: $_status',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Yakin data sudah benar?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doSubmit();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _doSubmit() {
    setState(() => _isSubmitting = true);

    final effectiveStatus = _status == 'cancel'
        ? 'cancel'
        : (_progressPercent >= 100 ? 'done' : _status);

    final now = DateTime.now();
    final startDt = DateTime(
      now.year, now.month, now.day,
      _startTime.hour, _startTime.minute,
    );
    final finishDt = DateTime(
      now.year, now.month, now.day,
      _finishTime.hour, _finishTime.minute,
    );

    final log = TaskExecutionLog(
      plandailyId: widget.task.plandailyId,
      startTime: startDt.toIso8601String(),
      finishTime: finishDt.toIso8601String(),
      breakDurationMinutes: _breakMinutes,
      progressPercent: _progressPercent,
      status: effectiveStatus,
      photoBefore: _photoBeforePath,
      photoProcess: _photoProcessPath,
      photoAfter: _photoAfterPath,
      dailyNotes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    widget.onSubmit(log);
    Navigator.of(context).pop();
  }
}

// ═══════════════════════════════════════════════════════════════
// Time Picker Tile
// ═══════════════════════════════════════════════════════════════
class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit, size: 14, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Photo Slot Widget
// ═══════════════════════════════════════════════════════════════
class _PhotoSlot extends StatelessWidget {
  final String label;
  final String? imagePath;
  final bool isRequired;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoSlot({
    required this.label,
    required this.imagePath,
    required this.isRequired,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;

    return Column(
      children: [
        GestureDetector(
          onTap: hasImage ? null : onPick,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isRequired && !hasImage
                    ? AppColors.statusLocked.withValues(alpha: 0.5)
                    : hasImage
                        ? AppColors.statusDone.withValues(alpha: 0.4)
                        : AppColors.border,
                width: isRequired && !hasImage ? 1.5 : 1,
              ),
            ),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.file(
                          File(imagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.background.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 24,
                        color: isRequired
                            ? AppColors.statusLocked.withValues(alpha: 0.7)
                            : AppColors.textDisabled,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRequired ? 'Wajib' : 'Opsional',
                        style: TextStyle(
                          fontSize: 9,
                          color: isRequired
                              ? AppColors.statusLocked.withValues(alpha: 0.7)
                              : AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 2),
              const Text('*',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.statusLocked)),
            ],
          ],
        ),
      ],
    );
  }
}
