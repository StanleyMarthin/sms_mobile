import 'package:flutter/material.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../job_plan/presentation/pages/job_plan_page.dart';
import '../../domain/entities/task_filter.dart';
import 'mechanic_task_page.dart';
import 'task_view_page.dart';

enum TaskSectionKind { tasks, overtime, plan }

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
    final role = sl<SessionManager>().role;
    final isMechanic = hasPermission(role, Permission.dashboardMechanic);

    switch (kind) {
      case TaskSectionKind.tasks:
        if (isMechanic) {
          return MechanicTaskPage(
            isOvertime: false,
            title: 'Task',
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
        if (isMechanic) {
          return MechanicTaskPage(
            isOvertime: true,
            title: 'Lembur',
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