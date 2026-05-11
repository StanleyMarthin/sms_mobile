/*
Tujuan: Halaman wrapper task execution mekanik dengan date filter dan mode self-only opsional.
Caller: TasksPage dan TaskViewPage saat management mengerjakan jobdesc miliknya sendiri.
Dependensi: TaskBloc, DateFilterBar, TaskListPage.
Main Functions: initState, _loadTasks, build.
Side Effects: Memicu load task execution ke bloc.
*/
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../bloc/task_bloc.dart';
import '../bloc/task_event.dart';
import '../widgets/date_filter_bar.dart';
import 'task_list_page.dart';

class MechanicTaskPage extends StatefulWidget {
  const MechanicTaskPage({
    super.key,
    required this.isOvertime,
    required this.title,
    this.focusTaskId,
    this.initialDate,
    this.forceOwnOnly = false,
  });

  final bool isOvertime;
  final String title;
  final String? focusTaskId;
  final DateTime? initialDate;
  final bool forceOwnOnly;

  @override
  State<MechanicTaskPage> createState() => _MechanicTaskPageState();
}

class _MechanicTaskPageState extends State<MechanicTaskPage> {
  late final TaskBloc _bloc;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _bloc = sl<TaskBloc>();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadTasks();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _loadTasks() {
    _bloc.add(
      LoadTodaysTasksEvent(
        isOvertime: widget.isOvertime,
        date: _selectedDate,
        forceOwnOnly: widget.forceOwnOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DateFilterBar(
            selectedDate: _selectedDate,
            onDateChanged: (date) {
              setState(() => _selectedDate = date);
              _loadTasks();
            },
            label: widget.title,
          ),
        ),
        Expanded(
          child: BlocProvider.value(
            value: _bloc,
            child: TaskListPage(
              isOvertime: widget.isOvertime,
              selectedDate: _selectedDate,
              title: widget.title,
              focusTaskId: widget.focusTaskId,
              forceOwnOnly: widget.forceOwnOnly,
            ),
          ),
        ),
      ],
    );

    // If it's pushed as a standalone route, it might need its own Scaffold.
    // However, when used inside FeatureShellPage, it shouldn't have one.
    // We check if we are the root of a Navigator route.
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool isStandalone = parentRoute != null && parentRoute.isCurrent;
    
    // In this project, MechanicTaskPage is sometimes used as a body (inside Scaffold)
    // and sometimes pushed (needs Scaffold).
    // We'll wrap it in Scaffold if it's the current route and not inside a Shell.
    if (isStandalone && !parentRoute.canPop) {
        return content;
    }
    
    // Actually, to be safe and simple, if it's forced as own only (the self-execution flow),
    // it's always pushed, so we return a Scaffold.
    if (widget.forceOwnOnly) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceCard,
            foregroundColor: AppColors.textPrimary,
            title: Text(widget.title),
          ),
          body: SafeArea(child: content),
        );
    }

    return content;
  }
}
