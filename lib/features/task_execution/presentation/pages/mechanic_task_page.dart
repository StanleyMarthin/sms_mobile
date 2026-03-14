import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  });

  final bool isOvertime;
  final String title;
  final String? focusTaskId;
  final DateTime? initialDate;

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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
            ),
          ),
        ),
      ],
    );
  }
}