/*
Tujuan: Halaman QC V2 queue, detail, dan submit command.
Caller: Router /qc/v2, QcTab shortcut, dan widget test.
Dependensi: QcRepository, QcV2QueueItem, QcV2CommandFeedback.
Main Functions: QcV2QueuePage, QcV2DetailPage, QcV2SubmitPage.
Side Effects: HTTP GET queue dan POST submit melalui repository.
*/

library;

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../countdown/domain/entities/countdown_entities.dart';
import '../../../countdown/presentation/widgets/countdown_dialogs.dart';
import '../../domain/entities/qc_item.dart';
import '../../domain/repositories/qc_repository.dart';
import '../utils/qc_v2_command_feedback.dart';

class QcV2QueuePage extends StatefulWidget {
  const QcV2QueuePage({super.key, this.repository, this.initialItems});

  final QcRepository? repository;
  final List<QcV2QueueItem>? initialItems;

  @override
  State<QcV2QueuePage> createState() => _QcV2QueuePageState();
}

class _QcV2QueuePageState extends State<QcV2QueuePage> {
  late Future<QcV2PagedResponse> _future;

  QcRepository get _repo => widget.repository ?? sl<QcRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.initialItems != null
        ? Future.value(
            QcV2PagedResponse(
              items: widget.initialItems!,
              hasMore: false,
              page: 1,
              total: widget.initialItems!.length,
            ),
          )
        : _repo.getV2Queue();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QcV2PagedResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!.items;
        if (items.isEmpty) {
          return const Center(child: Text('Tidak ada QC V2'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _QcV2Card(
              item: items[index],
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QcV2DetailPage(
                      item: items[index],
                      repository: widget.repository,
                    ),
                  ),
                );
                if (mounted && widget.initialItems == null) {
                  setState(_reload);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class QcV2DetailPage extends StatelessWidget {
  const QcV2DetailPage({super.key, required this.item, this.repository});

  final QcV2QueueItem item;
  final QcRepository? repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QC V2 Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(item.unitName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(item.panelName),
          Text('Countdown: ${item.countdownName}'),
          const Divider(height: 24),
          Text('Remaining Hours: ${item.remainingHours}'),
          Text('Labor Status: ${item.countdownStatus}'),
          Text('Latest QC: ${item.latestQcResult ?? '-'}'),
          Text('Validated Plans: ${item.validatedPlanCount}'),
          for (final planId in item.validatedPlanIds) Text(planId),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _openSubmit(context, 'PASS'),
            child: const Text('PASS'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _openSubmit(context, 'NOT_PASS'),
            child: const Text('NOT PASS'),
          ),
        ],
      ),
    );
  }

  void _openSubmit(BuildContext context, String action) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QcV2SubmitPage(item: item, action: action, repository: repository),
      ),
    );
  }
}

class QcV2SubmitPage extends StatefulWidget {
  const QcV2SubmitPage({
    super.key,
    required this.item,
    required this.action,
    this.repository,
  });

  final QcV2QueueItem item;
  final String action;
  final QcRepository? repository;

  @override
  State<QcV2SubmitPage> createState() => _QcV2SubmitPageState();
}

class _QcV2SubmitPageState extends State<QcV2SubmitPage> {
  final _notes = TextEditingController();
  final _duration = TextEditingController();
  final _photo1 = TextEditingController();
  final _photo2 = TextEditingController();
  bool _submitting = false;

  QcRepository get _repo => widget.repository ?? sl<QcRepository>();

  @override
  void dispose() {
    _notes.dispose();
    _duration.dispose();
    _photo1.dispose();
    _photo2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QC ${widget.action}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.item.unitName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(widget.item.panelName),
          Text('Countdown: ${widget.item.countdownName}'),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
          ),
          TextField(
            controller: _duration,
            decoration: const InputDecoration(labelText: 'Inspection Minutes'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _photo1,
            decoration: const InputDecoration(labelText: 'Photo URL 1'),
          ),
          TextField(
            controller: _photo2,
            decoration: const InputDecoration(labelText: 'Photo URL 2'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Submitting...' : widget.action),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await _repo.submitV2Qc(
        coreId: widget.item.coreId,
        commandId:
            'mobile-qc-v2-${widget.item.coreId}-${DateTime.now().microsecondsSinceEpoch}',
        expectedVersion: widget.item.version,
        action: widget.action,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        photos: [
          _photo1.text.trim(),
          _photo2.text.trim(),
        ].where((value) => value.isNotEmpty).toList(),
        inspectionDurationMinutes: int.tryParse(_duration.text.trim()),
      );
      if (!mounted) return;
      if (result.nextAction == 'TIME_ADJUSTMENT_REQUIRED') {
        await _showAdjustmentPrompt(result.qcId);
        if (!mounted) return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(QcV2CommandFeedback.message(error))),
      );
      if (QcV2CommandFeedback.shouldRefresh(error)) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showAdjustmentPrompt(String qcId) async {
    final openRevision = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajukan Tambahan Waktu'),
        content: const Text(
          'QC tidak lolos dan sisa jam sudah habis. Ajukan adjustment countdown untuk menambah waktu kerja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ajukan Tambahan Waktu'),
          ),
        ],
      ),
    );
    if (openRevision != true || !mounted) return;
    await CountdownDialogs.showCountdownRevisionDialog(
      context: context,
      item: _countdownSeed(),
      initialReason: 'QC_ADJUSTMENT',
      sourceType: 'QC',
      referenceId: qcId,
    );
  }

  CountdownJobdesc _countdownSeed() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final deadline =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    return CountdownJobdesc(
      id: widget.item.coreId,
      carId: widget.item.carId,
      divisionId: '',
      panelName: widget.item.panelName,
      sectionName: widget.item.panelName,
      jobdesc: widget.item.countdownName,
      taskCategory: 'MAIN',
      progress: 100,
      status: widget.item.countdownStatus,
      targetHoursInitial: 0,
      timeExtensionHours: 0,
      targetHoursRevised: 0,
      totalActualHours: 0,
      remainingHours: widget.item.remainingHours,
      startDate: deadline,
      deadlineDate: deadline,
      qcLastStatus: widget.item.latestQcResult,
      qcValidationStatus: null,
      qcResultStatus: widget.item.latestQcResult,
      qcEstimatedReworkHours: null,
      qcReworkDeadlineDate: null,
      qcAdvisorNotes: null,
    );
  }
}

class _QcV2Card extends StatelessWidget {
  const _QcV2Card({required this.item, required this.onTap});

  final QcV2QueueItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(item.unitName),
        subtitle: Text(
          'Panel: ${item.panelName}\n'
          'Countdown: ${item.countdownName}\n'
          'Remaining Hours: ${item.remainingHours}',
        ),
        trailing: Text(item.qcState),
        isThreeLine: true,
      ),
    );
  }
}
