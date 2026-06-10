import 'package:flutter/material.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/task_filter.dart';
import 'mechanic_task_page.dart';
import 'task_view_page.dart';

/// Unified Tasks page for all roles.
///
/// Operator sees Daily / Overtime execution tabs.
/// Management sees Daily / Overtime / Review tabs.
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final isOperator =
        session.isFieldExecution &&
        hasPermission(session.role, Permission.dashboardMechanic);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.textMuted,
                dividerHeight: 0,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Harian'),
                  Tab(text: 'Lembur'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: isOperator
              ? const [
                  MechanicTaskPage(isOvertime: false, title: 'Task'),
                  MechanicTaskPage(isOvertime: true, title: 'Lembur'),
                ]
              : const [
                  TaskViewPage(taskType: TaskType.daily),
                  TaskViewPage(taskType: TaskType.overtime),
                ],
        ),
      ),
    );
  }
}
