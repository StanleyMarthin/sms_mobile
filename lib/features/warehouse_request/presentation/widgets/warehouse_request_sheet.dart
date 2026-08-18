import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../domain/entities/warehouse_item_suggestion.dart';
import '../../domain/repositories/warehouse_repository.dart';
import 'active_job_picker.dart';

/// Job context yang di-pass dari halaman task aktif.
class WarehouseJobContext {
  WarehouseJobContext({
    required this.carId,
    required this.coreId,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    this.targetSearchDate,
    this.deadlineDate,
    this.isOvertime,
  });
  final String carId;
  final String coreId;
  final String unitName;
  final String panelName;
  final String jobName;
  final DateTime? targetSearchDate;
  final DateTime? deadlineDate;
  final bool? isOvertime;
}

class _WarehouseDraftItem {
  _WarehouseDraftItem({
    required this.itemName,
    required this.qty,
    required this.uom,
    this.itemMasterId,
  });

  final String itemName;
  final double qty;
  final String uom;
  final String? itemMasterId;
}

class _PendingWarehouseSubmitItem {
  _PendingWarehouseSubmitItem({
    required this.item,
    this.fromForm = false,
  });

  final _WarehouseDraftItem item;
  final bool fromForm;
}

/// Sheet request barang gudang (PEMINJAMAN / PENGAMBILAN).
/// Untuk PENYIMPANAN gunakan [WarehouseStorageSheet].
class WarehouseRequestSheet extends StatefulWidget {
  const WarehouseRequestSheet._({
    this.jobContext,
    this.transactionType = 'PEMINJAMAN',
  });
  final WarehouseJobContext? jobContext;
  final String transactionType;

  static Future<bool> show({
    required BuildContext context,
    WarehouseJobContext? jobContext,
    String transactionType = 'PEMINJAMAN',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WarehouseRequestSheet._(
        jobContext: jobContext,
        transactionType: transactionType,
      ),
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
  final List<_WarehouseDraftItem> _draftItems = [];
  WarehouseItemSuggestion? _selectedItem;

  String _itemCategory = 'SPARE_PART';
  late String _transactionType;
  bool _installToUnit = false;
  bool _isSaving = false;

  String? _selectedCarId;
  String? _selectedUnitName;
  WarehouseJobContext? _selectedJobContext;
  bool _bahanForJobdesc = true;
  List<WarehouseItemSuggestion> _unitSpareparts = [];
  bool _isLoadingUnitItems = false;

  bool get _isLinked => widget.jobContext != null || _selectedJobContext != null;

  WarehouseJobContext? get _jobContext =>
      widget.jobContext ?? _selectedJobContext;

  @override
  void initState() {
    super.initState();
    _transactionType = widget.transactionType;
    _syncTrxType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _itemCategory == 'SPARE_PART' && !_isLinked) {
        _pickJob();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _uomCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _syncTrxType() {
    if (_itemCategory == 'TOOLS') {
      _installToUnit = false;
      _selectedCarId = null;
      _selectedUnitName = null;
    }
  }

  Future<void> _pickJob() async {
    final ctx = await ActiveJobPicker.show(context);
    if (!mounted || ctx == null) return;
    setState(() {
      _selectedJobContext = ctx;
      _selectedCarId = null;
      _selectedUnitName = null;
    });
    if (_itemCategory == 'SPARE_PART') {
      await _loadUnitSpareparts(ctx.carId);
    }
  }

  Future<void> _loadUnitSpareparts(String carId) async {
    setState(() => _isLoadingUnitItems = true);
    try {
      final items = await sl<WarehouseRepository>().searchItems(
        query: '',
        category: 'SPARE_PART',
        carId: carId,
      );
      if (!mounted) return;
      setState(() => _unitSpareparts = items);
    } catch (_) {
      if (mounted) setState(() => _unitSpareparts = []);
    } finally {
      if (mounted) setState(() => _isLoadingUnitItems = false);
    }
  }

  void _onItemSelected(WarehouseItemSuggestion? item) {
    setState(() {
      _selectedItem = item;
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

  void _handleCategoryChange(String value) {
    if (_draftItems.isNotEmpty) {
      AppNotification.showWarning(
        context,
        'Kosongkan daftar dulu untuk ganti kategori.',
      );
      return;
    }
    setState(() {
      _itemCategory = value;
      _selectedItem = null;
      _unitSpareparts = [];
      if (value == 'TOOLS') _selectedJobContext = null;
      _syncTrxType();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _handle(),
                SizedBox(height: 14),
                _title(),
                SizedBox(height: 14),
                if (_isLinked) ...[
                  _jobBanner(),
                  SizedBox(height: 16),
                ] else if (_itemCategory == 'SPARE_PART') ...[
                  _jobPickerTile(required: true),
                  SizedBox(height: 16),
                ] else if (_itemCategory == 'BAHAN') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _bahanModeButton(
                          active: _bahanForJobdesc,
                          label: 'Untuk Jobdesc',
                          icon: Icons.link_rounded,
                          onTap: () => setState(() => _bahanForJobdesc = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _bahanModeButton(
                          active: !_bahanForJobdesc,
                          label: 'Workshop',
                          icon: Icons.factory_outlined,
                          onTap: () => setState(() {
                            _bahanForJobdesc = false;
                            _selectedJobContext = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_bahanForJobdesc)
                    _jobPickerTile(required: true)
                  else
                    _infoBox(
                      'Bahan default untuk workshop (bukan unit/jobdesc).',
                    ),
                  SizedBox(height: 16),
                ],
                _label('Kategori Barang'),
                SizedBox(height: 8),
                _categoryRow(),
                SizedBox(height: 14),
                if (_itemCategory == 'SPARE_PART') ...[
                  _infoBox(
                    _transactionType == 'PEMINJAMAN'
                        ? 'Tipe: Peminjaman.'
                        : 'Tipe: Pengambilan.',
                  ),
                  SizedBox(height: 14),
                  if (_transactionType == 'PENGAMBILAN') ...[
                    SwitchListTile.adaptive(
                      value: _installToUnit,
                      activeThumbColor: AppColors.gold,
                      activeTrackColor: AppColors.gold.withValues(alpha: 0.35),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Langsung dipasang ke unit',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Gunakan bila barang langsung terpasang.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      onChanged: (v) => setState(() => _installToUnit = v),
                    ),
                    SizedBox(height: 8),
                  ],
                ] else ...[
                  _infoBox(
                    _itemCategory == 'BAHAN'
                        ? 'ACC: Ketua Divisi → Kepala Gudang → PPIC.'
                        : 'Tools langsung ke admin gudang.',
                  ),
                  SizedBox(height: 14),
                ],
                _label('Nama Barang'),
                SizedBox(height: 8),
                if (_itemCategory == 'SPARE_PART' && _jobContext != null)
                  _unitSparepartPicker()
                else
                  WarehouseItemSearchField(
                    controller: _nameCtrl,
                    category: _itemCategory,
                    hintText: _hintName,
                    onSelected: _onItemSelected,
                    carId: _itemCategory == 'SPARE_PART'
                        ? _jobContext?.carId
                        : null,
                  ),
                SizedBox(height: 8),
                _infoBox(
                  _itemCategory == 'SPARE_PART'
                      ? 'Wajib pilih sparepart dari daftar stok gudang.'
                      : 'Pilih dari stok gudang bila ada. Kalau belum tahu nama pastinya, tulis saja nama lapangan. Nama bisa dikoreksi saat approval atau saat gudang menyiapkan barang.',
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Jumlah'),
                          SizedBox(height: 8),
                          TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.numbers_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              hintText: '1',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Satuan'),
                          SizedBox(height: 8),
                          TextField(
                            controller: _uomCtrl,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(hintText: 'PCS'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _addItemButton(),
                if (_draftItems.isNotEmpty) ...[
                  SizedBox(height: 14),
                  _draftList(),
                ],
                SizedBox(height: 14),
                _label(
                  _itemCategory == 'BAHAN' && !_bahanForJobdesc
                      ? 'Catatan (wajib)'
                      : _draftItems.length > 1
                      ? 'Catatan (semua item)'
                      : 'Catatan (opsional)',
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 3,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Catatan tambahan bila diperlukan',
                    prefixIcon: Icon(
                      Icons.notes_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(height: 20),
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
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _title() => Row(
    children: [
      Icon(Icons.warehouse_outlined, color: AppColors.gold, size: 20),
      SizedBox(width: 8),
      Text(
        _isLinked ? 'Ajukan Barang untuk Pekerjaan' : 'Ajukan Barang',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );

  Widget _label(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 0.3,
    ),
  );

  Widget _infoBox(String msg) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ],
    ),
  );

  Widget _jobBanner() {
    final ctx = _jobContext!;
    final today = DateTime.now();
    final todayD = DateTime(today.year, today.month, today.day);
    final isToday =
        ctx.targetSearchDate == null ||
        (DateTime(
              ctx.targetSearchDate!.year,
              ctx.targetSearchDate!.month,
              ctx.targetSearchDate!.day,
            ) ==
            todayD);
    final diffDays = ctx.targetSearchDate == null
        ? 0
        : DateTime(
            ctx.targetSearchDate!.year,
            ctx.targetSearchDate!.month,
            ctx.targetSearchDate!.day,
          ).difference(todayD).inDays;
    final isTomorrow = diffDays == 1;
    final dateLabel = isToday
        ? null
        : isTomorrow
        ? 'Besok'
        : '${ctx.targetSearchDate!.day}/${ctx.targetSearchDate!.month}/${ctx.targetSearchDate!.year}';
    final isOvertime = ctx.isOvertime ?? !isToday;

    final accentColor = isOvertime
        ? AppColors.statusInProgress
        : AppColors.gold;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOvertime ? Icons.nightlight_round : Icons.link_rounded,
                size: 13,
                color: accentColor,
              ),
              SizedBox(width: 6),
              Text(
                isOvertime
                    ? 'Task lembur${dateLabel != null ? " ($dateLabel)" : ""}'
                    : 'Terkait pekerjaan aktif',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              if (dateLabel != null && !isOvertime) ...[
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 6),
          Text(
            ctx.unitName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${ctx.panelName}  ·  ${ctx.jobName}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobPickerTile({required bool required}) {
    final ctx = _jobContext;
    return InkWell(
      onTap: _pickJob,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 16,
              color: AppColors.gold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    required
                        ? 'Pilih Pekerjaan (wajib)'
                        : 'Pilih Pekerjaan (opsional)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ctx == null
                        ? (required ? 'Wajib pilih jobdesc' : 'Opsional pilih jobdesc')
                        : '${ctx.unitName} · ${ctx.panelName} · ${ctx.jobName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bahanModeButton({
    required bool active,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.gold.withValues(alpha: 0.15)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? AppColors.gold : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: active ? AppColors.gold : AppColors.textMuted),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.gold : AppColors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _unitSparepartPicker() {
    if (_isLoadingUnitItems) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
          ),
        ),
      );
    }
    if (_unitSpareparts.length <= 3 && _unitSpareparts.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<WarehouseItemSuggestion>(
            initialValue: _unitSpareparts.contains(_selectedItem)
                ? _selectedItem
                : null,
            dropdownColor: AppColors.surfaceCard,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Pilih sparepart unit',
            ),
            items: _unitSpareparts
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.itemName),
                  ),
                )
                .toList(),
            onChanged: (item) {
              if (item != null) _onItemSelected(item);
            },
          ),
          if (_selectedItem != null) ...[
            const SizedBox(height: 8),
            _SelectedItemPreview(item: _selectedItem!),
          ],
        ],
      );
    }
    return WarehouseItemSearchField(
      controller: _nameCtrl,
      category: 'SPARE_PART',
      hintText: _hintName,
      onSelected: _onItemSelected,
      carId: _jobContext?.carId,
    );
  }

  Widget _categoryRow() {
    final items = [
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
              onTap: () => _handleCategoryChange(e.$1),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? AppColors.gold.withValues(alpha: 0.7)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      e.$3,
                      size: 18,
                      color: active ? AppColors.gold : AppColors.textMuted,
                    ),
                    SizedBox(height: 4),
                    Text(
                      e.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? AppColors.gold : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _addItemButton() => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _isSaving ? null : _addItem,
      icon: Icon(Icons.add_rounded, size: 18),
      label: Text(
        'Tambah ke Daftar',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
    ),
  );

  Widget _draftList() => Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Daftar Item',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_draftItems.length} item',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        ..._draftItems.map(_draftItemTile),
      ],
    ),
  );

  Widget _draftItemTile(_WarehouseDraftItem item) => Container(
    margin: EdgeInsets.only(bottom: 8),
    padding: EdgeInsets.fromLTRB(10, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: AppColors.gold,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '${_formatQty(item.qty)} ${item.uom}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              if (item.itemMasterId != null) ...[
                SizedBox(height: 3),
                Text(
                  'Tersambung ke stok gudang',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: _isSaving
              ? null
              : () => setState(() => _draftItems.remove(item)),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.close_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
        ),
      ],
    ),
  );

  Widget _submitButton() => FilledButton.icon(
    onPressed: _isSaving ? null : _submit,
    icon: _isSaving
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(Icons.send_rounded, size: 18),
    label: Text(
      _isSaving
          ? 'Mengirim...'
          : _draftItems.isEmpty
          ? 'Ajukan'
          : 'Ajukan ${_draftItems.length} Item',
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.background,
      padding: EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  String get _hintName => _itemCategory == 'SPARE_PART'
      ? 'cth: Kampas Rem Depan'
      : _itemCategory == 'BAHAN'
      ? 'cth: Cat Primer 2K'
      : 'cth: Kunci Torsi';

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toString();

  bool get _hasPendingFormInput => _nameCtrl.text.trim().isNotEmpty;

  _WarehouseDraftItem? _buildDraftItem({required bool showError}) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (showError) {
        AppNotification.showError(context, 'Nama barang tidak boleh kosong.');
      }
      return null;
    }
    if (_itemCategory == 'SPARE_PART' && _selectedItem == null) {
      if (showError) {
        AppNotification.showError(
          context,
          'Sparepart wajib dipilih dari daftar stok gudang.',
        );
      }
      return null;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      if (showError) {
        AppNotification.showError(context, 'Jumlah harus lebih dari 0.');
      }
      return null;
    }
    return _WarehouseDraftItem(
      itemName: name,
      qty: qty,
      uom: _uomCtrl.text.trim().isNotEmpty ? _uomCtrl.text.trim() : 'PCS',
      itemMasterId: _selectedItem?.id,
    );
  }

  void _clearItemInputs() {
    _nameCtrl.clear();
    _qtyCtrl.text = '1';
    _uomCtrl.text = 'PCS';
    _selectedItem = null;
  }

  void _addItem() {
    final item = _buildDraftItem(showError: true);
    if (item == null) return;
    setState(() {
      _draftItems.add(item);
      _clearItemInputs();
    });
  }

  List<_PendingWarehouseSubmitItem> _collectSubmitItems() {
    final items = <_PendingWarehouseSubmitItem>[
      ..._draftItems.map((item) => _PendingWarehouseSubmitItem(item: item)),
    ];

    if (_draftItems.isEmpty) {
      final current = _buildDraftItem(showError: true);
      if (current == null) return [];
      items.add(_PendingWarehouseSubmitItem(item: current, fromForm: true));
      return items;
    }

    if (_hasPendingFormInput) {
      final current = _buildDraftItem(showError: true);
      if (current == null) return [];
      items.add(_PendingWarehouseSubmitItem(item: current, fromForm: true));
    }

    return items;
  }

  Future<void> _submit() async {
    final effectiveJob = _jobContext;
    final bahanWorkshop = _itemCategory == 'BAHAN' && !_bahanForJobdesc;
    if (_itemCategory != 'TOOLS' && !bahanWorkshop && effectiveJob == null) {
      AppNotification.showError(
        context,
        'Pilih pekerjaan/jobdesc terlebih dahulu.',
      );
      return;
    }
    if (bahanWorkshop && _notesCtrl.text.trim().isEmpty) {
      AppNotification.showError(
        context,
        'Catatan wajib diisi untuk bahan workshop.',
      );
      return;
    }
    final submitItems = _collectSubmitItems();
    if (submitItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final session = sl<SessionManager>();
      final repo = sl<WarehouseRepository>();
      final ctx = effectiveJob;
      final submittedDraftItems = <_WarehouseDraftItem>[];
      var submittedFormItem = false;
      var submittedCount = 0;
      final notesValue = _notesCtrl.text.trim().isNotEmpty
          ? _notesCtrl.text.trim()
          : null;

      for (final entry in submitItems) {
        try {
          await repo.createTransaction(
            transactionType: _transactionType,
            itemCategory: _itemCategory,
            itemName: entry.item.itemName,
            qty: entry.item.qty,
            uom: entry.item.uom,
            requester: session.fullName ?? '-',
            division: session.divisionName ?? '-',
            divisionId: session.divisionId ?? 0,
            employeeId: session.userId ?? '-',
            carId: ctx?.carId ?? _selectedCarId,
            coreId: ctx?.coreId,
            unitName: ctx?.unitName ??
                (bahanWorkshop ? 'WORKSHOP' : _selectedUnitName),
            panelName: ctx?.panelName,
            jobdesc: ctx?.jobName,
            itemMasterId: entry.item.itemMasterId,
            installToUnit: _installToUnit,
            targetSearchDate: DateTime.now().add(Duration(days: 4)),
            deadlineDate: ctx?.deadlineDate,
            notes: notesValue,
          );
          submittedCount += 1;
          if (entry.fromForm) {
            submittedFormItem = true;
          } else {
            submittedDraftItems.add(entry.item);
          }
        } catch (e) {
          if (submittedDraftItems.isNotEmpty || submittedFormItem) {
            setState(() {
              _draftItems.removeWhere(submittedDraftItems.contains);
              if (submittedFormItem) _clearItemInputs();
            });
          }
          if (mounted) {
            final prefix = submittedCount > 0
                ? '$submittedCount item berhasil. '
                : '';
            AppNotification.showError(
              context,
              '$prefix${friendlyMessage(e, fallback: 'Gagal di ${entry.item.itemName}')}',
            );
          }
          return;
        }
      }

      if (submittedDraftItems.isNotEmpty || submittedFormItem) {
        setState(() {
          _draftItems.removeWhere(submittedDraftItems.contains);
          if (submittedFormItem) _clearItemInputs();
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final successMessage = submittedCount == 1
              ? '1 item berhasil diajukan'
              : '$submittedCount item berhasil diajukan';
          AppNotification.showSuccess(context, successMessage);
        }
      });
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal mengajukan barang'),
        );
      }
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
      builder: (_) => WarehouseStorageSheet._(),
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
  WarehouseJobContext? _jobContext;
  final List<String> _photoPaths = [];
  final List<String> _photoUrls = [];
  bool _isUploadingPhoto = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _pickJob() async {
    final ctx = await ActiveJobPicker.show(context);
    if (!mounted || ctx == null) return;
    setState(() => _jobContext = ctx);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                // Title
                Row(
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      color: Color(0xFF5B8EFF),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Simpan ke Gudang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Simpan barang yang sudah dilepas ke gudang.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 16),

                // Jobdesc
                _label('Pekerjaan / Unit'),
                SizedBox(height: 8),
                _storageJobPickerTile(),
                SizedBox(height: 14),

                // Nama Part
                _label('Nama Part / Barang'),
                SizedBox(height: 8),
                WarehouseItemSearchField(
                  controller: _nameCtrl,
                  category: 'SPARE_PART',
                  hintText: 'cth: Pintu Kanan, Bumper Depan',
                  onSelected: _onItemSelected,
                  carId: _jobContext?.carId,
                ),
                SizedBox(height: 14),

                // Kondisi
                _label('Kondisi Barang'),
                SizedBox(height: 8),
                _conditionRow(),
                SizedBox(height: 14),

                _label('Foto Barang'),
                SizedBox(height: 8),
                _photoPicker(),
                SizedBox(height: 14),

                // Catatan
                _label('Catatan (opsional)'),
                SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 3,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Catatan tambahan bila diperlukan',
                    prefixIcon: Icon(
                      Icons.notes_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.archive_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Mengirim...' : 'Ajukan Penyimpanan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFF5B8EFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 0.3,
    ),
  );

  Widget _storageJobPickerTile() {
    final ctx = _jobContext;
    return InkWell(
      onTap: _pickJob,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.link_rounded,
              size: 16,
              color: Color(0xFF5B8EFF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Pekerjaan (wajib)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ctx == null
                        ? 'Wajib pilih jobdesc'
                        : '${ctx.unitName} · ${ctx.panelName} · ${ctx.jobName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionRow() {
    final opts = ['GOOD', 'DAMAGED', 'SCRAP'];
    final labels = ['Baik', 'Rusak', 'Scrap'];
    final colors = [
      AppColors.statusDone,
      AppColors.statusInProgress,
      AppColors.statusLocked,
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
                duration: Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? colors[i].withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? colors[i] : AppColors.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? colors[i] : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
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
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                )
              : Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(
            _isUploadingPhoto ? 'Mengupload...' : 'Ambil Foto',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.border),
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (_photoPaths.isNotEmpty) ...[
          SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoPaths.length,
              separatorBuilder: (context, index) => SizedBox(width: 8),
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
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else
          Padding(
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
        builder: (_) => InAppCameraPage(
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
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Upload foto gagal'),
        );
      }
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
    final ctx = _jobContext;
    if (ctx == null) {
      AppNotification.showError(
        context,
        'Pilih pekerjaan/jobdesc terlebih dahulu.',
      );
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
        carId: ctx.carId,
        coreId: ctx.coreId,
        unitName: ctx.unitName,
        panelName: ctx.panelName,
        jobdesc: ctx.jobName,
        itemCondition: _condition,
        photoUrls: _photoUrls.isEmpty ? null : _photoUrls,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          AppNotification.showSuccess(context, '$name berhasil diajukan');
        }
      });
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal mengajukan barang'),
        );
      }
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
    this.carId,
  });

  final TextEditingController controller;
  final String category;
  final String hintText;
  final ValueChanged<WarehouseItemSuggestion?> onSelected;
  final String? carId;

  @override
  State<WarehouseItemSearchField> createState() =>
      _WarehouseItemSearchFieldState();
}

class _WarehouseItemSearchFieldState extends State<WarehouseItemSearchField> {
  Timer? _debounce;
  List<WarehouseItemSuggestion> _items = [];
  WarehouseItemSuggestion? _selected;
  bool _isLoading = false;

  List<WarehouseItemSuggestion> _sortSuggestions(
    List<WarehouseItemSuggestion> items,
  ) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final aHasStock = a.stockQty > 0;
      final bHasStock = b.stockQty > 0;
      if (aHasStock != bHasStock) {
        return aHasStock ? -1 : 1;
      }
      final stockCompare = b.stockQty.compareTo(a.stockQty);
      if (stockCompare != 0) return stockCompare;
      return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
    });
    return sorted;
  }

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
      setState(() => _items = []);
      return;
    }

    _debounce = Timer(Duration(milliseconds: 350), () async {
      setState(() => _isLoading = true);
      try {
        final repo = sl<WarehouseRepository>();
        final items = await repo.searchItems(
          query: query,
          category: widget.category,
          carId: widget.carId,
        );
        if (!mounted) return;
        setState(() => _items = _sortSuggestions(items));
      } catch (_) {
        if (!mounted) return;
        setState(() => _items = []);
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
      _items = [];
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
          style: TextStyle(color: AppColors.textPrimary),
          textCapitalization: TextCapitalization.words,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
            suffixIcon: _isLoading
                ? Padding(
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
          SizedBox(height: 8),
          _SelectedItemPreview(item: _selected!),
        ],
        if (_items.isNotEmpty) ...[
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _items.map((item) {
                final hasStock = item.stockQty > 0;
                return InkWell(
                  onTap: () => _pick(item),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Opacity(
                      opacity: hasStock ? 1 : 0.62,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SuggestionPhoto(photoUrls: item.photoUrls),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${item.itemCategory} · ${item.uom}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                if (item.lastLocation?.isNotEmpty ?? false)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Lokasi: ${item.lastLocation}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF5B8EFF),
                                      ),
                                    ),
                                  ),
                                if (item.matchedAlias?.isNotEmpty ?? false)
                                  Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Alias: ${item.matchedAlias}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          _StockQtyBadge(
                            stockQty: item.stockQty,
                            uom: item.uom,
                          ),
                        ],
                      ),
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
    final hasStock = item.stockQty > 0;
    final stockLabel = item.stockQty % 1 == 0
        ? item.stockQty.toInt().toString()
        : item.stockQty.toString();
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SuggestionPhoto(photoUrls: item.photoUrls),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${item.itemCode} · ${item.uom}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (item.lastLocation?.isNotEmpty ?? false)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      item.lastLocation!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5B8EFF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: hasStock
                  ? AppColors.statusDone.withValues(alpha: 0.12)
                  : AppColors.statusLocked.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasStock
                    ? AppColors.statusDone.withValues(alpha: 0.4)
                    : AppColors.statusLocked.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Text(
                  hasStock ? stockLabel : '0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasStock
                        ? AppColors.statusDone
                        : AppColors.statusLocked,
                  ),
                ),
                Text(
                  hasStock ? 'Stok' : 'Habis',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: hasStock
                        ? AppColors.statusDone
                        : AppColors.statusLocked,
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
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: AppColors.textMuted,
        ),
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
          child: Icon(
            Icons.broken_image_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _StockQtyBadge extends StatelessWidget {
  const _StockQtyBadge({required this.stockQty, required this.uom});

  final double stockQty;
  final String uom;

  @override
  Widget build(BuildContext context) {
    final hasStock = stockQty > 0;
    final label = stockQty % 1 == 0
        ? stockQty.toInt().toString()
        : stockQty.toString();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: hasStock
            ? AppColors.statusDone.withValues(alpha: 0.12)
            : AppColors.statusLocked.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasStock
              ? AppColors.statusDone.withValues(alpha: 0.4)
              : AppColors.statusLocked.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasStock ? label : '0',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: hasStock ? AppColors.statusDone : AppColors.statusLocked,
            ),
          ),
          Text(
            hasStock ? 'Stok' : 'Habis',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: hasStock ? AppColors.statusDone : AppColors.statusLocked,
            ),
          ),
        ],
      ),
    );
  }
}
