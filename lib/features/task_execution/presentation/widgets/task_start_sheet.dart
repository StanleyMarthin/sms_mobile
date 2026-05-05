import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/time_parser.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_entity.dart';

/// Simple bottom sheet for **Step 1: Mulai Pekerjaan**.
///
/// Only captures:
/// - Start time (auto-filled with current time, editable)
/// - Photo Before (required by backend)
///
/// On "Mulai", creates a [TaskDraft] and passes it to [onStart].
/// This draft is saved locally — NO API call at this step.
class TaskStartSheet extends StatefulWidget {
  final TaskEntity task;
  final void Function(TaskDraft draft) onStart;

  const TaskStartSheet({
    super.key,
    required this.task,
    required this.onStart,
  });

  /// Show as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required TaskEntity task,
    required void Function(TaskDraft draft) onStart,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskStartSheet(task: task, onStart: onStart),
    );
  }

  @override
  State<TaskStartSheet> createState() => _TaskStartSheetState();
}

class _TaskStartSheetState extends State<TaskStartSheet> {
  late TimeOfDay _startTime;
  late final TextEditingController _startTimeCtrl;
  bool _syncingStartTime = false;
  String? _photoBeforePath;

  String? _safeCurrentRoute() {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return ModalRoute.of(context)?.settings.name;
    }
  }

  @override
  void initState() {
    super.initState();
    _startTime = TimeOfDay.now();
    _startTimeCtrl = TextEditingController(text: _formatTime(_startTime));
    _startTimeCtrl.addListener(_handleStartTimeChanged);
  }

  @override
  void dispose() {
    _startTimeCtrl.removeListener(_handleStartTimeChanged);
    _startTimeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.8,
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
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Row(
                children: [
                  const Icon(Icons.play_circle_outline,
                      color: AppColors.gold, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mulai Pekerjaan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: AppColors.textMuted, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Task info
              _taskInfoCard(),
              const SizedBox(height: 20),

              // Start time
              _sectionLabel('Jam Mulai', Icons.schedule),
              const SizedBox(height: 10),
              _startTimeTile(),
              const SizedBox(height: 20),

              // Photo before
              _sectionLabel('Foto Before', Icons.camera_alt_outlined),
              const SizedBox(height: 4),
              const Text(
                'Ambil foto kondisi sebelum mulai.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              _photoBeforeSlot(),
              const SizedBox(height: 28),

              // Mulai button
              _startButton(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.unitName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.build_outlined,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${t.panelName} • ${t.jobName}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _startTimeTile() {
    return TextField(
      controller: _startTimeCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [HHMMFormatter()],
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: 'Jam Mulai',
        hintText: '08:00',
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
        suffixIcon: IconButton(
          onPressed: _pickStartTime,
          icon: const Icon(Icons.schedule_rounded, color: AppColors.gold),
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
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
      setState(() => _startTime = picked);
      _syncStartTimeController();
    }
  }

  void _handleStartTimeChanged() {
    if (_syncingStartTime) return;
    final parsed = TimeParser.parseTimeOfDay(_startTimeCtrl.text);
    if (parsed == null) return;
    if (parsed.hour == _startTime.hour && parsed.minute == _startTime.minute) {
      return;
    }
    setState(() => _startTime = parsed);
  }

  void _syncStartTimeController() {
    final value = _formatTime(_startTime);
    _syncingStartTime = true;
    _startTimeCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncingStartTime = false;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _photoBeforeSlot() {
    final hasImage = _photoBeforePath != null;
    return GestureDetector(
      onTap: hasImage ? null : _pickPhoto,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasImage
                ? AppColors.statusDone.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(
                      File(_photoBeforePath!),
                      cacheWidth: 360,
                      cacheHeight: 360,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _photoBeforePath = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 32, color: AppColors.textDisabled),
                  SizedBox(height: 6),
                  Text(
                    'Tap untuk ambil foto',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textDisabled),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final currentRoute = _safeCurrentRoute();

    // Save context before entering camera
    try {
      final prefs = await SharedPreferences.getInstance();
      String? targetRoute = currentRoute;
      if (targetRoute != null &&
          targetRoute.isNotEmpty &&
          !targetRoute.contains('taskId=')) {
        targetRoute += targetRoute.contains('?') ? '&' : '?';
        targetRoute += 'taskId=${widget.task.plandailyId}';
      }
      if (targetRoute != null && targetRoute.isNotEmpty) {
        await prefs.setString('pending_camera_route', targetRoute);
      }
      await prefs.setString('pending_camera_slot', 'before');
    } catch (_) {}
    if (!mounted) return;

    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const InAppCameraPage(
          slot: 'before',
          label: 'Foto Before (Sebelum Pekerjaan)',
        ),
        fullscreenDialog: true,
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_camera_slot');
    } catch (_) {}

    if (!mounted || path == null) return;
    setState(() => _photoBeforePath = path);
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _doStart,
        icon: const Icon(Icons.play_arrow, size: 20),
        label: const Text(
          'Mulai Pekerjaan',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _doStart() {
    if (_photoBeforePath == null || _photoBeforePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto wajib diambil sebelum mulai pekerjaan.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final startDt = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime.hour,
      _startTime.minute,
    );

    final draft = TaskDraft(
      plandailyId: widget.task.plandailyId,
      startTime: startDt.toIso8601String(),
      photoBeforePath: _photoBeforePath,
      createdAt: now.toIso8601String(),
    );

    widget.onStart(draft);
    Navigator.of(context).pop();
  }
}
