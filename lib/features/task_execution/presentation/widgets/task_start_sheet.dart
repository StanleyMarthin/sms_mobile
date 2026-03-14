import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_entity.dart';

/// Simple bottom sheet for **Step 1: Mulai Pekerjaan**.
///
/// Only captures:
/// - Start time (auto-filled with current time, editable)
/// - Photo Before (optional)
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
  String? _photoBeforePath;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _startTime = TimeOfDay.now();
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
                'Ambil foto kondisi sebelum mulai (opsional)',
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
    final timeStr =
        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: _pickStartTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.login, size: 18, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start Time',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 18,
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
    }
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
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _photoBeforePath = null),
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
      setState(() => _photoBeforePath = picked.path);
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
