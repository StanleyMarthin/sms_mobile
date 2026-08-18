/*
Tujuan: Bottom sheet detail eksekusi task dengan layout horizontal (Label: Value) dan tanpa rendutan berlebih.
Caller: TaskCard dan ViewTaskCard.
Dependensi: AppColors.
Main Functions: TaskExecutionDetailSheet.show.
Side Effects: Render modal UI.
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
    this.planTotalDuration,
    this.planRemainingDuration,
    required this.actualStartTime,
    required this.actualFinishTime,
    required this.actualDuration,
    this.actualWorkedTotal,
    required this.progress,
    required this.status,
    required this.category,
    this.operatorName,
    this.instruction,
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
  final String? planTotalDuration;
  final String? planRemainingDuration;
  final String actualStartTime;
  final String actualFinishTime;
  final String actualDuration;
  final String? actualWorkedTotal;
  final double progress;
  final String status;
  final String category;
  final String? operatorName;
  final String? instruction;
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
    String? planTotalDuration,
    String? planRemainingDuration,
    required String actualStartTime,
    required String actualFinishTime,
    required String actualDuration,
    String? actualWorkedTotal,
    required double progress,
    required String status,
    required String category,
    String? operatorName,
    String? instruction,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
        planTotalDuration: planTotalDuration,
        planRemainingDuration: planRemainingDuration,
        actualStartTime: actualStartTime,
        actualFinishTime: actualFinishTime,
        actualDuration: actualDuration,
        actualWorkedTotal: actualWorkedTotal,
        progress: progress,
        status: status,
        category: category,
        operatorName: operatorName,
        instruction: instruction,
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
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // slim handle
          Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),

          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _metaChip(Icons.flag_rounded, status.toUpperCase()),
                _metaChip(Icons.category_rounded, category.toUpperCase()),
                if (isOvertime) _metaChip(Icons.nights_stay_rounded, 'LEMBUR'),
                if (isRework) _metaChip(Icons.refresh_rounded, 'REWORK'),
              ],
            ),
          ),

          SizedBox(height: 20),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (operatorName != null) _row('Pelaksana', operatorName!),
                  _row('Unit', unitName),
                  _row('Panel', panelName),
                  _row('Divisi', divisionName),
                  _row('Tanggal Kerja', taskDate),

                  Divider(color: AppColors.border, height: 24),

                  _row('Jobdesc', jobName),
                  if (description.isNotEmpty && description != jobName)
                    _row('Deskripsi', description),
                  if (instruction != null && instruction!.isNotEmpty)
                    _row('Instruksi / SPOK', instruction!),

                  Divider(color: AppColors.border, height: 24),

                  _sectionHeader('RENCANA (PLAN)'),
                  _row('Jam Kerja', '$planStartTime - $planFinishTime'),
                  _row('Target Harian', planDuration),
                  if (planTotalDuration != null &&
                      planTotalDuration!.isNotEmpty)
                    _row('Target Total', planTotalDuration!),
                  if (planRemainingDuration != null &&
                      planRemainingDuration!.isNotEmpty)
                    _row('Sisa Target', planRemainingDuration!),

                  SizedBox(height: 8),

                  _sectionHeader('AKTUAL (REALTIME)'),
                  _row('Mulai', actualStartTime),
                  _row('Selesai', actualFinishTime),
                  _row('Durasi Sesi', actualDuration),
                  if (actualWorkedTotal != null &&
                      actualWorkedTotal!.isNotEmpty)
                    _row('Akumulasi', actualWorkedTotal!),
                  _row('Progress', '${progress.toInt()}%'),

                  if (checkpoints.isNotEmpty) ...[
                    Divider(color: AppColors.border, height: 32),
                    _sectionHeader('RIWAYAT MONITORING'),
                    ...checkpoints.map((cp) => _checkpointRow(cp)),
                  ],

                  if (actions != null) ...[
                    SizedBox(height: 20),
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

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 3, height: 12, color: AppColors.gold),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.gold),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkpointRow(Map<String, dynamic> cp) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Progress: ${cp['progress']}% • ${cp['status']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
