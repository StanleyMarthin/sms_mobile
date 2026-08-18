/*
Tujuan: Router-level section chooser untuk membuka halaman task yang sesuai berdasarkan role dan jenis section.
Caller: app_router.dart untuk route /tasks, /overtime, dan /plans.
Dependensi: RBAC, SessionManager, MechanicTaskPage, TaskViewPage, JobPlanPage.
Main Functions: build.
Side Effects: Menentukan navigasi tampilan task execution atau monitoring management.
*/
import 'package:flutter/material.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../job_plan/presentation/pages/job_plan_page.dart';
import '../../domain/entities/task_filter.dart';
import 'mechanic_task_page.dart';
import 'task_view_page.dart';

enum TaskSectionKind { tasks, overtime, plan }

enum TaskSectionPresentation { pic, kdModes, monitoring }

TaskSectionPresentation resolveTaskSectionPresentation({
  required bool isOperator,
  required bool isKd,
}) {
  if (isKd) return TaskSectionPresentation.kdModes;
  if (isOperator) return TaskSectionPresentation.pic;
  return TaskSectionPresentation.monitoring;
}

class TaskSectionPage extends StatelessWidget {
  const TaskSectionPage({
    super.key,
    required this.kind,
    this.focusTaskId,
    this.initialDate,
    this.planSourceType,
    this.planSourceRefId,
    this.planAutoOpenCreate = false,
  });

  final TaskSectionKind kind;
  final String? focusTaskId;
  final DateTime? initialDate;
  final String? planSourceType;
  final String? planSourceRefId;
  final bool planAutoOpenCreate;

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final role = session.role;
    final isOperator =
        session.isFieldExecution &&
        hasPermission(role, Permission.dashboardMechanic);
    final presentation = resolveTaskSectionPresentation(
      isOperator: isOperator,
      isKd: UserRole.fromSession(session) == UserRole.kd,
    );

    switch (kind) {
      case TaskSectionKind.tasks:
        if (presentation == TaskSectionPresentation.pic) {
          return MechanicTaskPage(
            isOvertime: false,
            title: 'Task',
            focusTaskId: focusTaskId,
            initialDate: initialDate,
          );
        }
        if (presentation == TaskSectionPresentation.kdModes) {
          return _KdTaskModePage(
            isOvertime: false,
            focusTaskId: focusTaskId,
            initialDate: initialDate,
          );
        }
        return TaskViewPage(
          taskType: TaskType.daily,
          focusTaskId: focusTaskId,
          initialDate: initialDate,
        );
      case TaskSectionKind.overtime:
        if (presentation == TaskSectionPresentation.pic) {
          return MechanicTaskPage(
            isOvertime: true,
            title: 'Lembur',
            focusTaskId: focusTaskId,
            initialDate: initialDate,
          );
        }
        if (presentation == TaskSectionPresentation.kdModes) {
          return _KdTaskModePage(
            isOvertime: true,
            focusTaskId: focusTaskId,
            initialDate: initialDate,
          );
        }
        return TaskViewPage(
          taskType: TaskType.overtime,
          focusTaskId: focusTaskId,
          initialDate: initialDate,
        );
      case TaskSectionKind.plan:
        return JobPlanPage(
          initialDate: initialDate,
          initialSourceType: planSourceType,
          initialSourceRefId: planSourceRefId,
          autoOpenCreate: planAutoOpenCreate,
        );
    }
  }
}

class _KdTaskModePage extends StatelessWidget {
  const _KdTaskModePage({
    required this.isOvertime,
    this.focusTaskId,
    this.initialDate,
  });

  final bool isOvertime;
  final String? focusTaskId;
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    final taskType = isOvertime ? TaskType.overtime : TaskType.daily;
    final picTitle = isOvertime ? 'Lembur Saya' : 'Task Saya';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Monitoring'),
              Tab(text: 'PIC Saya'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                TaskViewPage(
                  taskType: taskType,
                  focusTaskId: focusTaskId,
                  initialDate: initialDate,
                ),
                MechanicTaskPage(
                  isOvertime: isOvertime,
                  title: picTitle,
                  focusTaskId: focusTaskId,
                  initialDate: initialDate,
                  forceOwnOnly: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
