import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../domain/entities/warehouse_item_suggestion.dart';
import '../../domain/repositories/warehouse_repository.dart';

/// Job context yang di-pass dari halaman task aktif.
class WarehouseJobContext {
  const WarehouseJobContext({
    required this.carId,
    required this.coreId,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    this.targetSearchDate,
    this.deadlineDate,
  });
  final String carId;
  final String coreId;
  final String unitName;
  final String panelName;
  final String jobName;
  final DateTime? targetSearchDate;
  final DateTime? deadlineDate;
}

/// Sheet request barang gudang (PEMINJAMAN / PENGAMBILAN).
/// Untuk PENYIMPANAN gunakan [WarehouseStorageSheet].
class WarehouseRequestSheet extends StatefulWidget {
  const WarehouseRequestSheet._({this.jobContext});
  final WarehouseJobContext? jobContext;

  static Future<bool> show({
    required BuildContext context,
    WarehouseJobContext? jobContext,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WarehouseRequestSheet._(jobContext: jobContext),
    );
    return result == true;
  }

  /// Shortcut untuk PENYIMPANAN — tampilkan [WarehouseStorageSheet].
  static Future<bool> showStorage({required BuildContext context}) =>
      WarehouseStorageSheet.show(context: context);

  @override
  State<WarehouseRequestSheet> createState() => _WarehouseRequestSheetState();
}

class _WarehouseRequestSheetState extends State<WarehouseRequestSheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _uomCtrl = TextEditingController(text: 'PCS');
  final _notesCtrl = TextEditingController();

  String _itemCategory = 'SPARE_PART';
  String _transactionType = 'PEMINJAMAN';
  bool _installToUnit = false;
  bool _isSaving = false;

  String? _selectedCarId;
  String? _selectedUnitName;
  List<Map<String, dynamic>> _apiCars = [];
  bool _isLoadingCars = true;

  bool get _isLinked => widget.jobContext != null;

  @override
  void initState() {
    super.initState();
    _syncTrxType();
    if (!_isLinked) {
      _fetchCars();
    } else {
      _isLoadingCars = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _uomCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCars() async {
    try {
      final res = await sl<ApiClient>().get(ApiEndpoints.jobPlanDropdowns);
      final data = res.data['data'] ?? res.data;
      if (!mounted) return;
      if (data != null && data['cars'] is List) {
        setState(() {
          _apiCars = (data['cars'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoadingCars = false;
        });
      } else {
        setState(() => _isLoadingCars = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCars = false);
    }
  }

  void _syncTrxType() {
    if (_itemCategory == 'BAHAN') {
      _transactionType = 'PENGAMBILAN';
      _installToUnit = false;
    } else if (_itemCategory == 'TOOLS') {
      _transactionType = 'PEMINJAMAN';
      _installToUnit = false;
      _selectedCarId = null;
      _selectedUnitName = null;
    }
  }

  void _onItemSelected(WarehouseItemSuggestion? item) {
    setState(() {
      if (item != null) {
        _nameCtrl.text = item.itemName;
        if (_uomCtrl.text.trim().isEmpty || _uomCtrl.text.trim() == 'PCS') {
          _uomCtrl.text = item.uom;
        }
      } else if (_nameCtrl.text.trim().isEmpty) {
        _uomCtrl.text = 'PCS';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _handle(),
                const SizedBox(height: 14),
                _title(),
                const SizedBox(height: 14),
                if (_isLinked) ...[
                  _jobBanner(),
                  const SizedBox(height: 16)
                ] else if (_itemCategory != 'TOOLS') ...[
                  _label('Unit / Kendaraan'),
                  const SizedBox(height: 8),
                  _unitDropdown(),
                  const SizedBox(height: 16),
                ],
                _label('Kategori Barang'),
                const SizedBox(height: 8),
                _categoryRow(),
                const SizedBox(height: 14),
                if (_itemCategory == 'SPARE_PART') ...[
                  _label('Tipe Transaksi'),
                  const SizedBox(height: 8),
                  _txTypeRow(),
                  const SizedBox(height: 14),
                  if (_transactionType == 'PENGAMBILAN') ...[
                    SwitchListTile.adaptive(
                      value: _installToUnit,
                      activeThumbColor: AppColors.gold,
                      activeTrackColor: AppColors.gold.withValues(alpha: 0.35),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Langsung dipasang ke unit',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Gunakan bila barang langsung terpasang.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      onChanged: (v) => setState(() => _installToUnit = v),
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else ...[
                  _infoBox(_itemCategory == 'BAHAN'
                      ? 'Bahan dipakai langsung dan tidak perlu dikembalikan.'
                      : 'Tools dipinjam lalu dikembalikan setelah selesai digunakan.'),
                  const SizedBox(height: 14),
                ],
                _label('Nama Barang'),
                const SizedBox(height: 8),
                WarehouseItemSearchField(
                  controller: _nameCtrl,
                  category: _itemCategory,
                  hintText: _hintName,
                  onSelected: _onItemSelected,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Jumlah'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style:
                                const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.numbers_outlined,
                                  color: AppColors.textMuted, size: 20),
                              hintText: '1',
                            ),
                          ),
                        ],
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Satuan'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _uomCtrl,
                            style:
                                const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(hintText: 'PCS'),
                          ),
                        ],
                      )),
                ]),
                const SizedBox(height: 12),
                _label('Catatan (opsional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 3,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Catatan tambahan bila diperlukan',
                    prefixIcon: Icon(Icons.notes_outlined,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                _submitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── sub-widgets ───────────────────────────────────────────────
  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _title() => Row(children: [
        const Icon(Icons.warehouse_outlined, color: AppColors.gold, size: 20),
        const SizedBox(width: 8),
        Text(_isLinked ? 'Ajukan Barang untuk Pekerjaan' : 'Ajukan Barang',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ]);

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.3));

  Widget _infoBox(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted))),
        ]),
      );

  Widget _jobBanner() {
    final ctx = widget.jobContext!;
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    final isToday = ctx.targetSearchDate == null ||
        (DateTime(ctx.targetSearchDate!.year, ctx.targetSearchDate!.month,
                ctx.targetSearchDate!.day) ==
            todayD);
    final diffDays = ctx.targetSearchDate == null
        ? 0
        : DateTime(ctx.targetSearchDate!.year, ctx.targetSearchDate!.month,
                ctx.targetSearchDate!.day)
            .difference(todayD)
            .inDays;
    final isTomorrow = diffDays == 1;
    final dateLabel = isToday
        ? null
        : isTomorrow
            ? 'Besok'
            : '${ctx.targetSearchDate!.day}/${ctx.targetSearchDate!.month}/${ctx.targetSearchDate!.year}';
    final isOvertime = !isToday;

    final accentColor =
        isOvertime ? AppColors.statusInProgress : AppColors.gold;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isOvertime ? Icons.nightlight_round : Icons.link_rounded,
              size: 13, color: accentColor),
          const SizedBox(width: 6),
          Text(
            isOvertime
                ? 'Task lembur${dateLabel != null ? " ($dateLabel)" : ""}'
                : 'Terkait pekerjaan aktif',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: accentColor),
          ),
          if (dateLabel != null && !isOvertime) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(dateLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text(ctx.unitName,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        Text('${ctx.panelName}  ·  ${ctx.jobName}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _categoryRow() {
    const items = [
      ('SPARE_PART', 'Sparepart', Icons.settings_outlined),
      ('BAHAN', 'Bahan', Icons.science_outlined),
      ('TOOLS', 'Tools', Icons.build_outlined),
    ];
    return Row(
      children: items.map((e) {
        final active = _itemCategory == e.$1;
        return Expanded(
            child: Padding(
          padding: EdgeInsets.only(right: e.$1 != 'TOOLS' ? 8 : 0),
          child: GestureDetector(
            onTap: () => setState(() {
              _itemCategory = e.$1;
              _syncTrxType();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: active
                        ? AppColors.gold.withValues(alpha: 0.7)
                        : AppColors.border),
              ),
              child: Column(children: [
                Icon(e.$3,
                    size: 18,
                    color: active ? AppColors.gold : AppColors.textMuted),
                const SizedBox(height: 4),
                Text(e.$2,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? AppColors.gold : AppColors.textMuted)),
              ]),
            ),
          ),
        ));
      }).toList(),
    );
  }

  Widget _txTypeRow() {
    const items = [
      ('PEMINJAMAN', 'Pinjam', Icons.swap_horiz_rounded),
      ('PENGAMBILAN', 'Ambil', Icons.exit_to_app_rounded),
    ];
    return Row(
      children: items.map((e) {
        final active = _transactionType == e.$1;
        return Expanded(
            child: Padding(
          padding: EdgeInsets.only(right: e.$1 == 'PEMINJAMAN' ? 8 : 0),
          child: GestureDetector(
            onTap: () => setState(() {
              _transactionType = e.$1;
              if (_transactionType != 'PENGAMBILAN') _installToUnit = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: active
                        ? AppColors.gold.withValues(alpha: 0.7)
                        : AppColors.border),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(e.$3,
                    size: 16,
                    color: active ? AppColors.gold : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(e.$2,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? AppColors.gold : AppColors.textMuted)),
              ]),
            ),
          ),
        ));
      }).toList(),
    );
  }

  Widget _unitDropdown() {
    if (_isLoadingCars) {
      return const SizedBox(
          height: 48,
          child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold)));
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedCarId,
      dropdownColor: AppColors.surfaceCard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      iconEnabledColor: AppColors.textMuted,
      isExpanded: true,
      decoration: const InputDecoration(hintText: 'Pilih Unit / Kendaraan'),
      items: _apiCars
          .map((car) => DropdownMenuItem(
                value: car['id'] as String,
                child: Text('${car['unit_name']} - ${car['customer_name']}'),
              ))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        final car = _apiCars.firstWhere((c) => c['id'] == v);
        setState(() {
          _selectedCarId = v;
          _selectedUnitName = car['unit_name'] as String?;
        });
      },
    );
  }

  Widget _submitButton() => FilledButton.icon(
        onPressed: _isSaving ? null : _submit,
        icon: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(
          _isSaving ? 'Mengirim...' : 'Ajukan',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  String get _hintName => _itemCategory == 'SPARE_PART'
      ? 'cth: Kampas Rem Depan'
      : _itemCategory == 'BAHAN'
          ? 'cth: Cat Primer 2K'
          : 'cth: Kunci Torsi';

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppNotification.showError(context, 'Nama barang tidak boleh kosong.');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1;
    if (qty <= 0) {
      AppNotification.showError(context, 'Jumlah harus lebih dari 0.');
      return;
    }
    if (!_isLinked && _itemCategory != 'TOOLS' && _selectedCarId == null) {
      AppNotification.showError(
          context, 'Pilih unit/kendaraan terlebih dahulu.');
      return;
    }
    if (_transactionType == 'PENGAMBILAN' &&
        (_itemCategory == 'BAHAN' || _itemCategory == 'SPARE_PART') &&
        !_isLinked) {
      AppNotification.showError(
          context, 'Pengambilan bahan/sparepart harus dari task aktif.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final session = sl<SessionManager>();
      final repo = sl<WarehouseRepository>();
      final ctx = widget.jobContext;

      await repo.createTransaction(
        transactionType: _transactionType,
        itemCategory: _itemCategory,
        itemName: name,
        qty: qty,
        uom: _uomCtrl.text.trim().isNotEmpty ? _uomCtrl.text.trim() : 'PCS',
        requester: session.fullName ?? '-',
        division: session.divisionName ?? '-',
        divisionId: session.divisionId ?? 0,
        employeeId: session.userId ?? '-',
        carId: ctx?.carId ?? _selectedCarId,
        coreId: ctx?.coreId,
        unitName: ctx?.unitName ?? _selectedUnitName,
        panelName: ctx?.panelName,
        jobdesc: ctx?.jobName,
        installToUnit: _installToUnit,
        targetSearchDate: DateTime.now().add(const Duration(days: 4)),
        deadlineDate: ctx?.deadlineDate,
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          AppNotification.showSuccess(context, '$name berhasil diajukan');
        }
      });
    } catch (e) {
      if (mounted) AppNotification.showError(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// STORAGE SHEET — PENYIMPANAN
// ═══════════════════════════════════════════════════════════════
class WarehouseStorageSheet extends StatefulWidget {
  const WarehouseStorageSheet._();

  static Future<bool> show({required BuildContext context}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WarehouseStorageSheet._(),
    );
    return result == true;
  }

  @override
  State<WarehouseStorageSheet> createState() => _WarehouseStorageSheetState();
}

class _WarehouseStorageSheetState extends State<WarehouseStorageSheet> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _condition = 'GOOD';
  String? _selectedCarId;
  String? _selectedUnitName;
  List<Map<String, dynamic>> _apiCars = [];
  final List<String> _photoPaths = [];
  final List<String> _photoUrls = [];
  bool _isLoadingCars = true;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCars();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onItemSelected(WarehouseItemSuggestion? item) {
    setState(() {
      if (item != null) {
        _nameCtrl.text = item.itemName;
      }
    });
  }

  Future<void> _fetchCars() async {
    try {
      final res = await sl<ApiClient>().get(ApiEndpoints.jobPlanDropdowns);
      final data = res.data['data'] ?? res.data;
      if (!mounted) return;
      if (data != null && data['cars'] is List) {
        setState(() {
          _apiCars = (data['cars'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoadingCars = false;
        });
      } else {
        setState(() => _isLoadingCars = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCars = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 14),
                // Title
                const Row(children: [
                  Icon(Icons.archive_outlined,
                      color: Color(0xFF5B8EFF), size: 20),
                  SizedBox(width: 8),
                  Text('Simpan ke Gudang',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 4),
                const Text('Simpan barang yang sudah dilepas ke gudang.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 16),

                // Unit
                _label('Unit / Kendaraan'),
                const SizedBox(height: 8),
                _unitDropdown(),
                const SizedBox(height: 14),

                // Nama Part
                _label('Nama Part / Barang'),
                const SizedBox(height: 8),
                WarehouseItemSearchField(
                  controller: _nameCtrl,
                  category: 'SPARE_PART',
                  hintText: 'cth: Pintu Kanan, Bumper Depan',
                  onSelected: _onItemSelected,
                ),
                const SizedBox(height: 14),

                // Kondisi
                _label('Kondisi Barang'),
                const SizedBox(height: 8),
                _conditionRow(),
                const SizedBox(height: 14),

                _label('Foto Barang'),
                const SizedBox(height: 8),
                _photoPicker(),
                const SizedBox(height: 14),

                // Catatan
                _label('Catatan (opsional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 3,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Catatan tambahan bila diperlukan',
                    prefixIcon: Icon(Icons.notes_outlined,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.archive_rounded, size: 18),
                  label: Text(_isSaving ? 'Mengirim...' : 'Ajukan Penyimpanan',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5B8EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.3));

  Widget _unitDropdown() {
    if (_isLoadingCars) {
      return const SizedBox(
          height: 48,
          child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF5B8EFF))));
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedCarId,
      dropdownColor: AppColors.surfaceCard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      iconEnabledColor: AppColors.textMuted,
      isExpanded: true,
      decoration: const InputDecoration(hintText: 'Pilih Unit / Kendaraan'),
      items: _apiCars
          .map((car) => DropdownMenuItem(
                value: car['id'] as String,
                child: Text('${car['unit_name']} - ${car['customer_name']}'),
              ))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        final car = _apiCars.firstWhere((c) => c['id'] == v);
        setState(() {
          _selectedCarId = v;
          _selectedUnitName = car['unit_name'] as String?;
        });
      },
    );
  }

  Widget _conditionRow() {
    const opts = ['GOOD', 'DAMAGED', 'SCRAP'];
    const labels = ['Baik', 'Rusak', 'Scrap'];
    const colors = [
      AppColors.statusDone,
      AppColors.statusInProgress,
      AppColors.statusLocked
    ];
    return Row(
      children: List.generate(3, (i) {
        final active = _condition == opts[i];
        return Expanded(
            child: Padding(
          padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
          child: GestureDetector(
            onTap: () => setState(() => _condition = opts[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? colors[i].withValues(alpha: 0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: active ? colors[i] : AppColors.border),
              ),
              child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? colors[i] : AppColors.textMuted)),
            ),
          ),
        ));
      }),
    );
  }

  Widget _photoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isUploadingPhoto ? null : _captureAndUploadPhoto,
          icon: _isUploadingPhoto
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                )
              : const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(
            _isUploadingPhoto ? 'Mengupload...' : 'Ambil Foto',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (_photoPaths.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoPaths.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photoPaths[index]),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _photoPaths.removeAt(index);
                          _photoUrls.removeAt(index);
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close,
                            size: 14, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Foto bersifat opsional.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  Future<void> _captureAndUploadPhoto() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const InAppCameraPage(
          slot: 'warehouse_storage',
          label: 'Foto Barang Gudang',
        ),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || path == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final session = sl<SessionManager>();
      final repo = sl<WarehouseRepository>();
      final photoUrl = await repo.uploadPhoto(
        userId: session.userId ?? session.employeeId ?? '',
        filePath: path,
      );
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception('Upload foto gagal');
      }
      if (!mounted) return;
      setState(() {
        _photoPaths.add(path);
        _photoUrls.add(photoUrl);
      });
    } catch (e) {
      if (mounted) AppNotification.showError(context, 'Upload foto gagal: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppNotification.showError(context, 'Nama barang wajib diisi.');
      return;
    }
    if (_selectedCarId == null) {
      AppNotification.showError(context, 'Pilih unit terlebih dahulu.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final session = sl<SessionManager>();
      final repo = sl<WarehouseRepository>();
      await repo.createTransaction(
        transactionType: 'PENYIMPANAN',
        itemCategory: 'SPARE_PART',
        itemName: name,
        qty: 1,
        uom: 'PCS',
        requester: session.fullName ?? '-',
        division: session.divisionName ?? '-',
        divisionId: session.divisionId ?? 0,
        employeeId: session.userId ?? '-',
        carId: _selectedCarId,
        unitName: _selectedUnitName,
        itemCondition: _condition,
        photoUrls: _photoUrls.isEmpty ? null : _photoUrls,
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          AppNotification.showSuccess(context, '$name berhasil diajukan');
        }
      });
    } catch (e) {
      if (mounted) AppNotification.showError(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class WarehouseItemSearchField extends StatefulWidget {
  const WarehouseItemSearchField({
    super.key,
    required this.controller,
    required this.category,
    required this.hintText,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String category;
  final String hintText;
  final ValueChanged<WarehouseItemSuggestion?> onSelected;

  @override
  State<WarehouseItemSearchField> createState() =>
      _WarehouseItemSearchFieldState();
}

class _WarehouseItemSearchFieldState extends State<WarehouseItemSearchField> {
  Timer? _debounce;
  List<WarehouseItemSuggestion> _items = const [];
  WarehouseItemSuggestion? _selected;
  bool _isLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    if (_selected != null && query != _selected!.itemName) {
      _selected = null;
      widget.onSelected(null);
    }

    _debounce?.cancel();
    if (query.length < 2) {
      setState(() => _items = const []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isLoading = true);
      try {
        final repo = sl<WarehouseRepository>();
        final items = await repo.searchItems(
          query: query,
          category: widget.category,
        );
        if (!mounted) return;
        setState(() => _items = items);
      } catch (_) {
        if (!mounted) return;
        setState(() => _items = const []);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  void _pick(WarehouseItemSuggestion item) {
    widget.controller.text = item.itemName;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    setState(() {
      _selected = item;
      _items = const [];
    });
    widget.onSelected(item);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          style: const TextStyle(color: AppColors.textPrimary),
          textCapitalization: TextCapitalization.words,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.inventory_2_outlined,
                color: AppColors.textMuted, size: 20),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          _SelectedItemPreview(item: _selected!),
        ],
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _items.map((item) {
                return InkWell(
                  onTap: () => _pick(item),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SuggestionPhoto(photoUrls: item.photoUrls),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.itemCategory} · ${item.uom}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (item.lastLocation?.isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Lokasi terakhir: ${item.lastLocation}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF5B8EFF),
                                    ),
                                  ),
                                ),
                              if (item.matchedAlias?.isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Alias cocok: ${item.matchedAlias}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedItemPreview extends StatelessWidget {
  const _SelectedItemPreview({required this.item});

  final WarehouseItemSuggestion item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SuggestionPhoto(photoUrls: item.photoUrls),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.itemCode} · ${item.uom}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (item.lastLocation?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.lastLocation!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5B8EFF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionPhoto extends StatelessWidget {
  const _SuggestionPhoto({required this.photoUrls});

  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    if (photoUrls.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined,
            size: 18, color: AppColors.textMuted),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        photoUrls.first,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: AppColors.surfaceInput,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined,
              size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
