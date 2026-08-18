/*
Tujuan: Bottom sheet detail countdown dengan ringkasan progres, detail jobdesc, dan shortcut pembuatan plan.
Caller: Countdown pages dan grouped monitoring pages.
Dependensi: AppColors, CountdownRepository, JobPlanRepository, CountdownDialogs.
Main Functions: build, _buildHeader, _buildInfoGrid.
Side Effects: Membuka dialog create plan dan memicu refresh parent saat plan dibuat.
*/
library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_message.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../pages/grouped_monitoring_pages.dart';
import '../utils/countdown_helper.dart';
import 'countdown_dialogs.dart';
import 'countdown_shared.dart';

/// Bottom sheet for reviewing and acting on a [CountdownJobdesc].
///
/// Used by KD to create plans, submit revisions, or declare completion.
class CountdownDetailSheet extends StatelessWidget {
  const CountdownDetailSheet._({
    required this.item,
    required this.unit,
    required this.allUnitItems,
    required this.isPm,
    required this.repository,
    required this.jobPlanRepository,
    required this.qcIdsByCoreId,
    required this.onPlanCreated,
    required this.onRevisionRequested,
    this.initialDate,
    this.onDeclared,
  });

  final CountdownJobdesc item;
  final CountdownUnit unit;
  final List<CountdownJobdesc> allUnitItems;
  final bool isPm;
  final CountdownRepository repository;
  final JobPlanRepository jobPlanRepository;
  final Map<String, String> qcIdsByCoreId;
  final VoidCallback onPlanCreated;
  final VoidCallback onRevisionRequested;
  final DateTime? initialDate;
  final VoidCallback? onDeclared;

  /// Show the detail sheet modally.
  static void show({
    required BuildContext context,
    required CountdownJobdesc item,
    required CountdownUnit unit,
    required List<CountdownJobdesc> allUnitItems,
    required bool isPm,
    required CountdownRepository repository,
    required JobPlanRepository jobPlanRepository,
    required Map<String, String> qcIdsByCoreId,
    required VoidCallback onPlanCreated,
    required VoidCallback onRevisionRequested,
    DateTime? initialDate,
    VoidCallback? onDeclared,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountdownDetailSheet._(
        item: item,
        unit: unit,
        allUnitItems: allUnitItems,
        isPm: isPm,
        repository: repository,
        jobPlanRepository: jobPlanRepository,
        qcIdsByCoreId: qcIdsByCoreId,
        onPlanCreated: onPlanCreated,
        onRevisionRequested: onRevisionRequested,
        initialDate: initialDate,
        onDeclared: onDeclared,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = CountdownHelper.effectiveCountdownStatus(
      item,
    ).toUpperCase();
    final isDone = CountdownHelper.isWorkCompleted(item);
    final revisionBanner = CountdownHelper.revisionStatusBanner(item);
    final hasActiveRevision =
        item.revisionRequestStatus?.toUpperCase() == 'REQUESTED';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 14),

          // ── Header ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.panelName} • ${item.sectionName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  item.jobdesc,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    CountdownStatusChip(status: effectiveStatus),
                    SizedBox(width: 8),
                    Text(
                      '${item.progress}% • DL ${item.deadlineDate}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (revisionBanner != null) ...[
                  RevisionStatusBanner(banner: revisionBanner),
                  SizedBox(height: 8),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 4),

          // ── Info rows ──
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoRow('Task Category', item.taskCategory),
                  _infoRow(
                    'Target Jam',
                    item.targetHoursRevisedAlias ??
                        CountdownHelper.formatWorkHours(
                          item.targetHoursRevised,
                        ),
                  ),
                  _infoRow(
                    'Terpakai',
                    CountdownHelper.formatWorkHours(item.totalActualHours),
                  ),
                  _infoRow(
                    'Tersisa',
                    item.remainingHoursAlias ??
                        CountdownHelper.formatWorkHours(item.remainingHours),
                  ),
                  _infoRow('Mulai', item.startDate),
                  _infoRow('Deadline', item.deadlineDate),
                  if (item.qcLastStatus != null)
                    _infoRow('QC Status', item.qcLastStatus!),

                  SizedBox(height: 16),
                  Divider(color: AppColors.border),
                  SizedBox(height: 12),

                  // ── Actions ──
                  if (!isPm) ...[
                    // Create Plan button
                    if (!isDone)
                      FilledButton.icon(
                        onPressed: () async {
                          final created =
                              await CountdownDialogs.showCreatePlanDialog(
                                context: context,
                                item: item,
                                unit: unit,
                                allUnitItems: allUnitItems,
                                jobPlanRepository: jobPlanRepository,
                                availablePlanHours:
                                    item.availablePlanHoursAlias != null ||
                                        item.reservedPlanHours > 0
                                    ? item.availablePlanHours
                                    : item.remainingHours,
                                initialDate: initialDate,
                              );
                          if (created) {
                            if (context.mounted) Navigator.pop(context);
                            onPlanCreated();
                          }
                        },
                        icon: Icon(Icons.add_task_rounded),
                        label: Text('Buat Job Plan'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.background,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                    SizedBox(height: 8),

                    // Declare complete button
                    if (!isDone)
                      FilledButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await CountdownDialogs.showDeclareCompleteDialog(
                                context: context,
                                item: item,
                              );
                          if (confirmed) {
                            try {
                              await repository.markAsQcReady(item.id);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Status berhasil diubah ke Menunggu QC.',
                                    ),
                                  ),
                                );
                              }
                              onDeclared?.call();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      friendlyMessage(
                                        e,
                                        fallback: 'Gagal menyelesaikan item',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: Icon(Icons.verified_outlined),
                        label: Text('Nyatakan Selesai (QC Ready)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.statusDone,
                          foregroundColor: AppColors.background,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                    SizedBox(height: 8),

                    // Revision request button
                    if (!isDone && !hasActiveRevision)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final submitted =
                              await CountdownDialogs.showCountdownRevisionDialog(
                                context: context,
                                item: item,
                              );
                          if (submitted) {
                            if (context.mounted) Navigator.pop(context);
                            onRevisionRequested();
                          }
                        },
                        icon: Icon(Icons.update_rounded),
                        label: Text('Ajukan Revisi Countdown'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.orange,
                          side: BorderSide(
                            color: AppColors.orange.withValues(alpha: 0.5),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    SizedBox(height: 8),

                    // View History button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PmJobdescActualPage(
                              unit: unit,
                              item: item,
                              repository: repository,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.history_rounded),
                      label: Text('Lihat Riwayat Pekerjaan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: AppColors.textPrimary.withValues(alpha: 0.3),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                  if (isPm) ...[
                    Text(
                      'Mode PM: Anda dapat melihat detail aktual pada halaman countdown.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
