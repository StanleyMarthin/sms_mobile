import 'dart:async';

import 'package:flutter/material.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../../../core/constants/app_colors.dart';
import '../utils/countdown_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/time_parser.dart';

class CountdownDialogs {
  static Future<bool> showCreatePlanDialog({
    required BuildContext context,
    required CountdownJobdesc item,
    required CountdownUnit unit,
    required List<CountdownJobdesc> allUnitItems,
    required JobPlanRepository jobPlanRepository,
    required double availablePlanHours,
    DateTime? initialDate,
  }) async {
    final rootContext = context;
    final session = sl<SessionManager>();

    List<Map<String, dynamic>> employees = [];
    try {
      final String targetDivisionId = item.divisionId;
      final res = await sl<ApiClient>().get(
        ApiEndpoints.jobPlanDropdowns,
        queryParameters: targetDivisionId.isNotEmpty ? {'divisionId': targetDivisionId} : null,
      );
      final data = res.data['data'] ?? res.data;
      if (data != null && data['users'] is List) {
        employees = (data['users'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    if (employees.isEmpty) {
      if (rootContext.mounted) AppNotification.showError(rootContext, 'Gagal mengambil data anggota dari server.');
      return false;
    }

    employees.sort((a, b) => '${a['name'] ?? a['full_name'] ?? ''}'.compareTo('${b['name'] ?? b['full_name'] ?? ''}'));

    final comboCandidates = allUnitItems
        .where((i) => i.panelName == item.panelName && i.id != item.id && i.targetHoursRevised > 0)
        .toList();

    final selectedCombos = <CountdownJobdesc>{};
    String? selectedEmployeeId;
    String? selectedEmployeeName;

    double getTotalAvailableHours() {
      var total = availablePlanHours;
      for (final combo in selectedCombos) {
        total += combo.targetHoursRevised;
      }
      return total;
    }

    final hoursCtrl = TextEditingController(
      text: TimeParser.formatDecimalToHHmm(availablePlanHours > 0 ? availablePlanHours : item.targetHoursRevised),
    );
    final descriptionCtrl = TextEditingController();
    DateTime selectedDate = initialDate ?? DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay finishTime = CountdownHelper.calculateFinishTime(
      startTime: startTime,
      durationHours: availablePlanHours > 0 ? availablePlanHours : item.targetHoursRevised,
      date: selectedDate,
    );
    var finishTimeEdited = false;
    var isOvertime = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> openEmployeePicker() async {
            var q = '';
            await showModalBottomSheet<void>(
              context: ctx,
              isScrollControlled: true,
              backgroundColor: AppColors.surfaceCard,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (bsCtx) => StatefulBuilder(
                builder: (bsCtx, setBs) {
                  final filtered = employees.where((e) {
                    final name = ((e['name'] ?? e['full_name'] ?? '') as String).toLowerCase();
                    return name.contains(q.toLowerCase());
                  }).toList();
                  return SafeArea(
                    child: FractionallySizedBox(
                      heightFactor: 0.85,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(bsCtx).viewInsets.bottom),
                        child: Column(
                          children: [
                            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 14),
                            const Text('Pilih Pelaksana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            TextField(
                              autofocus: true,
                              onChanged: (v) => setBs(() => q = v),
                              decoration: const InputDecoration(
                                labelText: 'Cari nama...',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                                itemBuilder: (_, i) {
                                  final e = filtered[i];
                                  final name = (e['name'] ?? e['full_name'] ?? '-') as String;
                                  final grade = (e['grade'] ?? e['jabatan'] ?? '') as String;
                                  final isSel = e['id'] == selectedEmployeeId;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSel ? AppColors.gold : AppColors.surfaceInput,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: TextStyle(color: isSel ? AppColors.background : AppColors.textMuted, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    title: Text(name, style: TextStyle(color: AppColors.textPrimary, fontWeight: isSel ? FontWeight.w700 : FontWeight.normal)),
                                    subtitle: grade.isNotEmpty ? Text(grade, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)) : null,
                                    trailing: isSel ? const Icon(Icons.check_circle_rounded, color: AppColors.gold) : null,
                                    onTap: () {
                                      setSheet(() {
                                        selectedEmployeeId = e['id'] as String;
                                        selectedEmployeeName = name;
                                      });
                                      Navigator.pop(bsCtx);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }

          Widget sectionCard({required String title, required Widget child}) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceInput,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            );
          }

          Widget tapPill({required String label, required String value, required VoidCallback onTap, IconData icon = Icons.edit_calendar_rounded}) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.94),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Buat Job Plan', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              item.jobdesc,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Expanded(child: Text('${unit.unitName} • ${item.panelName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Sisa: ${TimeParser.formatDecimalToHHmm(availablePlanHours)} jam',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),

                // Form
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [

                      // Pelaksana
                      sectionCard(
                        title: 'PELAKSANA',
                        child: InkWell(
                          onTap: openEmployeePicker,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedEmployeeId != null ? AppColors.gold : AppColors.border,
                                width: selectedEmployeeId != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: selectedEmployeeId != null
                                      ? AppColors.gold.withValues(alpha: 0.15)
                                      : AppColors.surfaceInput,
                                  child: Icon(
                                    selectedEmployeeId != null ? Icons.person_rounded : Icons.person_add_rounded,
                                    size: 20,
                                    color: selectedEmployeeId != null ? AppColors.gold : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedEmployeeId != null ? 'Pelaksana' : 'Ketuk untuk memilih',
                                        style: TextStyle(fontSize: 11, color: selectedEmployeeId != null ? AppColors.gold : AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedEmployeeName ?? 'Pilih Pelaksana *',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: selectedEmployeeId != null ? AppColors.textPrimary : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Target Jam
                      sectionCard(
                        title: 'TARGET JAM PENGERJAAN',
                        child: TextField(
                          controller: hoursCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [HHHMMFormatter()],
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: '008:00',
                            helperText: 'Format HHH:MM  •  Maks: ${TimeParser.formatDecimalToHHmm(getTotalAvailableHours())}',
                            suffixIcon: const Icon(Icons.timer_outlined, color: AppColors.textMuted),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (val) {
                            final hrs = TimeParser.parseHHmmToDecimal(val);
                            if (hrs != null && hrs > 0) {
                              setSheet(() {
                                if (!finishTimeEdited) {
                                  finishTime = CountdownHelper.calculateFinishTime(
                                    startTime: startTime,
                                    durationHours: hrs,
                                    date: selectedDate,
                                  );
                                }
                                // Auto-detect overtime: finish after 17:00
                                isOvertime = CountdownHelper.isOvertimeByTime(finishTime);
                              });
                            }
                          },
                        ),
                      ),

                      // Jadwal
                      sectionCard(
                        title: 'JADWAL PELAKSANAAN',
                        child: Column(
                          children: [
                            tapPill(
                              label: 'Tanggal Pengerjaan',
                              value: CountdownHelper.formatDate(selectedDate),
                              icon: Icons.calendar_today_rounded,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2027),
                                );
                                if (picked != null) {
                                  final hrs = TimeParser.parseHHmmToDecimal(hoursCtrl.text);
                                  setSheet(() {
                                    selectedDate = picked;
                                    if (!finishTimeEdited && hrs != null && hrs > 0) {
                                      finishTime = CountdownHelper.calculateFinishTime(
                                        startTime: startTime,
                                        durationHours: hrs,
                                        date: selectedDate,
                                      );
                                    }
                                    isOvertime = CountdownHelper.isOvertimeByTime(finishTime);
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: tapPill(
                                  label: 'Jam Mulai',
                                  value: CountdownHelper.formatTime(startTime),
                                  icon: Icons.schedule_rounded,
                                  onTap: () async {
                                    final picked = await showTimePicker(context: ctx, initialTime: startTime);
                                    if (picked != null) {
                                      final hrs = TimeParser.parseHHmmToDecimal(hoursCtrl.text);
                                      setSheet(() {
                                        startTime = picked;
                                        if (!finishTimeEdited && hrs != null && hrs > 0) {
                                          finishTime = CountdownHelper.calculateFinishTime(
                                            startTime: startTime,
                                            durationHours: hrs,
                                            date: selectedDate,
                                          );
                                        }
                                        isOvertime = CountdownHelper.isOvertimeByTime(finishTime);
                                      });
                                    }
                                  },
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: tapPill(
                                  label: 'Jam Selesai',
                                  value: CountdownHelper.formatTime(finishTime),
                                  icon: Icons.schedule_rounded,
                                  onTap: () async {
                                    final picked = await showTimePicker(context: ctx, initialTime: finishTime);
                                    if (picked != null) setSheet(() { finishTime = picked; finishTimeEdited = true; isOvertime = CountdownHelper.isOvertimeByTime(finishTime); });
                                  },
                                )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => setSheet(() => isOvertime = !isOvertime),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isOvertime ? AppColors.orange.withValues(alpha: 0.08) : AppColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isOvertime ? AppColors.orange.withValues(alpha: 0.4) : AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.nights_stay_rounded, size: 18, color: isOvertime ? AppColors.orange : AppColors.textMuted),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text('Dikerjakan saat lembur', style: TextStyle(fontSize: 14, color: isOvertime ? AppColors.orange : AppColors.textPrimary, fontWeight: FontWeight.w500))),
                                    Switch.adaptive(value: isOvertime, onChanged: (v) => setSheet(() => isOvertime = v), activeColor: AppColors.orange),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Combo
                      if (comboCandidates.isNotEmpty)
                        sectionCard(
                          title: 'GABUNGKAN JOB PANEL SAMA (OPSIONAL)',
                          child: Column(
                            children: comboCandidates.map((combo) {
                              final isSel = selectedCombos.contains(combo);
                              return InkWell(
                                onTap: () => setSheet(() {
                                  if (isSel) {
                                    selectedCombos.remove(combo);
                                  } else {
                                    selectedCombos.add(combo);
                                  }
                                  hoursCtrl.text = TimeParser.formatDecimalToHHmm(getTotalAvailableHours());
                                  if (!finishTimeEdited) {
                                    finishTime = CountdownHelper.calculateFinishTime(
                                      startTime: startTime,
                                      durationHours: getTotalAvailableHours(),
                                      date: selectedDate,
                                    );
                                    isOvertime = CountdownHelper.isOvertimeByTime(finishTime);
                                  }
                                }),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSel ? AppColors.gold.withValues(alpha: 0.07) : AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isSel ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: isSel ? AppColors.gold : AppColors.textMuted),
                                      const SizedBox(width: 10),
                                      Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(combo.jobdesc, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                                          Text('Target: ${TimeParser.formatDecimalToHHmm(combo.targetHoursRevised)} jam', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        ],
                                      )),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Instruksi
                      sectionCard(
                        title: 'INSTRUKSI TAMBAHAN / POK (OPSIONAL)',
                        child: TextField(
                          controller: descriptionCtrl,
                          minLines: 2,
                          maxLines: 4,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Tulis instruksi atau nomor POK...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Submit
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
                  decoration: const BoxDecoration(color: AppColors.surfaceCard, border: Border(top: BorderSide(color: AppColors.border))),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Simpan ke Draft', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (selectedEmployeeId == null) {
                            AppNotification.showWarning(ctx, 'Pilih pelaksana terlebih dahulu.');
                            return;
                          }
                          final inputHours = TimeParser.parseHHmmToDecimal(hoursCtrl.text);
                          if (inputHours == null || inputHours <= 0) {
                            AppNotification.showError(ctx, 'Target jam wajib diisi dengan benar.');
                            return;
                          }
                          final maxHours = getTotalAvailableHours();
                          if (inputHours > maxHours) {
                            AppNotification.showError(ctx, 'Target melebihi sisa alokasi. Maks: ${TimeParser.formatDecimalToHHmm(maxHours)}');
                            return;
                          }
                          final selectedEmployee = employees.firstWhere((e) => e['id'] == selectedEmployeeId);
                          var remaining = inputHours;
                          final planItems = <CountdownJobdesc>[item, ...selectedCombos];
                          final draftItems = <Map<String, dynamic>>[];
                          for (final planItem in planItems) {
                            if (remaining <= 0) break;
                            final cap = planItem.id == item.id ? availablePlanHours : planItem.targetHoursRevised;
                            final alloc = remaining > cap ? cap : remaining;
                            draftItems.add({
                              'sourceType': 'COUNTDOWN',
                              'coreId': planItem.id,
                              'carId': planItem.carId,
                              'divisionId': item.divisionId,
                              'unitName': unit.unitName,
                              'panelName': planItem.panelName,
                              'assignedUserId': selectedEmployeeId!,
                              'assignedTo': (selectedEmployee['name'] ?? selectedEmployee['full_name'] ?? '-') as String,
                              'jobDescription': planItem.jobdesc,
                              'targetHours': alloc,
                              'taskDate': selectedDate.toIso8601String().split('T').first,
                              'startTime': CountdownHelper.formatTime(startTime),
                              'finishTime': CountdownHelper.formatTime(finishTime),
                              'isOvertime': isOvertime,
                              'note': ['Sumber: Countdown ${planItem.id}', if (planItems.length > 1) 'Combo Jobdesc', isOvertime ? 'Lembur: Ya' : 'Lembur: Tidak', if (descriptionCtrl.text.trim().isNotEmpty) 'POK: ${descriptionCtrl.text.trim()}'].join(' | '),
                            });
                            remaining -= alloc;
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                          try {
                            await jobPlanRepository.saveDraft(userId: session.employeeId ?? '', items: draftItems, sourceType: 'COUNTDOWN');
                            if (rootContext.mounted) AppNotification.showSuccess(rootContext, 'Draft tersimpan! Buka tab Rencana untuk kirim ke approval.');
                          } catch (_) {
                            if (rootContext.mounted) AppNotification.showError(rootContext, 'Gagal menyimpan draft. Coba lagi.');
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return created == true;
  }

  static Future<bool> showCountdownRevisionDialog({
    required BuildContext context,
    required CountdownJobdesc item,
  }) async {
    final hoursCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var deadline =
        DateTime.tryParse(item.deadlineDate)?.add(const Duration(days: 1)) ??
            DateTime.now().add(const Duration(days: 1));
    String? inlineError;
    bool isSubmitting = false;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            'Ajukan Revisi Countdown',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.panelName} • ${item.jobdesc}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deadline saat ini ${item.deadlineDate} • Target saat ini ${item.targetHoursRevised.toStringAsFixed(1)} jam',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: hoursCtrl,
                  readOnly: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Tambahan Jam Kerja (opsional)',
                    helperText: 'Kosongkan bila cuma ubah deadline. Ketuk untuk isi',
                    suffixIcon: Icon(Icons.timer_outlined, color: AppColors.textMuted, size: 20),
                  ),
                  onTap: () async {
                    final currentLabel = hoursCtrl.text.trim();
                    int h = 0;
                    int m = 0;
                    if (currentLabel.contains(':')) {
                      final parts = currentLabel.split(':');
                      h = int.tryParse(parts[0]) ?? 0;
                      m = int.tryParse(parts[1]) ?? 0;
                    }
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(hour: h, minute: m),
                      initialEntryMode: TimePickerEntryMode.inputOnly,
                      helpText: 'Set Tambahan Jam Kerja',
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() {
                        hoursCtrl.text = TimeParser.formatDecimalToHHmm(picked.hour + (picked.minute / 60.0));
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline Baru',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  subtitle: Text(
                    '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded,
                      color: AppColors.gold, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: deadline,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => deadline = picked);
                    }
                  },
                ),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Alasan Revisi',
                    helperText:
                        'Jelaskan kebutuhan revisi deadline dan/atau tambahan jam kerja.',
                  ),
                ),
                if (inlineError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.statusLocked.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.statusLocked.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppColors.statusLocked),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            inlineError!,
                            style: const TextStyle(fontSize: 12, color: AppColors.statusLocked),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final rawHours = hoursCtrl.text.trim();
                      final requestedHours =
                          rawHours.isEmpty ? 0.0 : TimeParser.parseHHmmToDecimal(rawHours);

                      if (requestedHours == null || requestedHours < 0) {
                        setDialogState(() => inlineError = 'Format tambahan jam kerja tidak valid.');
                        return;
                      }

                      final selectedDeadline = '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}';
                      final isDeadlineChanged = selectedDeadline != item.deadlineDate;

                      if (requestedHours == 0 && !isDeadlineChanged) {
                        setDialogState(() => inlineError = 'Ubah deadline atau isi tambahan jam kerja terlebih dahulu.');
                        return;
                      }

                      if (reasonCtrl.text.trim().isEmpty) {
                        setDialogState(() => inlineError = 'Alasan revisi wajib diisi.');
                        return;
                      }

                      setDialogState(() { isSubmitting = true; inlineError = null; });

                      try {
                        final repository = sl<CountdownRepository>();
                        await repository.requestRevision(
                          countdownId: item.id,
                          requestedHours: requestedHours,
                          requestedDeadline: selectedDeadline,
                          reason: reasonCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          inlineError = 'Gagal: $e';
                        });
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.background,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Text('Ajukan'),
            ),
          ],
        ),
      ),
    );

    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan revisi berhasil dikirim!'),
          backgroundColor: AppColors.statusDone,
        ),
      );
    }

    return submitted == true;
  }

  /// Shows a confirmation dialog for KD to declare a jobdesc as complete (QC_READY).
  /// Returns true if the user confirmed.
  static Future<bool> showDeclareCompleteDialog({
    required BuildContext context,
    required CountdownJobdesc item,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.statusDone, width: 1.2),
        ),
        icon: const Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.statusDone,
          size: 36,
        ),
        title: const Text(
          'Dinyatakan Selesai?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${item.panelName} • ${item.jobdesc}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pekerjaan ini akan dinyatakan selesai dan menunggu QC.\nStatus akan berubah ke READY_QC.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusDone,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text(
              'Ya, Selesaikan',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
