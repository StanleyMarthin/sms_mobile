// Form create Work Order Vendor — mengikuti pola visual form lama,
// tetapi mendukung multi item seperti PR.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/datasources/remote_wov_datasource.dart';

class WovFormPage extends StatefulWidget {
  const WovFormPage({super.key});
  @override
  State<WovFormPage> createState() => _WovFormPageState();
}

class _WovItemRow {
  final itemNameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final uomCtrl = TextEditingController(text: 'Pcs');
  final goodsConditionOutCtrl = TextEditingController();

  bool get isValid => itemNameCtrl.text.trim().isNotEmpty;

  Map<String, dynamic> toPayload() => {
    'itemName': itemNameCtrl.text.trim(),
    if (double.tryParse(qtyCtrl.text.trim()) != null)
      'quantity': double.tryParse(qtyCtrl.text.trim()),
    if (uomCtrl.text.trim().isNotEmpty) 'uom': uomCtrl.text.trim(),
    if (goodsConditionOutCtrl.text.trim().isNotEmpty)
      'goodsConditionOut': goodsConditionOutCtrl.text.trim(),
  };

  void dispose() {
    itemNameCtrl.dispose();
    qtyCtrl.dispose();
    uomCtrl.dispose();
    goodsConditionOutCtrl.dispose();
  }
}

class _WovFormPageState extends State<WovFormPage> {
  late final RemoteWovDataSource _ds;

  String? _carId, _carName;
  String? _divisionId, _divisionName;
  List<Map<String, dynamic>> _cars = [];
  List<Map<String, dynamic>> _divisions = [];
  bool _lockDivisionToOwn = false;

  List<Map<String, dynamic>> _vendors = [];
  String? _vendorId, _vendorName;

  final _picVendorCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final List<_WovItemRow> _items = [_WovItemRow()];
  DateTime? _targetDateReturn;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ds = RemoteWovDataSource(apiClient: sl(), sessionManager: sl());

    final session = sl<SessionManager>();
    _lockDivisionToOwn = _shouldLockDivision(session);
    if (_lockDivisionToOwn) {
      _divisionId = session.divisionId?.toString();
      _divisionName = session.divisionName;
    }

    _loadCars();
    _loadVendors();
  }

  bool _shouldLockDivision(SessionManager session) {
    String normalize(String? value) => (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    final role = normalize(session.role);
    final jabatan = normalize(session.jabatan);
    return role == 'kd' ||
        role == 'ketua_divisi' ||
        role == 'kp' ||
        role == 'kepala_produksi' ||
        jabatan == 'kp' ||
        jabatan == 'kepala_produksi';
  }

  List<Map<String, dynamic>> _resolveDivisionOptions(
    List<Map<String, dynamic>> source,
  ) {
    if (!_lockDivisionToOwn) return source;
    final ownId = _divisionId;
    final ownName = _divisionName?.trim();
    final filtered = source.where((division) {
      final idMatch = ownId != null && division['id'].toString() == ownId;
      final nameMatch =
          ownName != null &&
          ownName.isNotEmpty &&
          (division['name']?.toString().trim().toLowerCase() ?? '') ==
              ownName.toLowerCase();
      return idMatch || nameMatch;
    }).toList();
    if (filtered.isNotEmpty) return filtered;
    if (ownId == null && (ownName == null || ownName.isEmpty)) return const [];
    return [
      {'id': ownId ?? '', 'name': ownName ?? 'Divisi Saya'},
    ];
  }

  Future<void> _loadCars() async {
    try {
      final res = await sl<ApiClient>().get(ApiEndpoints.jobPlanDropdowns);
      final data = res.data['data'] ?? res.data;
      if (data != null && mounted) {
        final divisions = data['divisions'] is List
            ? List<Map<String, dynamic>>.from(data['divisions'])
            : <Map<String, dynamic>>[];
        setState(() {
          if (data['cars'] is List) {
            _cars = List<Map<String, dynamic>>.from(data['cars']);
          }
          _divisions = _resolveDivisionOptions(divisions);

          if (_lockDivisionToOwn &&
              _divisionId != null &&
              (_divisionName == null || _divisionName!.isEmpty)) {
            final div = _divisions
                .where((d) => d['id'].toString() == _divisionId)
                .firstOrNull;
            if (div != null) _divisionName = div['name'] as String?;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadVendors() async {
    try {
      final res = await sl<ApiClient>().get('/sm/vendors');
      final data = res.data['data'] ?? res.data;
      if (data != null && data is List && mounted) {
        setState(() => _vendors = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _picVendorCtrl.dispose();
    _remarksCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_carId == null) {
      _snack('Pilih unit terlebih dahulu', isError: true);
      return;
    }
    if (_vendorName == null || _vendorName!.isEmpty) {
      _snack('Pilih Vendor terlebih dahulu', isError: true);
      return;
    }

    final validItems = _items.where((item) => item.isValid).toList();
    if (validItems.isEmpty) {
      _snack('Minimal satu item wajib diisi', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _ds.createWov(
        carId: _carId!,
        carName: _carName,
        divisionName: _divisionName?.isNotEmpty == true ? _divisionName : null,
        vendorId: _vendorId,
        vendorName: _vendorName!,
        picVendor: _picVendorCtrl.text.trim().isNotEmpty
            ? _picVendorCtrl.text.trim()
            : null,
        targetDateReturn: _targetDateReturn?.toIso8601String().split('T').first,
        remarks: _remarksCtrl.text.trim().isNotEmpty
            ? _remarksCtrl.text.trim()
            : null,
        items: validItems.map((item) => item.toPayload()).toList(),
      );
      if (mounted) {
        final message = validItems.length > 1
            ? '${validItems.length} item WO Vendor berhasil dibuat!'
            : 'Work Order Vendor berhasil dibuat!';
        _snack(message);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? AppColors.statusLocked
            : AppColors.statusDone,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textMuted),
        title: const Text(
          'Buat WO Vendor',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: _isSubmitting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [
                      _sectionLabel('Unit Kendaraan *'),
                      _carPicker(),
                      const SizedBox(height: 16),
                      _sectionLabel('Divisi'),
                      _divisionPicker(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _sectionLabel('Informasi Pekerjaan / Barang *'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _items.add(_WovItemRow())),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: AppColors.gold,
                            ),
                            label: const Text(
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
                      ...List.generate(_items.length, _buildItemForm),
                      const SizedBox(height: 16),
                      _sectionLabel('Informasi Vendor *'),
                      _vendorPicker(),
                      const SizedBox(height: 10),
                      _inputField(
                        'PIC Vendor (Kontak)',
                        _picVendorCtrl,
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      _sectionLabel('Target Tanggal Kembali'),
                      _datePickerField(),
                      const SizedBox(height: 16),
                      _sectionLabel('Informasi Tambahan'),
                      _inputDecor(
                        TextField(
                          controller: _remarksCtrl,
                          maxLines: 3,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Keterangan / Catatan',
                            hintStyle: TextStyle(
                              color: AppColors.textDisabled,
                              fontSize: 12,
                            ),
                            prefixIcon: Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(4, 12, 14, 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: const Border(
                      top: BorderSide(color: AppColors.borderSubtle),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Ajukan WOV',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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
              ],
            ),
    );
  }

  Widget _buildItemForm(int idx) {
    final item = _items[idx];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Item ${idx + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 20,
                      color: AppColors.statusLocked,
                    ),
                    onPressed: () => setState(() {
                      _items[idx].dispose();
                      _items.removeAt(idx);
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              children: [
                _inputField(
                  'Nama Pekerjaan / Barang *',
                  item.itemNameCtrl,
                  icon: Icons.engineering_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _inputField(
                        'Qty',
                        item.qtyCtrl,
                        icon: Icons.numbers_rounded,
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _inputField(
                        'Satuan',
                        item.uomCtrl,
                        icon: Icons.straighten_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _inputField(
                  'Kondisi Barang Keluar',
                  item.goodsConditionOutCtrl,
                  icon: Icons.info_outline_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    TextInputType? keyboard,
  }) => _inputDecor(
    TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        prefixIcon: icon != null
            ? Icon(icon, size: 16, color: AppColors.textMuted)
            : null,
        border: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(icon != null ? 4 : 14, 12, 14, 12),
      ),
    ),
  );

  Widget _inputDecor(Widget child) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceInput,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _datePickerField() => InkWell(
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: _targetDateReturn ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.background,
              surface: AppColors.surfaceCard,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.surfaceCard,
            ),
          ),
          child: child!,
        ),
      );
      if (date != null && mounted) {
        setState(() => _targetDateReturn = date);
      }
    },
    borderRadius: BorderRadius.circular(10),
    child: _inputDecor(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
        child: Row(
          children: [
            const Icon(
              Icons.event_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _targetDateReturn != null
                    ? DateFormat(
                        'EEEE, d MMMM yyyy',
                        'id_ID',
                      ).format(_targetDateReturn!)
                    : 'Target Tanggal Kembali',
                style: TextStyle(
                  fontSize: 13,
                  color: _targetDateReturn != null
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _carPicker() {
    return _inputDecor(
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _carId,
          hint: Text(
            _cars.isEmpty ? 'Memuat unit...' : 'Pilih Unit Kendaraan',
            style: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
          ),
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.textMuted,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          items: _cars
              .map(
                (car) => DropdownMenuItem<String>(
                  value: car['id'].toString(),
                  child: Text('${car['unit_name']} - ${car['police_number']}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final car = _cars.firstWhere(
              (item) => item['id'].toString() == value,
            );
            setState(() {
              _carId = value;
              _carName = car['unit_name'] as String;
            });
          },
        ),
      ),
    );
  }

  Widget _divisionPicker() {
    return _inputDecor(
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _divisionId,
          hint: Text(
            _divisions.isEmpty ? 'Memuat divisi...' : 'Pilih Divisi',
            style: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
          ),
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: _lockDivisionToOwn
              ? const SizedBox.shrink()
              : const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.textMuted,
                ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          items: _divisions
              .map(
                (division) => DropdownMenuItem<String>(
                  value: division['id'].toString(),
                  child: Text(division['name'] as String),
                ),
              )
              .toList(),
          onChanged: _lockDivisionToOwn
              ? null
              : (value) {
                  if (value == null) return;
                  final division = _divisions.firstWhere(
                    (item) => item['id'].toString() == value,
                  );
                  setState(() {
                    _divisionId = value;
                    _divisionName = division['name'] as String;
                  });
                },
        ),
      ),
    );
  }

  Widget _vendorPicker() {
    return _inputDecor(
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _vendorId,
          hint: Text(
            _vendors.isEmpty ? 'Memuat vendor...' : 'Pilih Vendor',
            style: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
          ),
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.textMuted,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          items: _vendors
              .map(
                (vendor) => DropdownMenuItem<String>(
                  value: vendor['id'].toString(),
                  child: Text(vendor['vendor_name'] as String),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final vendor = _vendors.firstWhere(
              (item) => item['id'].toString() == value,
            );
            setState(() {
              _vendorId = value;
              _vendorName = vendor['vendor_name'] as String;
            });
          },
        ),
      ),
    );
  }
}
