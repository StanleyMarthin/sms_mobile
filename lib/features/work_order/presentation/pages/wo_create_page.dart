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
import '../bloc/work_order_bloc.dart';
import '../bloc/work_order_event.dart';
import '../bloc/work_order_state.dart';

class WoCreatePage extends StatefulWidget {
  const WoCreatePage({super.key});

  @override
  State<WoCreatePage> createState() => _WoCreatePageState();
}

class _WoCreatePageState extends State<WoCreatePage> {
  // ── Dropdown data ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> _cars = [];
  List<Map<String, dynamic>> _panels = [];
  List<Map<String, dynamic>> _divisions = [];
  bool _loading = true;

  // ── Form state ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _selectedCar;
  Map<String, dynamic>? _selectedDiv;
  String? _selectedPanelName; // from master
  bool _useFreeTextPanel = false;
  String? _selectedCategory;

  final _sectionNameCtrl = TextEditingController();
  final _jobDetailCtrl = TextEditingController();
  final _quomCtrl = TextEditingController();

  DateTime _targetDate = DateTime.now().add(const Duration(days: 3));

  static const _categories = [
    'ENGINE',
    'UNDERCARRIAGE',
    'ELECTRICAL',
    'INTERIOR',
    'EXTERIOR',
    'BODY',
    'CUSTOM',
  ];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _sectionNameCtrl.dispose();
    _jobDetailCtrl.dispose();
    _quomCtrl.dispose();
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
        if (_selectedPanelName != null &&
            !_panels.any(
              (panel) => panel['name']?.toString() == _selectedPanelName,
            )) {
          _selectedPanelName = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _submit() {
    if (_selectedCar == null) {
      _snack('Pilih unit kendaraan terlebih dahulu');
      return;
    }
    if (_selectedDiv == null) {
      _snack('Pilih divisi tujuan terlebih dahulu');
      return;
    }
    if (_jobDetailCtrl.text.trim().isEmpty) {
      _snack('Deskripsi pekerjaan wajib diisi');
      return;
    }
    if (_useFreeTextPanel && _sectionNameCtrl.text.trim().isEmpty) {
      _snack('Nama panel/section wajib diisi');
      return;
    }
    if (_useFreeTextPanel && _selectedCategory == null) {
      _snack('Pilih kategori panel untuk panel baru');
      return;
    }

    context.read<WorkOrderBloc>().add(
      CreateWorkOrder(
        carId: _selectedCar!['id']?.toString() ?? '',
        targetDivId: _selectedDiv!['id']?.toString() ?? '',
        jobDetail: _jobDetailCtrl.text.trim(),
        notes: _buildCreateNotes(),
        targetDate:
            '${_targetDate.year}-'
            '${_targetDate.month.toString().padLeft(2, '0')}-'
            '${_targetDate.day.toString().padLeft(2, '0')}',
        panelName: _useFreeTextPanel
            ? _sectionNameCtrl.text.trim()
            : _selectedPanelName,
        sectionName: _useFreeTextPanel ? _sectionNameCtrl.text.trim() : null,
        panelCategory: _selectedCategory,
        addPanelToMaster: _useFreeTextPanel,
      ),
    );
    Navigator.pop(context, true);
  }

  String? _buildCreateNotes() {
    final quom = _quomCtrl.text.trim();
    if (quom.isEmpty) return null;
    return 'QUOM: $quom';
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
      shape: const RoundedRectangleBorder(
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
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => ss(() => query = v),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Cari...',
                        hintStyle: const TextStyle(
                          color: AppColors.textDisabled,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.gold,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada hasil',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.border,
                            ),
                            itemBuilder: (_, i) {
                              final item = filtered[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  label(item),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: sublabel != null
                                    ? Text(
                                        sublabel(item),
                                        style: const TextStyle(
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
        title: const Text(
          'Buat Work Order',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                                  _selectedPanelName = null;
                                });
                                await _loadDropdowns(
                                  carId: picked['id']?.toString(),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

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
                        const SizedBox(height: 12),

                        // ── Panel / Section ───────────────────────────
                        _SectionCard(
                          icon: Icons.grid_view_rounded,
                          title: 'Panel / Section',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_useFreeTextPanel)
                                _TapField(
                                  value: _selectedPanelName,
                                  hint: 'Ketuk untuk pilih panel (opsional)',
                                  onTap: () async {
                                    final picked = await _pickFromList(
                                      title: 'Pilih Panel',
                                      items: _panels,
                                      label: (p) => p['name']?.toString() ?? '',
                                      sublabel: (p) =>
                                          p['section']?.toString() ?? '',
                                    );
                                    if (picked != null) {
                                      setState(
                                        () => _selectedPanelName =
                                            picked['name']?.toString(),
                                      );
                                    }
                                  },
                                ),
                              const SizedBox(height: 8),
                              CheckboxListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: _useFreeTextPanel,
                                activeColor: AppColors.gold,
                                onChanged: (v) => setState(() {
                                  _useFreeTextPanel = v ?? false;
                                  if (!_useFreeTextPanel) {
                                    _selectedCategory = null;
                                    _sectionNameCtrl.clear();
                                  }
                                }),
                                title: const Text(
                                  'Panel tidak ada di daftar (isi manual)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              if (_useFreeTextPanel) ...[
                                TextField(
                                  controller: _sectionNameCtrl,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: _inputDeco(
                                    'Nama Panel / Section',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Panel manual akan otomatis ditambahkan ke master sesuai unit terpilih.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfaceCard,
                                  decoration: _inputDeco('Kategori Panel *'),
                                  items: _categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedCategory = v),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Detail Pekerjaan ──────────────────────────
                        _SectionCard(
                          icon: Icons.assignment_rounded,
                          title: 'Detail Pekerjaan',
                          child: Column(
                            children: [
                              TextField(
                                controller: _jobDetailCtrl,
                                maxLines: 4,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDeco(
                                  'Deskripsikan pekerjaan yang diperlukan...',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _quomCtrl,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDeco(
                                  'QUOM (opsional, akan masuk catatan)',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Tanggal Target ─────────────────────────────
                        _SectionCard(
                          icon: Icons.schedule_rounded,
                          title: 'Target WO',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PIC dan jam kerja akan ditentukan KD tujuan pada tahap approval WO.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                      const Duration(days: 365),
                                    ),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: const ColorScheme.dark(
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
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // ── Submit bar ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceCard,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text(
                            'Kirim Work Order',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
    hintStyle: const TextStyle(color: AppColors.textDisabled),
    filled: true,
    fillColor: AppColors.surfaceInput,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
