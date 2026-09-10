/*
Tujuan: UI Tracking Master Panel di modul Countdown.
Caller: GroupedUnitMonitoringPage mode Tracking Panel.
Dependensi: CountdownRepository, RemotePrDataSource, Countdown/PR entities, ApiEndpoints, AppColors.
Main Functions: MasterPanelTrackingView.
Side Effects: HTTP read tracking, create Countdown, dan create PR sesuai permission.
*/

import 'package:flutter/material.dart';
import 'dart:math';

import '../../../../core/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../pr/data/datasources/remote_pr_datasource.dart';
import '../../../pr/data/models/pr_item.dart';
import '../../../pr/presentation/pages/pr_detail_page.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../widgets/countdown_shared.dart';

bool canCreateMasterPanelCountdown(Set<String> permissionCodes) {
  return permissionCodes.contains(Perms.unitCatalogCreateJobdesc);
}

bool canCreateMasterPanelPr(Set<String> permissionCodes) {
  return permissionCodes.contains(Perms.prCreate);
}

String newCountdownCommandId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class MasterPanelTrackingView extends StatefulWidget {
  const MasterPanelTrackingView({
    super.key,
    required this.unit,
    required this.repository,
  });

  final CountdownUnit unit;
  final CountdownRepository repository;

  @override
  State<MasterPanelTrackingView> createState() =>
      _MasterPanelTrackingViewState();
}

class _MasterPanelTrackingViewState extends State<MasterPanelTrackingView> {
  bool _loading = true;
  MasterPanelTracking? _tracking;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracking = await widget.repository.getMasterPanelTracking(
        widget.unit.carId,
      );
      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppNotification.showError(
        context,
        friendlyMessage(error, fallback: 'Gagal memuat tracking panel'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tracking = _tracking;
    if (tracking == null || tracking.summary.total == 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CountdownEmptyMessage(
          message: 'Belum ada Master Panel untuk unit ini.',
        ),
      );
    }
    final components = _filteredComponents(tracking.components);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _SummaryCard(summary: tracking.summary),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: _searchDecoration('Cari component, panel, atau part'),
          ),
          const SizedBox(height: 12),
          ...components.map(
            (component) => CountdownNavCard(
              title: component.componentName,
              subtitle:
                  '${component.totalParts} Part • ${component.pendingCount} Belum Tindakan • ${component.progressCount} Progress • ${component.orderCount} Order',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _TrackingPanelPage(
                    unit: widget.unit,
                    component: component,
                    repository: widget.repository,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MasterPanelTrackingComponent> _filteredComponents(
    List<MasterPanelTrackingComponent> components,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return components;
    return components.where((component) {
      if (component.componentName.toLowerCase().contains(query)) return true;
      return component.panels.any((panel) {
        if (panel.panelName.toLowerCase().contains(query)) return true;
        return panel.parts.any(
          (part) =>
              part.namePart.toLowerCase().contains(query) ||
              (part.aliasName ?? '').toLowerCase().contains(query) ||
              (part.partNumber ?? '').toLowerCase().contains(query),
        );
      });
    }).toList();
  }
}

class _TrackingPanelPage extends StatelessWidget {
  const _TrackingPanelPage({
    required this.unit,
    required this.component,
    required this.repository,
  });

  final CountdownUnit unit;
  final MasterPanelTrackingComponent component;
  final CountdownRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(component.componentName),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: component.panels
            .map(
              (panel) => CountdownNavCard(
                title: panel.panelName,
                subtitle:
                    '${panel.totalParts} Part • ${panel.activityCount} Activity • ${panel.progressPercent.toStringAsFixed(0)}% Progress',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _TrackingPartPage(
                      unit: unit,
                      panel: panel,
                      repository: repository,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TrackingPartPage extends StatefulWidget {
  const _TrackingPartPage({
    required this.unit,
    required this.panel,
    required this.repository,
  });

  final CountdownUnit unit;
  final MasterPanelTrackingPanel panel;
  final CountdownRepository repository;

  @override
  State<_TrackingPartPage> createState() => _TrackingPartPageState();
}

class _TrackingPartPageState extends State<_TrackingPartPage> {
  late MasterPanelTrackingPanel _panel = widget.panel;
  bool _refreshing = false;

  Future<void> _refreshPanel() async {
    setState(() => _refreshing = true);
    try {
      final tracking = await widget.repository.getMasterPanelTracking(
        widget.unit.carId,
      );
      final panels = tracking.components.expand(
        (component) => component.panels,
      );
      final updated = panels.where((panel) {
        if (_panel.panelId != null) return panel.panelId == _panel.panelId;
        return panel.panelId == null && panel.panelName == _panel.panelName;
      }).firstOrNull;
      if (!mounted || updated == null) return;
      setState(() => _panel = updated);
    } catch (error) {
      if (!mounted) return;
      AppNotification.showError(
        context,
        friendlyMessage(error, fallback: 'Gagal refresh tracking panel'),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_panel.panelName),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshPanel,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _panel.parts.length,
              itemBuilder: (_, index) {
                final part = _panel.parts[index];
                return _PartCard(
                  part: part,
                  onTap: () async {
                    final changed = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _MasterPanelDetailSheet(
                        unitId: widget.unit.carId,
                        part: part,
                        repository: widget.repository,
                        onChanged: _refreshPanel,
                      ),
                    );
                    if (changed == true) {
                      await _refreshPanel();
                    }
                  },
                );
              },
            ),
          ),
          if (_refreshing)
            const Positioned(
              top: 8,
              right: 16,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({required this.part, required this.onTap});

  final MasterPanelTrackingPart part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activity = part.activitySummary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              part.aliasName ?? part.namePart,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (part.aliasName != null) ...[
              const SizedBox(height: 2),
              Text(
                part.namePart,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Part Number: ${part.partNumber ?? '-'} • Condition: ${part.initialCondition} • Qty: ${part.qty.toStringAsFixed(part.qty.truncateToDouble() == part.qty ? 0 : 1)}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusPill(status: part.trackingStatus),
                _CountPill(label: 'Countdown', count: activity.countdownCount),
                _CountPill(label: 'PR', count: activity.prCount),
                if (activity.woCount > 0)
                  _CountPill(label: 'WO', count: activity.woCount),
                if (activity.wovCount > 0)
                  _CountPill(label: 'WOV', count: activity.wovCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterPanelDetailSheet extends StatefulWidget {
  const _MasterPanelDetailSheet({
    required this.unitId,
    required this.part,
    required this.repository,
    required this.onChanged,
  });

  final String unitId;
  final MasterPanelTrackingPart part;
  final CountdownRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_MasterPanelDetailSheet> createState() =>
      _MasterPanelDetailSheetState();
}

class _MasterPanelDetailSheetState extends State<_MasterPanelDetailSheet> {
  late Future<MasterPanelDetail> _future = widget.repository
      .getMasterPanelDetail(
        unitId: widget.unitId,
        panelId: widget.part.masterPanelId,
      );

  Future<void> _reloadDetail() async {
    setState(() {
      _future = widget.repository.getMasterPanelDetail(
        unitId: widget.unitId,
        panelId: widget.part.masterPanelId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: FutureBuilder<MasterPanelDetail>(
          future: _future,
          builder: (context, snapshot) {
            final detail = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || detail == null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: CountdownEmptyMessage(
                  message: friendlyMessage(
                    snapshot.error,
                    fallback: 'Gagal memuat detail Master Panel',
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  detail.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${detail.componentName} > ${detail.panelName}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                _ImageStrip(images: detail.images),
                const SizedBox(height: 14),
                _InfoRow(label: 'Part Number', value: detail.partNumber ?? '-'),
                _InfoRow(label: 'Condition', value: detail.initialCondition),
                _InfoRow(label: 'Status', value: detail.currentStatus),
                _InfoRow(label: 'Qty', value: _formatQty(detail.qty)),
                if (detail.notes != null)
                  _InfoRow(label: 'Catatan', value: detail.notes!),
                const SizedBox(height: 12),
                _ActivitySummaryCard(
                  summary: widget.part.activitySummary,
                  countdownCount: detail.countdownCount,
                  prCount: detail.prActivities.length,
                ),
                if (detail.countdownCount > 0) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Countdown',
                    value: '${detail.countdownCount} pekerjaan',
                  ),
                ],
                if (detail.prActivities.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...detail.prActivities.map((pr) => _PrActivityTile(pr: pr)),
                ],
                if (_canCreateCountdownFromSession() ||
                    _canCreatePrFromSession()) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (_canCreateCountdownFromSession())
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _openCreateCountdown(detail),
                            icon: const Icon(Icons.add_task),
                            label: const Text('Buat Countdown'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      if (_canCreatePrFromSession())
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _openCreatePr(detail),
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: const Text('Buat PR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceInput,
                              foregroundColor: AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  bool _canCreateCountdownFromSession() {
    if (!sl.isRegistered<SessionManager>()) return false;
    final session = sl<SessionManager>();
    return canCreateMasterPanelCountdown({
      if (session.hasPerm(Perms.unitCatalogCreateJobdesc))
        Perms.unitCatalogCreateJobdesc,
    });
  }

  bool _canCreatePrFromSession() {
    if (!sl.isRegistered<SessionManager>()) return false;
    final session = sl<SessionManager>();
    return canCreateMasterPanelPr({
      if (session.hasPerm(Perms.prCreate)) Perms.prCreate,
    });
  }

  Future<void> _openCreateCountdown(MasterPanelDetail detail) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateCountdownSheet(
        unitId: widget.unitId,
        detail: detail,
        repository: widget.repository,
      ),
    );
    if (created != true || !mounted) return;
    await _reloadDetail();
    await widget.onChanged();
    if (!mounted) return;
    AppNotification.showSuccess(context, 'Countdown berhasil dibuat.');
  }

  Future<void> _openCreatePr(MasterPanelDetail detail) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePrSheet(unitId: widget.unitId, detail: detail),
    );
    if (created != true || !mounted) return;
    await _reloadDetail();
    await widget.onChanged();
    if (!mounted) return;
    AppNotification.showSuccess(context, 'PR berhasil dibuat.');
  }
}

class _PrActivityTile extends StatelessWidget {
  const _PrActivityTile({required this.pr});

  final MasterPanelPrActivity pr;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PrDetailPage(reqId: pr.reqId)),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pr.prNumber,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${pr.accTracking} • Qty ${_formatQty(pr.qty)}${pr.targetDate == null ? '' : ' • ${pr.targetDate}'}',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _CreatePrSheet extends StatefulWidget {
  const _CreatePrSheet({required this.unitId, required this.detail});

  final String unitId;
  final MasterPanelDetail detail;

  @override
  State<_CreatePrSheet> createState() => _CreatePrSheetState();
}

class _CreatePrSheetState extends State<_CreatePrSheet> {
  final String _commandId = newCountdownCommandId();
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _targetDate;
  String _priority = 'NORMAL';
  String _origin = 'LOKAL';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final qty = widget.detail.qty <= 0 ? 1.0 : widget.detail.qty;
    _qtyController.text = _formatQty(qty);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      AppNotification.showError(context, 'Qty wajib lebih dari 0.');
      return;
    }
    setState(() => _saving = true);
    try {
      final session = sl<SessionManager>();
      await RemotePrDataSource(
        apiClient: sl(),
        sessionManager: session,
      ).createPr(
        carId: widget.unitId,
        masterPanelId: widget.detail.id,
        commandId: _commandId,
        carName: widget.unitId,
        divisionId: session.divisionId?.toString(),
        divisionName: session.divisionName,
        targetDate: _targetDate == null ? null : _dateOnly(_targetDate!),
        priority: _priority,
        notes: _notesController.text.trim(),
        items: [
          PRItem(
            id: '',
            prId: '',
            itemName: widget.detail.name,
            originType: _origin,
            qty: qty,
          ),
        ],
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppNotification.showError(
        context,
        friendlyMessage(error, fallback: 'Gagal membuat PR'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Buat PR',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.unitId}\n${widget.detail.componentName} > ${widget.detail.panelName}\n${widget.detail.name}\nCondition: ${widget.detail.initialCondition} • Part Number: ${widget.detail.partNumber ?? '-'}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _qtyController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _fieldDecoration('Qty Request'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              items: const [
                DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                DropdownMenuItem(value: 'URGENT', child: Text('URGENT')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _priority = value ?? 'NORMAL'),
              decoration: _fieldDecoration('Priority'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _origin,
              items: const [
                DropdownMenuItem(value: 'LOKAL', child: Text('LOKAL')),
                DropdownMenuItem(value: 'LN', child: Text('LN')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _origin = value ?? 'LOKAL'),
              decoration: _fieldDecoration('Origin'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickTargetDate,
              icon: const Icon(Icons.event),
              label: Text(
                _targetDate == null
                    ? 'Pilih Target Date'
                    : 'Target: ${_dateOnly(_targetDate!)}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              decoration: _fieldDecoration('Catatan'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: Text(_saving ? 'Menyimpan...' : 'Buat PR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCountdownSheet extends StatefulWidget {
  const _CreateCountdownSheet({
    required this.unitId,
    required this.detail,
    required this.repository,
  });

  final String unitId;
  final MasterPanelDetail detail;
  final CountdownRepository repository;

  @override
  State<_CreateCountdownSheet> createState() => _CreateCountdownSheetState();
}

class _CreateCountdownSheetState extends State<_CreateCountdownSheet> {
  final String _commandId = newCountdownCommandId();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _startDate;
  DateTime? _deadline;
  CountdownCreateOptions? _options;
  CountdownCreateDivisionOption? _division;
  CountdownCreateJobTypeOption? _jobType;
  CountdownCreateUserOption? _pic;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.detail.name;
    _loadOptions();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.repository.getCountdownCreateOptions(
        widget.unitId,
      );
      if (!mounted) return;
      setState(() {
        _options = options;
        _division = options.divisions.isEmpty ? null : options.divisions.first;
        _jobType = _jobTypesForDivision(options).firstOrNull;
        _pic = _usersForDivision(options).firstOrNull;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppNotification.showError(
        context,
        friendlyMessage(error, fallback: 'Gagal memuat pilihan Countdown'),
      );
    }
  }

  List<CountdownCreateJobTypeOption> _jobTypesForDivision(
    CountdownCreateOptions options,
  ) {
    final divisionId = _division?.id;
    return options.jobTypes
        .where(
          (item) => item.divisionId == null || item.divisionId == divisionId,
        )
        .toList();
  }

  List<CountdownCreateUserOption> _usersForDivision(
    CountdownCreateOptions options,
  ) {
    final divisionId = _division?.id;
    return options.users
        .where(
          (item) => item.divisionId == null || item.divisionId == divisionId,
        )
        .toList();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    final target = double.tryParse(_targetController.text.trim());
    if (_division == null || _pic == null || _jobType == null) {
      AppNotification.showError(
        context,
        'Divisi, PIC, dan jenis pekerjaan wajib diisi.',
      );
      return;
    }
    if ((_descriptionController.text.trim()).isEmpty ||
        target == null ||
        target <= 0) {
      AppNotification.showError(
        context,
        'Pekerjaan dan target jam wajib diisi.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.createMasterPanelCountdown(
        unitId: widget.unitId,
        masterPanelId: widget.detail.id,
        idempotencyKey: _commandId,
        divisionId: _division!.id,
        jobTypeId: _jobType!.id,
        description: _descriptionController.text.trim(),
        targetHours: target,
        picPlan: _pic!.id,
        startDate: _startDate == null ? null : _dateOnly(_startDate!),
        deadlineDate: _deadline == null ? null : _dateOnly(_deadline!),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppNotification.showError(
        context,
        friendlyMessage(error, fallback: 'Gagal membuat Countdown'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final jobTypes = options == null
        ? <CountdownCreateJobTypeOption>[]
        : _jobTypesForDivision(options);
    final users = options == null
        ? <CountdownCreateUserOption>[]
        : _usersForDivision(options);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: _loading
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Buat Countdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.unitId}\n${widget.detail.componentName} > ${widget.detail.panelName}\n${widget.detail.name}\nCondition: ${widget.detail.initialCondition} • Part Number: ${widget.detail.partNumber ?? '-'}',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<CountdownCreateDivisionOption>(
                    initialValue: _division,
                    items: (options?.divisions ?? const [])
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _division = value;
                            _jobType = _jobTypesForDivision(
                              options!,
                            ).firstOrNull;
                            _pic = _usersForDivision(options).firstOrNull;
                          }),
                    decoration: _fieldDecoration('Divisi'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<CountdownCreateUserOption>(
                    key: ValueKey('pic-${_division?.id}'),
                    initialValue: users.contains(_pic) ? _pic : null,
                    items: users
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _pic = value),
                    decoration: _fieldDecoration('PIC Plan'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<CountdownCreateJobTypeOption>(
                    key: ValueKey('job-${_division?.id}'),
                    initialValue: jobTypes.contains(_jobType) ? _jobType : null,
                    items: jobTypes
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _jobType = value;
                            if (value != null) {
                              _descriptionController.text = value.name;
                            }
                          }),
                    decoration: _fieldDecoration('Jenis Pekerjaan'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    enabled: !_saving,
                    decoration: _fieldDecoration('Pekerjaan'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _targetController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _fieldDecoration('Target Jam'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickStartDate,
                    icon: const Icon(Icons.today),
                    label: Text(
                      _startDate == null
                          ? 'Pilih Start Date'
                          : 'Start Date: ${_dateOnly(_startDate!)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDeadline,
                    icon: const Icon(Icons.event),
                    label: Text(
                      _deadline == null
                          ? 'Pilih Deadline'
                          : 'Deadline: ${_dateOnly(_deadline!)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final MasterPanelTrackingSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _Metric(label: 'Total', value: summary.total),
          _Metric(label: 'Pending', value: summary.pending),
          _Metric(label: 'Progress', value: summary.progress),
          _Metric(label: 'Order', value: summary.order),
          _Metric(label: 'Done', value: summary.done),
        ],
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.summary,
    this.countdownCount,
    this.prCount,
  });

  final MasterPanelTrackingActivitySummary summary;
  final int? countdownCount;
  final int? prCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _CountPill(
            label: 'Countdown',
            count: countdownCount ?? summary.countdownCount,
          ),
          _CountPill(label: 'Job Plan', count: summary.jobPlanCount),
          _CountPill(label: 'PR', count: prCount ?? summary.prCount),
          _CountPill(label: 'WO', count: summary.woCount),
          _CountPill(label: 'WOV', count: summary.wovCount),
        ],
      ),
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.images});

  final List<MasterPanelImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const CountdownEmptyMessage(
        message: 'Belum ada foto Master Panel.',
      );
    }
    return SizedBox(
      height: 180,
      child: PageView(
        children: images
            .map(
              (image) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: InteractiveViewer(
                  child: Image.network(
                    _imageUrl(image.fileUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceInput,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'PROGRESS_ORDER' => 'PROGRESS + ORDER',
      'PROGRESS' => 'PROGRESS',
      'ORDER' => 'ORDER',
      'DONE' => 'DONE',
      _ => 'PENDING',
    };
    final color = switch (status) {
      'PROGRESS_ORDER' => AppColors.orange,
      'PROGRESS' => AppColors.gold,
      'ORDER' => AppColors.orange,
      'DONE' => AppColors.statusDone,
      _ => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $count',
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _searchDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
    prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
    filled: true,
    fillColor: AppColors.surfaceInput,
    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.gold),
    ),
  );
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.surfaceInput,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.gold),
    ),
  );
}

String _imageUrl(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty || url.contains('/api/v1/proxy/image?url=')) return url;
  if (!url.contains('.r2.dev')) return url;
  return '${ApiEndpoints.baseUrl}/api/v1/proxy/image?url=${Uri.encodeComponent(url)}';
}

String _formatQty(double value) {
  return value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
