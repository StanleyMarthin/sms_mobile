/*
Tujuan: Sheet update progress task mekanik dengan detail task, waktu kerja, progress kumulatif, dan dokumentasi.
Caller: TaskListPage saat task mulai dikerjakan atau dilanjutkan dari draft.
Dependensi: AppColors, TimeParser, InAppCameraPage, TaskDraft, TaskEntity, TaskExecutionLog, TaskExecutionFlowHelper.
Main Functions: show, initState, _taskInfoCard, _showConfirmation, _doSubmit, _workedHoursBreakdown.
Side Effects: Membuka kamera, menyimpan draft lokal via callback, dan submit log eksekusi ke bloc.
*/
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/clock_time_input.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/time_parser.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/entities/task_execution_log.dart';
import '../utils/task_execution_flow_helper.dart';

class TaskExecutionSheet extends StatefulWidget {
  final TaskEntity task;
  final TaskDraft? draft;
  final List<TaskEntity> otherTasks;
  final void Function(TaskExecutionLog log) onSubmit;
  final void Function(TaskDraft draft)? onDraftSave;

  const TaskExecutionSheet({
    super.key,
    required this.task,
    this.draft,
    this.otherTasks = const [],
    required this.onSubmit,
    this.onDraftSave,
  });

  /// Show this sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required TaskEntity task,
    TaskDraft? draft,
    List<TaskEntity> otherTasks = const [],
    required void Function(TaskExecutionLog log) onSubmit,
    void Function(TaskDraft draft)? onDraftSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskExecutionSheet(
        task: task,
        draft: draft,
        otherTasks: otherTasks,
        onSubmit: onSubmit,
        onDraftSave: onDraftSave,
      ),
    );
  }

  @override
  State<TaskExecutionSheet> createState() => _TaskExecutionSheetState();
}

class _TaskExecutionSheetState extends State<TaskExecutionSheet> {
  late TimeOfDay _startTime;
  late TimeOfDay _finishTime;
  late int _breakMinutes;
  double _progressPercent = 0;
  String _status = 'pending';
  bool _hasManualProgressOverride = false;
  bool _followSystemProgress = true;

  final _notesController = TextEditingController();
  final _breakController = TextEditingController();
  final _progressController = TextEditingController(text: '0');

  String? _photoBeforePath;
  String? _photoProcessPath;
  String? _photoAfterPath;

  bool _isSubmitting = false;
  late String _breakOption;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _breakMinutes = 0;
    _breakOption = '0';
    _breakController.text = '0';

    final draft = widget.draft;
    if (draft != null) {
      final draftStart = _parseTimeFromIso(draft.startTime);
      _startTime =
          draftStart ?? _parseTimeFromIso(widget.task.startedAt) ?? now;
      _finishTime = now;
      _photoBeforePath = draft.photoBeforePath;
      if (draft.photoProcessPath != null) {
        _photoProcessPath = draft.photoProcessPath;
      }
      if (draft.photoAfterPath != null) {
        _photoAfterPath = draft.photoAfterPath;
      }
      if (draft.notes != null) {
        _notesController.text = draft.notes!;
      }

      if (draft.progressPercent != null) {
        _hasManualProgressOverride = true;
        _followSystemProgress = false;
        _progressPercent = draft.progressPercent!.clamp(0.0, 100.0);
      } else {
        _progressPercent = _computeRealtimeProgressPercent();
      }
      _status = _progressPercent >= 100 ? 'done' : 'pending';
    } else if (widget.task.isInProgress) {
      _startTime = _parseTimeFromIso(widget.task.startedAt) ?? now;
      _finishTime = now;
      _progressPercent = _computeRealtimeProgressPercent();
      _status = _progressPercent >= 100 ? 'done' : 'pending';
    } else {
      _startTime = now;
      _finishTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute);
      _progressPercent = 0;
      _status = 'pending';
    }

    _progressController.text = _progressPercent.toInt().toString();
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
    return TimeOfDay(hour: nextMinutes ~/ 60, minute: nextMinutes % 60);
  }

  double get _totalTargetHours {
    if (widget.task.targetHoursRevised > 0) {
      return widget.task.targetHoursRevised;
    }
    if (widget.task.dailyTargetHours > 0) {
      return widget.task.dailyTargetHours;
    }
    return 1.0;
  }

  double get _recordedWorkedHours {
    return widget.task.totalActualHours.clamp(0.0, _totalTargetHours);
  }

  double _computeCurrentSessionHours() {
    return TaskExecutionFlowHelper.computeSessionHours(
      startTime: _startTime,
      finishTime: _finishTime,
      breakDurationMinutes: _breakMinutes,
    );
  }

  double _computeRealtimeProgressPercent() {
    return TaskExecutionFlowHelper.computeRealtimeProgressPercent(
      recordedWorkedHours: _recordedWorkedHours,
      currentSessionHours: _computeCurrentSessionHours(),
      totalTargetHours: _totalTargetHours,
    );
  }

  void _refreshProgressFromRealtime() {
    if (_hasManualProgressOverride) return;
    final realtimeProgress = _computeRealtimeProgressPercent();
    _progressPercent = realtimeProgress;
    _status = realtimeProgress >= 100 ? 'done' : 'pending';
    _progressController.text = realtimeProgress.toInt().toString();
  }

  TaskExecutionWorkedHoursBreakdown _workedHoursBreakdown() {
    return TaskExecutionFlowHelper.splitWorkedHours(
      taskDate: widget.task.taskDate,
      startTime: _startTime,
      finishTime: _finishTime,
      breakDurationMinutes: _breakMinutes,
    );
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'done':
        return 'Selesai';
      case 'on_progress':
        return 'On Progress';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Future<void> _handleBreakSelection(String value) async {
    if (value == 'manual') {
      final manualMinutes = await _showManualBreakDialog();
      if (manualMinutes == null) return;
      setState(() {
        _breakOption = 'manual';
        _breakMinutes = manualMinutes;
        _breakController.text = manualMinutes.toString();
        _refreshProgressFromRealtime();
      });
      return;
    }

    setState(() {
      _breakOption = value;
      if (value == '0') {
        _breakMinutes = 0;
      } else if (value == '1:00') {
        _breakMinutes = 60;
      } else if (value == '1:30') {
        _breakMinutes = 90;
      }
      _breakController.text = _breakMinutes.toString();
      _refreshProgressFromRealtime();
    });
  }

  Future<int?> _showManualBreakDialog() async {
    final controller = TextEditingController(
      text: _breakMinutes > 0 ? _breakMinutes.toString() : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Input Jam Istirahat',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            labelText: 'Menit',
            labelStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _persistDraftSnapshot() {
    final onDraftSave = widget.onDraftSave;
    if (onDraftSave == null) return;

    final now = DateTime.now();
    final startDt = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime.hour,
      _startTime.minute,
    );

    onDraftSave(
      TaskDraft(
        plandailyId: widget.task.plandailyId,
        startTime: TimeParser.formatIsoWithOffset(startDt),
        photoBeforePath: _photoBeforePath,
        photoProcessPath: _photoProcessPath,
        photoAfterPath: _photoAfterPath,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        progressPercent: _progressPercent,
        createdAt: widget.draft?.createdAt ?? now.toIso8601String(),
      ),
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
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.gold, width: 2)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _dragHandle(),
              SizedBox(height: 8),
              _header(),
              SizedBox(height: 20),

              // Section 1: Informasi Task
              _sectionLabel('Informasi Task', Icons.info_outline),
              SizedBox(height: 10),
              _taskInfoCard(),
              SizedBox(height: 24),

              // Section 2: Waktu Kerja
              _sectionLabel('Waktu Kerja', Icons.schedule),
              SizedBox(height: 10),
              _timeAndBreakRow(),
              SizedBox(height: 24),

              // Section 3: Progress Pekerjaan
              _sectionLabel('Progress Pekerjaan', Icons.trending_up),
              SizedBox(height: 10),
              _progressAndStatusRow(),
              SizedBox(height: 24),

              // Section 4: Dokumentasi
              _sectionLabel('Dokumentasi', Icons.camera_alt_outlined),
              SizedBox(height: 4),
              Text(
                'Foto progress dipakai saat onprogres. Foto after dipakai saat done.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              SizedBox(height: 10),
              _photoRow(),
              SizedBox(height: 24),

              // Section 5: Catatan
              _sectionLabel('Catatan', Icons.note_alt_outlined),
              SizedBox(height: 10),
              _notesField(),
              SizedBox(height: 28),

              // Submit
              _submitButton(),
              SizedBox(height: 16),
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
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Selesaikan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, color: AppColors.textMuted, size: 22),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // SECTION 1: INFORMASI TASK
  // ─────────────────────────────────────────────────────

  Widget _taskInfoCard() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoTile(
            icon: Icons.work_outline,
            title: 'Job',
            value: widget.task.jobName,
          ),
          SizedBox(height: 14),
          _infoTile(
            icon: Icons.assignment_outlined,
            title: 'Instruksi / SPOK',
            value: widget.task.instruction ?? '-',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // SECTION 2: WAKTU KERJA
  // ─────────────────────────────────────────────────────

  Widget _timeAndBreakRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClockTimeInput(
                labelText: 'Jam Mulai',
                initialTime: _startTime,
                onChanged: (t) {
                  setState(() {
                    _startTime = t;
                    _finishTime = _nextValidFinishTime(_startTime, _finishTime);
                    _refreshProgressFromRealtime();
                  });
                },
                onTapIcon: () => _pickTime(isStart: true),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ClockTimeInput(
                labelText: 'Jam Selesai',
                initialTime: _finishTime,
                onChanged: (t) {
                  setState(() {
                    _finishTime = _nextValidFinishTime(_startTime, t);
                    _refreshProgressFromRealtime();
                  });
                },
                onTapIcon: () => _pickTime(isStart: false),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        _breakRowFull(),
      ],
    );
  }

  Widget _breakRowFull() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: PopupMenuButton<String>(
        onSelected: _handleBreakSelection,
        color: AppColors.surfaceCard,
        offset: Offset(0, 40),
        itemBuilder: (context) => [
          PopupMenuItem(value: '0', child: Text('Tanpa Break')),
          PopupMenuItem(value: '1:00', child: Text('60 menit')),
          PopupMenuItem(value: '1:30', child: Text('90 menit')),
          PopupMenuItem(value: 'manual', child: Text('Input Manual')),
        ],
        child: Row(
          children: [
            Icon(
              Icons.coffee_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 10),
            Text(
              'Istirahat',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            Spacer(),
            Text(
              _breakLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.gold,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _finishTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
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
          _finishTime = _nextValidFinishTime(_startTime, _finishTime);
        } else {
          _finishTime = _nextValidFinishTime(_startTime, picked);
        }
        _refreshProgressFromRealtime();
      });
    }
  }

  String get _breakLabel {
    if (_breakOption == 'manual') {
      return '$_breakMinutes menit';
    }
    switch (_breakOption) {
      case '1:00':
        return '60 menit';
      case '1:30':
        return '90 menit';
      default:
        return 'Tanpa Break';
    }
  }

  Widget _progressAndStatusRow() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _progressModeChip(
                label: 'Otomatis',
                active: _followSystemProgress,
                onTap: () {
                  setState(() {
                    _followSystemProgress = true;
                    _hasManualProgressOverride = false;
                    _refreshProgressFromRealtime();
                  });
                },
              ),
              const SizedBox(width: 8),
              _progressModeChip(
                label: 'Isi Manual',
                active: !_followSystemProgress,
                onTap: () {
                  setState(() {
                    _followSystemProgress = false;
                    _hasManualProgressOverride = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Persentase selesai',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Spacer(),
              _compactProgressInput(),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _progressPercent / 100,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                _progressPercent >= 100 ? AppColors.statusDone : AppColors.gold,
              ),
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              _statusChip('pending', 'Pending'),
              SizedBox(width: 8),
              _statusChip('on_progress', 'On Progress'),
              SizedBox(width: 8),
              _statusChip('done', 'Selesai'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactProgressInput() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: TextField(
            controller: _progressController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.gold),
              ),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v) ?? 0;
              setState(() {
                _followSystemProgress = false;
                _hasManualProgressOverride = true;
                _progressPercent = parsed.clamp(0, 100).toDouble();
                if (_progressPercent >= 100) {
                  _status = 'done';
                } else if (_status == 'done') {
                  _status = 'pending';
                }
              });
            },
          ),
        ),
        SizedBox(width: 4),
        Text(
          '%',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _statusChip(String value, String label) {
    final isActive = _status == value;
    Color bgColor = AppColors.background;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.textMuted;

    if (isActive) {
      switch (value) {
        case 'pending':
          bgColor = AppColors.isLight
              ? Color(0xFFECEFF4)
              : Color(0xFF1A1A2E);
          borderColor = AppColors.isLight
              ? Color(0xFFB9C2D0)
              : Color(0xFF3A3A5C);
          textColor = AppColors.isLight
              ? Color(0xFF35688D)
              : AppColors.textSecondary;
          break;
        case 'on_progress':
          bgColor = AppColors.isLight
              ? Color(0xFFFFF3E6)
              : Color(0xFF2A1F00);
          borderColor = AppColors.isLight
              ? Color(0xFFF5C79B)
              : Color(0xFF7A5C00);
          textColor = AppColors.gold;
          break;
        case 'done':
          bgColor = AppColors.isLight
              ? Color(0xFFE7F2EA)
              : Color(0xFF0F2A0F);
          borderColor = AppColors.isLight
              ? Color(0xFFA8D3B6)
              : Color(0xFF1F5C1F);
          textColor = AppColors.statusDone;
          break;
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _followSystemProgress = false;
            _hasManualProgressOverride = true;
            _status = value;
            if (value == 'done' && _progressPercent < 100) {
              _progressPercent = 100;
              _progressController.text = '100';
            } else if (value == 'pending' && _progressPercent >= 100) {
              _progressPercent = 99;
              _progressController.text = '99';
            }
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressModeChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppColors.gold.withValues(alpha: 0.15)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? AppColors.gold : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.auto_awesome : Icons.edit_outlined,
            size: 13,
            color: active ? AppColors.gold : AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.gold : AppColors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );

  // ─────────────────────────────────────────────────────
  // SECTION 4: DOKUMENTASI
  // ─────────────────────────────────────────────────────

  Widget _photoRow() {
    return Row(
      children: [
        Expanded(
          child: _PhotoSlot(
            label: 'Process',
            imagePath: _photoProcessPath,
            isRequired: false,
            onPick: () => _pickPhoto('process'),
            onRemove: () => setState(() => _photoProcessPath = null),
          ),
        ),
        SizedBox(width: 10),
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
    final label = type == 'before'
        ? 'Foto Before'
        : type == 'process'
        ? 'Foto Progress'
        : 'Foto After';

    // Open In-App Camera (no OOM risk)
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => InAppCameraPage(slot: type, label: label),
        fullscreenDialog: true,
      ),
    );

    if (!mounted || path == null) return;

    setState(() {
      switch (type) {
        case 'before':
          _photoBeforePath = path;
          break;
        case 'process':
          _photoProcessPath = path;
          break;
        case 'after':
          _photoAfterPath = path;
          break;
      }
    });
    _persistDraftSnapshot();
  }

  // ─────────────────────────────────────────────────────
  // SECTION 5: CATATAN
  // ─────────────────────────────────────────────────────

  Widget _notesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Tulis catatan harian (opsional)...',
        hintStyle: TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surfaceInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.gold),
        ),
        contentPadding: EdgeInsets.all(14),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // VALIDATION + SUBMIT
  // ─────────────────────────────────────────────────────

  String? _validate() {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final finishMin = _finishTime.hour * 60 + _finishTime.minute;
    final hasProcessPhoto =
        _photoProcessPath != null && _photoProcessPath!.isNotEmpty;
    final hasAfterPhoto =
        _photoAfterPath != null && _photoAfterPath!.isNotEmpty;
    final isDone = _progressPercent >= 100 || _status == 'done';

    if (finishMin <= startMin) {
      return 'Finish time harus lebih dari start time';
    }

    for (final other in widget.otherTasks) {
      final otherStart = TimeParser.parseTimeOfDay(other.startTime);
      final otherFinish = TimeParser.parseTimeOfDay(other.targetFinishTime);
      if (otherStart == null || otherFinish == null) continue;
      final os = otherStart.hour * 60 + otherStart.minute;
      final of = otherFinish.hour * 60 + otherFinish.minute;
      if (startMin < of && finishMin > os) {
        final label = other.jobDescription.isNotEmpty
            ? other.jobDescription
            : other.jobName;
        return 'Jam kerja bentrok dengan "$label" '
            '(${other.startTime} - ${other.targetFinishTime}). '
            'Pilih jam yang tidak tumpang tindih.';
      }
    }

    if (isDone && !hasAfterPhoto) {
      return 'Foto After belum diambil. Wajib diisi saat status selesai.';
    }

    if (!hasProcessPhoto && !hasAfterPhoto) {
      return 'Foto belum diambil. Isi minimal Foto Process atau Foto After.';
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
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.background,
                ),
              )
            : Icon(Icons.send, size: 20),
        label: Text(
          _isSubmitting
              ? 'Mengirim...'
              : (isDone ? 'Submit Selesai' : 'Simpan & Lanjut Besok'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isDone ? AppColors.statusDone : AppColors.gold,
          foregroundColor: AppColors.background,
          padding: EdgeInsets.symmetric(vertical: 14),
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
    final breakdown = _workedHoursBreakdown();
    final effectiveStatus = TaskExecutionFlowHelper.resolveSubmitStatus(
      selectedStatus: _status,
      progressPercent: _progressPercent,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
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
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (_breakMinutes > 0)
              Text(
                'Break: $_breakMinutes menit',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            Text(
              'Progress: ${_progressPercent.toInt()}%  •  Status: ${_statusLabel(effectiveStatus)}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              'Jam kerja: ${breakdown.totalWorkedHours.toStringAsFixed(2)}j  •  Normal ${breakdown.normalHours.toStringAsFixed(2)}j  •  OT ${breakdown.overtimeHours.toStringAsFixed(2)}j',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Yakin data sudah benar?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textMuted),
            ),
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
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _doSubmit() {
    setState(() => _isSubmitting = true);

    final effectiveStatus = TaskExecutionFlowHelper.resolveSubmitStatus(
      selectedStatus: _status,
      progressPercent: _progressPercent,
    );
    final startDt = TaskExecutionFlowHelper.buildTaskDateTime(
      taskDate: widget.task.taskDate,
      time: _startTime,
    );
    final finishDt = TaskExecutionFlowHelper.buildTaskDateTime(
      taskDate: widget.task.taskDate,
      time: _finishTime,
    );

    final log = TaskExecutionLog(
      plandailyId: widget.task.plandailyId,
      startTime: TimeParser.formatIsoWithOffset(startDt),
      finishTime: TimeParser.formatIsoWithOffset(finishDt),
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
                          cacheWidth: 360,
                          cacheHeight: 360,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(
                                alpha: 0.7,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: AppColors.textPrimary,
                            ),
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
                      SizedBox(height: 4),
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
        SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: 2),
              Text(
                '*',
                style: TextStyle(fontSize: 11, color: AppColors.statusLocked),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
