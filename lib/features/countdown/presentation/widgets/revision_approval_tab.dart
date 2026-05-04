import 'package:flutter/material.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/countdown_shared.dart';
import '../../domain/repositories/countdown_repository.dart';

class RevisionApprovalTab extends StatefulWidget {
  const RevisionApprovalTab({
    super.key,
    required this.repository,
    this.carId,
    required this.onStatusChanged,
  });

  final CountdownRepository repository;
  final String? carId;
  final VoidCallback onStatusChanged;

  @override
  State<RevisionApprovalTab> createState() => _RevisionApprovalTabState();
}

class _RevisionApprovalTabState extends State<RevisionApprovalTab> {
  late Future<List<CountdownJobdesc>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    _requestsFuture = widget.repository.getRevisionRequests(carId: widget.carId).then((all) {
      return all
          .where((item) =>
              item.revisionRequestStatus != null &&
              item.revisionRequestStatus!.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final timeA = a.requestedRevisionAt;
          final timeB = b.requestedRevisionAt;
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CountdownJobdesc>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CountdownEmptyMessage(
                message: 'Tidak ada pengajuan revisi countdown saat ini.',
              ),
            ),
          );
        }

        final pending = requests.where((r) => r.revisionRequestStatus?.toUpperCase() == 'REQUESTED').toList();
        final history = requests.where((r) => r.revisionRequestStatus?.toUpperCase() != 'REQUESTED').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const RevisionSectionHeader(
              title: 'Menunggu Persetujuan',
              subtitle: 'Pengajuan revisi yang butuh review PM',
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty)
              const CountdownEmptyMessage(message: 'Tidak ada pengajuan yang menunggu.')
            else
              ...pending.map((item) => RevisionRequestCard(
                    item: item,
                    onApprove: (hours, deadline) => _handleAction(
                      context,
                      item,
                      'APPROVED',
                      approvedHours: hours,
                      approvedDeadline: deadline,
                    ),
                    onReject: (reason) => _handleAction(
                      context,
                      item,
                      'REJECTED',
                    ),
                  )),
            const SizedBox(height: 24),
            const RevisionSectionHeader(
              title: 'Riwayat Pengajuan',
              subtitle: 'Pengajuan yang sudah diproses',
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const CountdownEmptyMessage(message: 'Belum ada riwayat pengajuan.')
            else
              ...history.map((item) {
                final isApproved = item.revisionRequestStatus?.toUpperCase() == 'APPROVED';
                return ExpansionTile(
                  collapsedBackgroundColor: AppColors.surfaceInput,
                  backgroundColor: AppColors.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  leading: Icon(
                    isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isApproved ? AppColors.statusDone : AppColors.statusLocked,
                  ),
                  title: Text(
                    '${item.panelName} • ${item.jobdesc}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    isApproved ? 'Disetujui' : 'Ditolak',
                    style: TextStyle(
                      fontSize: 11,
                      color: isApproved ? AppColors.statusDone : AppColors.statusLocked,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('Pengaju', item.requestedRevisionByName ?? '-'),
                          _detailRow(
                              'Waktu Pengajuan',
                              item.requestedRevisionAt != null
                                  ? _formatDateTime(item.requestedRevisionAt!)
                                  : '-'),
                          _detailRow('Alasan', item.requestedRevisionReason ?? '-'),
                          _detailRow('Usulan Tambahan', '${item.requestedRevisionHours?.toStringAsFixed(1) ?? '0.0'} jam'),
                          _detailRow('Usulan Deadline', item.requestedRevisionDeadline ?? '-'),
                          const Divider(height: 16),
                          if (isApproved) ...[
                            _detailRow('Disetujui Oleh', item.approvedRevisionByName ?? '-'),
                            _detailRow('Waktu ACC',
                                item.approvedRevisionAt != null ? _formatDateTime(item.approvedRevisionAt!) : '-'),
                            _detailRow('ACC Tambahan', '${item.approvedRevisionHours?.toStringAsFixed(1) ?? '0.0'} jam'),
                            _detailRow('ACC Deadline', item.approvedRevisionDeadline ?? '-'),
                          ] else ...[
                            _detailRow('Ditolak Oleh', item.rejectedRevisionByName ?? '-'),
                            _detailRow('Waktu Tolak',
                                item.rejectedRevisionAt != null ? _formatDateTime(item.rejectedRevisionAt!) : '-'),
                          ]
                        ],
                      ),
                    ),
                  ],
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    CountdownJobdesc item,
    String finalStatus, {
    double? approvedHours,
    String? approvedDeadline,
  }) async {
    final isApproved = finalStatus == 'APPROVED';
    await widget.repository.processRevisionRequest(
      requestId: item.id,
      approved: isApproved,
      approvedHours: approvedHours ?? 0.0,
      approvedDeadline: approvedDeadline ?? item.deadlineDate,
    );

    if (!context.mounted) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            finalStatus == 'APPROVED' ? 'Revisi disetujui.' : 'Pengajuan revisi ditolak.',
          ),
          backgroundColor: finalStatus == 'APPROVED' ? AppColors.statusDone : AppColors.statusLocked,
        ),
      );
      setState(() => _loadRequests());
      widget.onStatusChanged();
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class RevisionRequestCard extends StatefulWidget {
  const RevisionRequestCard({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final CountdownJobdesc item;
  final void Function(double approvedHours, String approvedDeadline) onApprove;
  final void Function(String? reason) onReject;

  @override
  State<RevisionRequestCard> createState() => _RevisionRequestCardState();
}

class _RevisionRequestCardState extends State<RevisionRequestCard> {
  late TextEditingController _hoursCtrl;
  late TextEditingController _deadlineCtrl;
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    _hoursCtrl = TextEditingController(
      text: widget.item.requestedRevisionHours?.toStringAsFixed(1) ?? '0.0',
    );
    _deadlineCtrl = TextEditingController(
      text: widget.item.requestedRevisionDeadline ?? widget.item.deadlineDate,
    );
    _selectedDeadline = DateTime.tryParse(_deadlineCtrl.text);
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _deadlineCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.panelName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(widget.item.jobdesc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('New Request', style: TextStyle(fontSize: 10, color: AppColors.orange, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('Pengaju', widget.item.requestedRevisionByName ?? '-'),
                _detailRow('Waktu Pengajuan', widget.item.requestedRevisionAt != null ? _formatDateTime(widget.item.requestedRevisionAt!) : '-'),
                _detailRow('Alasan Revisi', widget.item.requestedRevisionReason ?? '-'),
                _detailRow('Target Saat Ini', '${widget.item.targetHoursRevised.toStringAsFixed(1)} jam'),
                _detailRow('Deadline Saat Ini', widget.item.deadlineDate),
                const Divider(),
                const Text('Persetujuan (Bisa disesuaikan PM)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _hoursCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'ACC Tambahan Jam',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDeadline ?? DateTime.now(),
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2027),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDeadline = picked;
                              _deadlineCtrl.text = _formatDate(picked);
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _deadlineCtrl,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'ACC Deadline Baru',
                              isDense: true,
                              suffixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => widget.onReject(null),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusLocked.withValues(alpha: 0.1),
                    foregroundColor: AppColors.statusLocked,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
                    ),
                  ),
                  child: const Text('Tolak'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 0.0;
                    final deadline = _deadlineCtrl.text.trim();
                    widget.onApprove(hours, deadline);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusDone,
                    foregroundColor: AppColors.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
                    ),
                  ),
                  child: const Text('ACC Revisi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
