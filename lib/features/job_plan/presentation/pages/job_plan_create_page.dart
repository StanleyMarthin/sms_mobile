/*
Tujuan: Halaman create Job Plan V2 dari Countdown.
Caller: Router /job-plans/v2/create.
Dependensi: JobPlanRepository, CommandMetadata foundation, GoRouter.
Main Functions: JobPlanCreatePage.
Side Effects: HTTP POST Job Plan V2 saat submit.
*/
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan_v2_options.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_v2_command_feedback.dart';

class JobPlanCreatePage extends StatefulWidget {
  const JobPlanCreatePage({
    super.key,
    this.coreId,
    this.panelName,
    this.countdownName,
    this.repository,
  });

  final String? coreId;
  final String? panelName;
  final String? countdownName;
  final JobPlanRepository? repository;

  @override
  State<JobPlanCreatePage> createState() => _JobPlanCreatePageState();
}

class _JobPlanCreatePageState extends State<JobPlanCreatePage> {
  late final _core = TextEditingController(text: widget.coreId ?? '');
  late final _employee = TextEditingController();
  late final _date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  late final _start = TextEditingController(text: '08:00');
  late final _hours = TextEditingController(text: '4');
  late final _description = TextEditingController(
    text: widget.countdownName ?? '',
  );
  bool _priority = false;
  bool _rework = false;
  bool _loading = false;
  late Future<JobPlanV2Options> _optionsFuture;
  String? _unitId;
  String? _panelId;
  String? _countdownId;
  String? _employeeId;

  @override
  void initState() {
    super.initState();
    _optionsFuture = (widget.repository ?? sl<JobPlanRepository>())
        .getV2Options();
    _countdownId = widget.coreId;
  }

  @override
  void dispose() {
    _core.dispose();
    _employee.dispose();
    _date.dispose();
    _start.dispose();
    _hours.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Create Job Plan', style: Theme.of(context).textTheme.titleLarge),
        if ((widget.panelName ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Panel: ${widget.panelName}'),
        ],
        if ((widget.countdownName ?? '').isNotEmpty)
          Text('Countdown: ${widget.countdownName}'),
        const SizedBox(height: 16),
        FutureBuilder<JobPlanV2Options>(
          future: _optionsFuture,
          builder: (context, snapshot) {
            final options = snapshot.data ?? const JobPlanV2Options();
            return Column(
              children: [
                _dropdown(
                  label: 'Unit',
                  value: _unitId,
                  items: options.units,
                  onChanged: (value) => setState(() => _unitId = value?.id),
                ),
                _dropdown(
                  label: 'Panel',
                  value: _panelId,
                  items: options.panels,
                  fallback: widget.panelName,
                  onChanged: (value) => setState(() => _panelId = value?.id),
                ),
                _dropdown(
                  label: 'Countdown',
                  value: _countdownId,
                  items: options.countdowns,
                  fallback: widget.countdownName,
                  onChanged: (value) => setState(() {
                    _countdownId = value?.id;
                    _core.text = value?.id ?? '';
                    if (_description.text.trim().isEmpty) {
                      _description.text = value?.label ?? '';
                    }
                  }),
                ),
                if (options.countdowns.isEmpty) _field(_core, 'Core ID'),
                _dropdown(
                  label: 'PIC',
                  value: _employeeId,
                  items: options.employees,
                  onChanged: (value) => setState(() {
                    _employeeId = value?.id;
                    _employee.text = value?.id ?? '';
                  }),
                ),
                if (options.employees.isEmpty) _field(_employee, 'PIC ID'),
              ],
            );
          },
        ),
        _field(_date, 'Tanggal'),
        _field(_start, 'Jam Mulai'),
        _field(_hours, 'Durasi Jam'),
        _field(_description, 'Job Description'),
        SwitchListTile(
          value: _priority,
          onChanged: (value) => setState(() => _priority = value),
          title: const Text('Priority'),
        ),
        SwitchListTile(
          value: _rework,
          onChanged: (value) => setState(() => _rework = value),
          title: const Text('Rework'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Menyimpan...' : 'Submit'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<JobPlanV2Option> items,
    required ValueChanged<JobPlanV2Option?> onChanged,
    String? fallback,
  }) {
    if (items.isEmpty) {
      final text = (fallback ?? '').trim();
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(text),
        ),
      );
    }
    final selected = items.any((item) => item.id == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: InputDecoration(labelText: label),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.label.isEmpty ? item.id : item.label),
              ),
            )
            .toList(),
        onChanged: (id) =>
            onChanged(items.where((item) => item.id == id).firstOrNull),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final repo = widget.repository ?? sl<JobPlanRepository>();
      final plan = await repo.createV2Plan(
        coreId: _core.text.trim(),
        employeeId: (_employeeId ?? _employee.text).trim(),
        taskDate: _date.text.trim(),
        plannedStartMinute: _timeToMinute(_start.text),
        plannedWorkMinutes: ((double.tryParse(_hours.text) ?? 0) * 60).round(),
        jobDescription: _description.text.trim(),
        commandId: _commandId('create'),
        isPriority: _priority,
        isRework: _rework,
      );
      if (mounted) context.go('/job-plan/${plan.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(JobPlanV2CommandFeedback.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _timeToMinute(String text) {
    final parts = text.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  String _commandId(String action) {
    return 'mobile-v2-$action-${DateTime.now().microsecondsSinceEpoch}';
  }
}
