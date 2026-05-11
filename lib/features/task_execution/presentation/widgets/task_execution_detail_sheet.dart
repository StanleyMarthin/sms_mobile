/*
Tujuan: Bottom sheet detail eksekusi task untuk menampilkan ringkasan plan, aktual, dan aksi terkait task.
Caller: TaskCard dan widget presentasi task execution lain yang perlu membuka detail pengerjaan.
Dependensi: AppColors, showModalBottomSheet.
Main Functions: TaskExecutionDetailSheet, TaskExecutionDetailSheet.show.
Side Effects: Membuka modal bottom sheet di UI.
*/
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class TaskExecutionDetailSheet extends StatelessWidget {
  const TaskExecutionDetailSheet({
    super.key,
    required this.title,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    required this.description,
    required this.divisionName,
    required this.taskDate,
    required this.planStartTime,
    required this.planFinishTime,
    required this.planDuration,
    required this.actualStartTime,
    required this.actualFinishTime,
    required this.actualDuration,
    required this.progress,
    required this.status,
    required this.category,
    this.operatorName,
    this.isOvertime = false,
    this.isRework = false,
    this.isPriority = false,
    this.checkpoints = const [],
    this.actions,
  });

  final String title;
  final String unitName;
  final String panelName;
  final String jobName;
  final String description;
  final String divisionName;
  final String taskDate;
  final String planStartTime;
  final String planFinishTime;
  final String planDuration;
  final String actualStartTime;
  final String actualFinishTime;
  final String actualDuration;
  final double progress;
  final String status;
  final String category;
  final String? operatorName;
  final bool isOvertime;
  final bool isRework;
  final bool isPriority;
  final List<Map<String, dynamic>> checkpoints;
  final Widget? actions;

  static void show({
    required BuildContext context,
    required String title,
    required String unitName,
    required String panelName,
    required String jobName,
    required String description,
    required String divisionName,
    required String taskDate,
    required String planStartTime,
    required String planFinishTime,
    required String planDuration,
    required String actualStartTime,
    required String actualFinishTime,
    required String actualDuration,
    required double progress,
    required String status,
    required String category,
    String? operatorName,
    bool isOvertime = false,
    bool isRework = false,
    bool isPriority = false,
    List<Map<String, dynamic>> checkpoints = const [],
    Widget? actions,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TaskExecutionDetailSheet(
        title: title,
        unitName: unitName,
        panelName: panelName,
        jobName: jobName,
        description: description,
        divisionName: divisionName,
        taskDate: taskDate,
        planStartTime: planStartTime,
        planFinishTime: planFinishTime,
        planDuration: planDuration,
        actualStartTime: actualStartTime,
        actualFinishTime: actualFinishTime,
        actualDuration: actualDuration,
        progress: progress,
        status: status,
        category: category,
        operatorName: operatorName,
        isOvertime: isOvertime,
        isRework: isRework,
        isPriority: isPriority,
        checkpoints: checkpoints,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(Icons.flag_rounded, status.toUpperCase()),
              _metaChip(Icons.category_rounded, category.toUpperCase()),
              if (isOvertime) _metaChip(Icons.nights_stay_rounded, 'LEMBUR'),
              if (isRework) _metaChip(Icons.refresh_rounded, 'REWORK'),
              if (isPriority) _metaChip(Icons.priority_high_rounded, 'PRIORITY'),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (operatorName != null)
                    _detailField('Pelaksana', operatorName!),
                  _detailField('Unit', unitName),
                  _detailField('Panel', panelName),
                  _detailField('Job', jobName),
                  _detailField('Divisi', divisionName),
                  _detailField('Tanggal Kerja', taskDate),
                  const Divider(color: AppColors.border, height: 32),
                  
                  const Text(
                    'RENCANA (PLAN)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _detailField('Jam Kerja', '$planStartTime - $planFinishTime'),
                      ),
                      Expanded(
                        child: _detailField('Target Jam', planDuration),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'AKTUAL (REALTIME)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _detailField('Mulai', actualStartTime),
                      ),
                      Expanded(
                        child: _detailField('Selesai', actualFinishTime),
                      ),
                    ],
                  ),
                  _detailField('Durasi Kerja', actualDuration),
                  _detailField('Progress', '${progress.toStringAsFixed(0)}%'),

                  const Divider(color: AppColors.border, height: 32),
                  if (description.isNotEmpty)
                    _detailField('Deskripsi / Jobdesc', description),

                  if (checkpoints.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'RIWAYAT MONITORING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...checkpoints.map((cp) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, right: 12),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.gold,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sesi ${cp['session']} • ${cp['time']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Progress: ${cp['progress']}% • Status: ${cp['status']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],

                  if (actions != null) ...[
                    const SizedBox(height: 32),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 20),
                    actions!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
