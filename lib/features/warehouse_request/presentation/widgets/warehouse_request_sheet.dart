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

class _WarehouseDraftItem {
  const _WarehouseDraftItem({
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
  const _PendingWarehouseSubmitItem({
    required this.item,
    this.fromForm = false,
  });

  final _WarehouseDraftItem item;
  final bool fromForm;
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
  final List<_WarehouseDraftItem> _draftItems = [];
  WarehouseItemSuggestion? _selectedItem;

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
      _syncTrxType();
    });
  }

  void _handleTransactionChange(String value) {
    if (_draftItems.isNotEmpty) {
      AppNotification.showWarning(
        context,
        'Kirim atau hapus daftar dulu untuk ganti tipe.',
      );
      return;
    }
    setState(() {
      _transactionType = value;
      if (_transactionType != 'PENGAMBILAN') _installToUnit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  const SizedBox(height: 16),
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
                      title: const Text(
                        'Langsung dipasang ke unit',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Gunakan bila barang langsung terpasang.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      onChanged: (v) => setState(() => _installToUnit = v),
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else ...[
                  _infoBox(
                    _itemCategory == 'BAHAN'
                        ? 'ACC: Ketua Divisi → Kepala Gudang → PPIC.'
                        : 'Tools langsung ke admin gudang.',
                  ),
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
                const SizedBox(height: 8),
                _infoBox(
                  'Pilih dari stok gudang bila ada. Kalau belum tahu nama pastinya, tulis saja nama lapangan. Nama bisa dikoreksi saat approval atau saat gudang menyiapkan barang.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
                              decimal: true,
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(hintText: 'PCS'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _addItemButton(),
                if (_draftItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _draftList(),
                ],
                const SizedBox(height: 14),
                _label(
                  _draftItems.length > 1
                      ? 'Catatan (semua item)'
                      : 'Catatan (opsional)',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 3,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Catatan tambahan bila diperlukan',
                    prefixIcon: Icon(
                      Icons.notes_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
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
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _title() => Row(
    children: [
      const Icon(Icons.warehouse_outlined, color: AppColors.gold, size: 20),
      const SizedBox(width: 8),
      Text(
        _isLinked ? 'Ajukan Barang untuk Pekerjaan' : 'Ajukan Barang',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 0.3,
    ),
  );

  Widget _infoBox(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ],
    ),
  );

  Widget _jobBanner() {
    final ctx = widget.jobContext!;
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
    final isOvertime = !isToday;

    final accentColor = isOvertime
        ? AppColors.statusInProgress
        : AppColors.gold;
    return Container(
      padding: const EdgeInsets.all(12),
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
              const SizedBox(width: 6),
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
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
          const SizedBox(height: 6),
          Text(
            ctx.unitName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${ctx.panelName}  ·  ${ctx.jobName}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
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
              onTap: () => _handleCategoryChange(e.$1),
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
                    const SizedBox(height: 4),
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
              onTap: () => _handleTransactionChange(e.$1),
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
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      e.$3,
                      size: 16,
                      color: active ? AppColors.gold : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      e.$2,
                      style: TextStyle(
                        fontSize: 12,
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

  Widget _unitDropdown() {
    if (_isLoadingCars) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedCarId,
      dropdownColor: AppColors.surfaceCard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      iconEnabledColor: AppColors.textMuted,
      isExpanded: true,
      decoration: const InputDecoration(hintText: 'Pilih Unit / Kendaraan'),
      items: _apiCars
          .map(
            (car) => DropdownMenuItem(
              value: car['id'] as String,
              child: Text('${car['unit_name']} - ${car['customer_name']}'),
            ),
          )
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

  Widget _addItemButton() => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _isSaving ? null : _addItem,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        'Tambah ke Daftar',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
    ),
  );

  Widget _draftList() => Container(
    padding: const EdgeInsets.all(12),
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
            const Text(
              'Daftar Item',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_draftItems.length} item',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._draftItems.map(_draftItemTile),
      ],
    ),
  );

  Widget _draftItemTile(_WarehouseDraftItem item) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
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
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatQty(item.qty)} ${item.uom}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              if (item.itemMasterId != null) ...[
                const SizedBox(height: 3),
                const Text(
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
          icon: const Icon(
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
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.send_rounded, size: 18),
    label: Text(
      _isSaving
          ? 'Mengirim...'
          : _draftItems.isEmpty
          ? 'Ajukan'
          : 'Ajukan ${_draftItems.length} Item',
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 14),
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
      if (current == null) return const [];
      items.add(_PendingWarehouseSubmitItem(item: current, fromForm: true));
      return items;
    }

    if (_hasPendingFormInput) {
      final current = _buildDraftItem(showError: true);
      if (current == null) return const [];
      items.add(_PendingWarehouseSubmitItem(item: current, fromForm: true));
    }

    return items;
  }

  Future<void> _submit() async {
    final needsJobReference =
        _itemCategory == 'BAHAN' || _itemCategory == 'SPARE_PART';
    if (!_isLinked && needsJobReference) {
      AppNotification.showError(
        context,
        'Peminjaman atau pengambilan bahan/sparepart harus dari pekerjaan aktif.',
      );
      return;
    }
    if (!_isLinked && _itemCategory != 'TOOLS' && _selectedCarId == null) {
      AppNotification.showError(
        context,
        'Pilih unit/kendaraan terlebih dahulu.',
      );
      return;
    }

    final submitItems = _collectSubmitItems();
    if (submitItems.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final session = sl<SessionManager>();
      final repo = sl<WarehouseRepository>();
      final ctx = widget.jobContext;
      final submittedDraftItems = <_WarehouseDraftItem>[];
      var submittedFormItem = false;
      var submittedCount = 0;

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
            unitName: ctx?.unitName ?? _selectedUnitName,
            panelName: ctx?.panelName,
            jobdesc: ctx?.jobName,
            itemMasterId: entry.item.itemMasterId,
            installToUnit: _installToUnit,
            targetSearchDate: DateTime.now().add(const Duration(days: 4)),
            deadlineDate: ctx?.deadlineDate,
            notes: _notesCtrl.text.trim().isNotEmpty
                ? _notesCtrl.text.trim()
                : null,
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
              '${prefix}Gagal di ${entry.item.itemName}: $e',
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Title
                const Row(
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
                const SizedBox(height: 4),
                const Text(
                  'Simpan barang yang sudah dilepas ke gudang.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
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
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Catatan tambahan bila diperlukan',
                    prefixIcon: Icon(
                      Icons.notes_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
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
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.archive_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Mengirim...' : 'Ajukan Penyimpanan',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5B8EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
      letterSpacing: 0.3,
    ),
  );

  Widget _unitDropdown() {
    if (_isLoadingCars) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF5B8EFF),
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedCarId,
      dropdownColor: AppColors.surfaceCard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      iconEnabledColor: AppColors.textMuted,
      isExpanded: true,
      decoration: const InputDecoration(hintText: 'Pilih Unit / Kendaraan'),
      items: _apiCars
          .map(
            (car) => DropdownMenuItem(
              value: car['id'] as String,
              child: Text('${car['unit_name']} - ${car['customer_name']}'),
            ),
          )
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
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                        child: const Icon(
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
        setState(() => _items = _sortSuggestions(items));
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
            prefixIcon: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
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
                final hasStock = item.stockQty > 0;
                return InkWell(
                  onTap: () => _pick(item),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Opacity(
                      opacity: hasStock ? 1 : 0.62,
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
                                      'Lokasi: ${item.lastLocation}',
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
                                      'Alias: ${item.matchedAlias}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
        child: const Icon(
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
          child: const Icon(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
