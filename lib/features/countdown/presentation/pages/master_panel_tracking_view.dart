/*
Tujuan: UI read-only Tracking Master Panel di modul Countdown.
Caller: GroupedUnitMonitoringPage mode Tracking Panel.
Dependensi: CountdownRepository, Countdown entities, ApiEndpoints, AppColors.
Main Functions: MasterPanelTrackingView.
Side Effects: HTTP read-only melalui repository.
*/

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../widgets/countdown_shared.dart';

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

class _TrackingPartPage extends StatelessWidget {
  const _TrackingPartPage({
    required this.unit,
    required this.panel,
    required this.repository,
  });

  final CountdownUnit unit;
  final MasterPanelTrackingPanel panel;
  final CountdownRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(panel.panelName),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: panel.parts.length,
        itemBuilder: (_, index) {
          final part = panel.parts[index];
          return _PartCard(
            part: part,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _MasterPanelDetailSheet(
                unitId: unit.carId,
                part: part,
                repository: repository,
              ),
            ),
          );
        },
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
  });

  final String unitId;
  final MasterPanelTrackingPart part;
  final CountdownRepository repository;

  @override
  State<_MasterPanelDetailSheet> createState() =>
      _MasterPanelDetailSheetState();
}

class _MasterPanelDetailSheetState extends State<_MasterPanelDetailSheet> {
  late final Future<MasterPanelDetail> _future = widget.repository
      .getMasterPanelDetail(
        unitId: widget.unitId,
        panelId: widget.part.masterPanelId,
      );

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
                _ActivitySummaryCard(summary: widget.part.activitySummary),
              ],
            );
          },
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
  const _ActivitySummaryCard({required this.summary});

  final MasterPanelTrackingActivitySummary summary;

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
          _CountPill(label: 'Countdown', count: summary.countdownCount),
          _CountPill(label: 'Job Plan', count: summary.jobPlanCount),
          _CountPill(label: 'PR', count: summary.prCount),
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
