import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/dummy_data.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/work_order.dart';

class WoInputSheet extends StatefulWidget {
  final WorkOrder? existing;
  final ValueChanged<WorkOrder> onSubmit;

  const WoInputSheet({
    super.key,
    this.existing,
    required this.onSubmit,
  });

  @override
  State<WoInputSheet> createState() => _WoInputSheetState();
}

class _WoInputSheetState extends State<WoInputSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _woType;
  late String _priority;

  late List<String> _panels;
  late List<String> _parts;
  late List<String> _jobdescs;

  String? _selectedCarId;
  String? _selectedPanel;
  String? _selectedPart;
  String? _selectedJobdesc;
  String? _selectedToDivision;

  late TextEditingController _vendorCtrl;
  late TextEditingController _estimatedHoursCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _customDescriptionCtrl;

  DateTime? _deadline;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _woType = e?.woType ?? 'WO';
    _priority = e?.priority ?? 'NORMAL';

    _panels = _extractUniqueStrings(
      DummyWorkOrders.seedRecords().map((m) => m['panelName'] as String?),
    );
    _parts = _extractUniqueStrings(
      DummyWorkOrders.seedRecords().map((m) => m['partName'] as String?),
    );
    _jobdescs = _extractUniqueStrings(
      DummyWorkOrders.seedRecords().map((m) => m['jobdescName'] as String?),
    );

    _selectedCarId = e?.carId;
    _selectedPanel = e?.panelName;
    _selectedPart = e?.partName;
    _selectedJobdesc = e?.jobdescName;
    _selectedToDivision = e?.toDivision;

    _vendorCtrl = TextEditingController(text: _woType == 'WOV' ? (e?.toDivision ?? '') : '');
    _estimatedHoursCtrl = TextEditingController(
      text: e != null ? e.estimatedHours.toStringAsFixed(1) : '',
    );
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _customDescriptionCtrl = TextEditingController(text: e?.description ?? '');

    if (e?.deadline != null) {
      _deadline = DateTime.tryParse(e!.deadline!);
    }
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _estimatedHoursCtrl.dispose();
    _notesCtrl.dispose();
    _customDescriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Text(
                      _isEdit ? 'Edit Work Order' : 'Buat Work Order',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTypeToggle(),
                        const SizedBox(height: 12),
                        _buildCarDropdown(),
                        const SizedBox(height: 12),
                        _buildDropdownWithAdd(
                          label: 'Panel *',
                          value: _selectedPanel,
                          options: _panels,
                          onChanged: (v) => setState(() => _selectedPanel = v),
                          onAddNew: () => _showAddOptionDialog(
                            title: 'Tambah Panel Baru',
                            onAdd: (value) {
                              setState(() {
                                if (!_panels.contains(value)) _panels.add(value);
                                _selectedPanel = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownWithAdd(
                          label: 'Part *',
                          value: _selectedPart,
                          options: _parts,
                          onChanged: (v) => setState(() => _selectedPart = v),
                          onAddNew: () => _showAddOptionDialog(
                            title: 'Tambah Part Baru',
                            onAdd: (value) {
                              setState(() {
                                if (!_parts.contains(value)) _parts.add(value);
                                _selectedPart = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownWithAdd(
                          label: 'Jobdesc *',
                          value: _selectedJobdesc,
                          options: _jobdescs,
                          onChanged: (v) => setState(() => _selectedJobdesc = v),
                          onAddNew: () => _showAddOptionDialog(
                            title: 'Tambah Jobdesc Baru',
                            onAdd: (value) {
                              setState(() {
                                if (!_jobdescs.contains(value)) _jobdescs.add(value);
                                _selectedJobdesc = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customDescriptionCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Detail pekerjaan (opsional)',
                            filled: true,
                            fillColor: AppColors.surfaceInput,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_woType == 'WO')
                          _buildDivisionDropdown()
                        else
                          TextFormField(
                            controller: _vendorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nama Vendor *',
                              filled: true,
                              fillColor: AppColors.surfaceInput,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _estimatedHoursCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Estimasi jam kerja *',
                            filled: true,
                            fillColor: AppColors.surfaceInput,
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final parsed = double.tryParse((v ?? '').trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Isi jam kerja yang valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildDeadlinePicker(),
                        const SizedBox(height: 12),
                        _buildPrioritySelector(),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Catatan',
                            filled: true,
                            fillColor: AppColors.surfaceInput,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submit,
                            icon: Icon(
                              _isEdit ? Icons.save_outlined : Icons.send_outlined,
                            ),
                            label: Text(_isEdit ? 'Simpan Perubahan' : 'Kirim Work Order'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        Expanded(child: _typeChip('WO', 'Internal')),
        const SizedBox(width: 8),
        Expanded(child: _typeChip('WOV', 'Vendor')),
      ],
    );
  }

  Widget _typeChip(String type, String label) {
    final isSelected = _woType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _woType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.gold : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCarDropdown() {
    const cars = DummyCars.all;
    return DropdownButtonFormField<String>(
      initialValue: _selectedCarId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Unit / Mobil *',
        filled: true,
        fillColor: AppColors.surfaceInput,
        border: OutlineInputBorder(),
      ),
      items: cars
          .map(
            (car) => DropdownMenuItem<String>(
              value: car['id'] as String,
              child: Text(
                '${car['unit_name']} - ${car['customer_name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedCarId = v),
      validator: (v) => v == null ? 'Wajib pilih unit' : null,
    );
  }

  Widget _buildDivisionDropdown() {
    final List<String> divisions = DummyDivisions.all
        .map((d) => d['name'] as String)
        .where((name) => name != 'MANAGEMENT')
        .toSet()
        .toList()
      ..sort();

    return DropdownButtonFormField<String>(
      initialValue:
          divisions.contains(_selectedToDivision) ? _selectedToDivision : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Divisi tujuan *',
        filled: true,
        fillColor: AppColors.surfaceInput,
        border: OutlineInputBorder(),
      ),
      items: divisions
          .map(
            (d) => DropdownMenuItem<String>(
              value: d,
              child: Text(
                d,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedToDivision = v),
      validator: (v) => v == null ? 'Wajib pilih divisi' : null,
    );
  }

  Widget _buildDropdownWithAdd({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required VoidCallback onAddNew,
  }) {
    final sorted = [...options]..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: sorted.contains(value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.surfaceInput,
            border: const OutlineInputBorder(),
          ),
          items: sorted
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(
                    v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Wajib diisi' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onAddNew,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah baru'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlinePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => _deadline = picked);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _deadline == null
              ? 'Pilih deadline *'
              : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: _deadline == null ? AppColors.textDisabled : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('Normal'),
          selected: _priority == 'NORMAL',
          onSelected: (_) => setState(() => _priority = 'NORMAL'),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Tinggi'),
          selected: _priority == 'HIGH',
          onSelected: (_) => setState(() => _priority = 'HIGH'),
        ),
      ],
    );
  }

  void _showAddOptionDialog({
    required String title,
    required ValueChanged<String> onAdd,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nama'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final value = ctrl.text.trim();
              if (value.isEmpty) return;
              onAdd(value);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  List<String> _extractUniqueStrings(Iterable<String?> values) {
    return values
      .whereType<String>()
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih deadline terlebih dahulu')),
      );
      return;
    }

    final car = DummyCars.all.firstWhere((c) => c['id'] == _selectedCarId);
    final session = sl<SessionManager>();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final deadlineStr =
        '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}';

    final description = _customDescriptionCtrl.text.trim().isEmpty
        ? (_selectedJobdesc ?? '-')
        : _customDescriptionCtrl.text.trim();

    final wo = WorkOrder(
      id: widget.existing?.id ?? 'wo-new-${DateTime.now().millisecondsSinceEpoch}',
      woNumber: widget.existing?.woNumber ??
          '$_woType-${session.divisionName?.substring(0, 3).toUpperCase() ?? 'DIV'}-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      woType: _woType,
      carId: car['id'] as String,
      unitName: car['unit_name'] as String,
      ownerName: car['customer_name'] as String,
      panelName: _selectedPanel!,
      partName: _selectedPart,
      jobdescName: _selectedJobdesc,
      coreId: widget.existing?.coreId ?? 'core-new',
      description: description,
      fromDivision: session.divisionName ?? 'MECHANIC',
      toDivision: _woType == 'WO' ? (_selectedToDivision ?? '-') : _vendorCtrl.text.trim(),
      estimatedHours: double.parse(_estimatedHoursCtrl.text.trim()),
      priority: _priority,
      status: widget.existing?.status ?? 'PENDING_ADVISOR',
      notes: _notesCtrl.text.trim(),
      requestedById: session.employeeId ?? 'unknown',
      requestedByName: session.fullName ?? 'Unknown',
      createdAt: widget.existing?.createdAt ?? nowIso,
      deadline: deadlineStr,
      advisorApprovedAt: widget.existing?.advisorApprovedAt,
      advisorApprovedBy: widget.existing?.advisorApprovedBy,
      pmApprovedAt: widget.existing?.pmApprovedAt,
      pmApprovedBy: widget.existing?.pmApprovedBy,
      rejectedReason: widget.existing?.rejectedReason,
      rejectedBy: widget.existing?.rejectedBy,
      previousDeadline: widget.existing?.previousDeadline,
      extensionReason: widget.existing?.extensionReason,
      approvedAt: widget.existing?.approvedAt,
      revisionRequestStatus: widget.existing?.revisionRequestStatus,
      requestedEstimatedHours: widget.existing?.requestedEstimatedHours,
      requestedDeadline: widget.existing?.requestedDeadline,
      revisionReason: widget.existing?.revisionReason,
      revisionReviewedBy: widget.existing?.revisionReviewedBy,
      extensionRequestStatus: widget.existing?.extensionRequestStatus,
      extensionRequestedDeadline: widget.existing?.extensionRequestedDeadline,
      extensionRequestedReason: widget.existing?.extensionRequestedReason,
      extensionReviewedBy: widget.existing?.extensionReviewedBy,
    );

    widget.onSubmit(wo);
    Navigator.pop(context);
  }
}
