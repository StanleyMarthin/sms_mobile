/*
Tujuan: Form pembuatan Work Order oleh KD pembuat sebelum penentuan PIC dan jam kerja oleh KD tujuan.
Caller: WorkOrderPage FAB.
Dependensi: WorkOrderBloc, JobPlanRepository dropdown master, AppColors.
Main Functions: WoCreatePage, _loadDropdowns, _submit.
Side Effects: HTTP dropdown fetch dan dispatch create WO ke bloc.
*/
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../bloc/work_order_bloc.dart';
import '../bloc/work_order_state.dart';

class WoCreatePage extends StatefulWidget {
  const WoCreatePage({super.key});

  @override
  State<WoCreatePage> createState() => _WoCreatePageState();
}

class _WoCreateItemDraft {
  String? selectedPanelName;
  final jobDetailCtrl = TextEditingController();
  final quomCtrl = TextEditingController();

  bool get hasAnyInput =>
      (selectedPanelName?.trim().isNotEmpty ?? false) ||
      jobDetailCtrl.text.trim().isNotEmpty ||
      quomCtrl.text.trim().isNotEmpty;

  bool get isValid => jobDetailCtrl.text.trim().isNotEmpty;

  String? buildNotes() {
    final quom = quomCtrl.text.trim();
    if (quom.isEmpty) return null;
    return 'QUOM: $quom';
  }

  Map<String, dynamic> toPayload() => {
    'jobDetail': jobDetailCtrl.text.trim(),
    if (buildNotes() != null) 'notes': buildNotes(),
    if (selectedPanelName != null) 'panelName': selectedPanelName,
  };

  void dispose() {
    jobDetailCtrl.dispose();
    quomCtrl.dispose();
  }
}

class _WoCreatePageState extends State<WoCreatePage> {
  late final WorkOrderRepository _workOrderRepository;

  // ── Dropdown data ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _cars = [];
  List<Map<String, dynamic>> _panels = [];
  List<Map<String, dynamic>> _divisions = [];
  bool _loading = true;
  bool _isSubmitting = false;

  // ── Form state ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _selectedCar;
  Map<String, dynamic>? _selectedDiv;
  final List<_WoCreateItemDraft> _items = [_WoCreateItemDraft()];

  DateTime _targetDate = DateTime.now().add(Duration(days: 3));

  @override
  void initState() {
    super.initState();
    _workOrderRepository = sl<WorkOrderRepository>();
    _loadDropdowns();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDropdowns({String? carId}) async {
    try {
      final repo = sl<JobPlanRepository>();
      final data = await repo.getDropdowns(divisionId: null, carId: carId);
      if (!mounted) return;
      setState(() {
        _cars = List<Map<String, dynamic>>.from(data['cars'] ?? []);
        _panels = List<Map<String, dynamic>>.from(data['panels'] ?? []);
        _divisions = List<Map<String, dynamic>>.from(data['divisions'] ?? []);
        for (final item in _items) {
          final selectedPanelName = item.selectedPanelName;
          if (selectedPanelName != null &&
              !_panels.any(
                (panel) => panel['name']?.toString() == selectedPanelName,
              )) {
            item.selectedPanelName = null;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedCar == null) {
      _snack('Pilih unit kendaraan terlebih dahulu');
      return;
    }
    if (_selectedDiv == null) {
      _snack('Pilih divisi tujuan terlebih dahulu');
      return;
    }

    final validItems = <_WoCreateItemDraft>[];
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      if (!item.hasAnyInput) {
        continue;
      }
      if (!item.isValid) {
        _snack('Item ${index + 1}: deskripsi pekerjaan wajib diisi');
        return;
      }
      validItems.add(item);
    }
    if (validItems.isEmpty) {
      _snack('Minimal satu pekerjaan wajib diisi');
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await _workOrderRepository.createWorkOrdersBatch(
      carId: _selectedCar!['id']?.toString() ?? '',
      targetDivId: _selectedDiv!['id']?.toString() ?? '',
      targetDate:
          '${_targetDate.year}-'
          '${_targetDate.month.toString().padLeft(2, '0')}-'
          '${_targetDate.day.toString().padLeft(2, '0')}',
      items: validItems.map((item) => item.toPayload()).toList(),
    );
    if (!mounted) return;

    result.fold((failure) => _snack(failure.message ?? 'Gagal membuat WO'), (
      data,
    ) {
      final createdCount = data['createdCount'] as int? ?? validItems.length;
      _snack(
        createdCount > 1
            ? '$createdCount Work Order berhasil dibuat'
            : 'Work Order berhasil dibuat',
      );
      Navigator.pop(context, true);
    });
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.statusLocked,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Search pickers ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _pickFromList({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) label,
    String Function(Map<String, dynamic>)? sublabel,
  }) async {
    String query = '';
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final filtered = items.where((i) {
            final lbl = label(i).toLowerCase();
            final sub = sublabel != null ? sublabel(i).toLowerCase() : '';
            final q = query.toLowerCase();
            return lbl.contains(q) || sub.contains(q);
          }).toList();
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(
                children: [
                  SizedBox(height: 8),
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => ss(() => query = v),
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari...',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                        ),
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
                          borderSide: BorderSide(
                            color: AppColors.gold,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Tidak ada hasil',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: AppColors.border),
                            itemBuilder: (_, i) {
                              final item = filtered[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  label(item),
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: sublabel != null
                                    ? Text(
                                        sublabel(item),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      )
                                    : null,
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Buat Work Order',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        elevation: 0,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: (_loading || _isSubmitting)
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : BlocListener<WorkOrderBloc, WorkOrderState>(
              listener: (ctx, state) {
                if (state is WorkOrderError) {
                  _snack(state.message);
                }
              },
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        // ── Unit ──────────────────────────────────────
                        _SectionCard(
                          icon: Icons.directions_car_rounded,
                          title: 'Unit Kendaraan',
                          child: _TapField(
                            value: _selectedCar != null
                                ? '${_selectedCar!['unit_name'] ?? ''}'
                                      '\n${_selectedCar!['customer_name'] ?? ''}'
                                : null,
                            hint: 'Ketuk untuk pilih unit',
                            onTap: () async {
                              final picked = await _pickFromList(
                                title: 'Pilih Unit',
                                items: _cars,
                                label: (c) => c['unit_name']?.toString() ?? '',
                                sublabel: (c) =>
                                    c['customer_name']?.toString() ?? '',
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedCar = picked;
                                  for (final item in _items) {
                                    item.selectedPanelName = null;
                                  }
                                });
                                await _loadDropdowns(
                                  carId: picked['id']?.toString(),
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 12),

                        // ── Divisi Tujuan ──────────────────────────────
                        _SectionCard(
                          icon: Icons.corporate_fare_rounded,
                          title: 'Divisi Tujuan',
                          child: _TapField(
                            value: _selectedDiv?['name']?.toString(),
                            hint: 'Ketuk untuk pilih divisi',
                            onTap: () async {
                              final picked = await _pickFromList(
                                title: 'Pilih Divisi Tujuan',
                                items: _divisions,
                                label: (d) => d['name']?.toString() ?? '',
                              );
                              if (picked != null) {
                                setState(() => _selectedDiv = picked);
                              }
                            },
                          ),
                        ),
                        SizedBox(height: 12),

                        Row(
                          children: [
                            Text(
                              'Daftar Pekerjaan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Spacer(),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _items.add(_WoCreateItemDraft()),
                              ),
                              icon: Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: AppColors.gold,
                              ),
                              label: Text(
                                'Tambah Item',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ...List.generate(
                          _items.length,
                          (index) =>
                              _buildWorkItemSection(index, _items[index]),
                        ),

                        // ── Tanggal Target ─────────────────────────────
                        _SectionCard(
                          icon: Icons.schedule_rounded,
                          title: 'Target WO',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PIC dan jam kerja akan ditentukan KD tujuan pada tahap approval WO.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SizedBox(height: 12),
                              _TapField(
                                icon: Icons.calendar_today_rounded,
                                value:
                                    '${_targetDate.day.toString().padLeft(2, '0')} / '
                                    '${_targetDate.month.toString().padLeft(2, '0')} / '
                                    '${_targetDate.year}',
                                hint: 'Pilih tanggal target',
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _targetDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      Duration(days: 365),
                                    ),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: ColorScheme.dark(
                                          primary: AppColors.gold,
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() => _targetDate = picked);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // ── Submit bar ─────────────────────────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: Icon(Icons.send_rounded),
                          label: Text(
                            'Kirim Work Order',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.background,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textDisabled),
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
      borderSide: BorderSide(color: AppColors.gold, width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  Widget _buildWorkItemSection(int index, _WoCreateItemDraft item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Item ${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
              Spacer(),
              if (_items.length > 1)
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: AppColors.statusLocked,
                  ),
                  onPressed: () => setState(() {
                    _items[index].dispose();
                    _items.removeAt(index);
                  }),
                ),
            ],
          ),
        ),
        _buildPanelSectionCard(item),
        SizedBox(height: 12),
        _buildDetailCard(item),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPanelSectionCard(_WoCreateItemDraft item) {
    return _SectionCard(
      icon: Icons.grid_view_rounded,
      title: 'Panel / Section',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TapField(
            value: item.selectedPanelName,
            hint: 'Ketuk untuk pilih panel (opsional)',
            onTap: () async {
              final picked = await _pickFromList(
                title: 'Pilih Panel',
                items: _panels,
                label: (panel) => panel['name']?.toString() ?? '',
                sublabel: (panel) => panel['section']?.toString() ?? '',
              );
              if (picked != null) {
                setState(
                  () => item.selectedPanelName = picked['name']?.toString(),
                );
              }
            },
          ),
          SizedBox(height: 8),
          Text(
            'WO dari Master Panel dibuat melalui Tracking Panel.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(_WoCreateItemDraft item) {
    return _SectionCard(
      icon: Icons.assignment_rounded,
      title: 'Detail Pekerjaan',
      child: Column(
        children: [
          TextField(
            controller: item.jobDetailCtrl,
            maxLines: 4,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDeco('Deskripsikan pekerjaan yang diperlukan...'),
          ),
          SizedBox(height: 10),
          TextField(
            controller: item.quomCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDeco('QUOM (opsional, akan masuk catatan)'),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.gold),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField({
    required this.hint,
    required this.onTap,
    this.value,
    this.icon = Icons.chevron_right_rounded,
  });
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(icon, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
