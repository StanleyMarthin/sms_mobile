// Form create Purchase Request — mengikuti pola wo_create_page.dart.
// Dynamic items list (tambah/hapus), upload foto opsional per item.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/network/api_client.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/services/upload_service.dart';
import '../../data/datasources/remote_pr_datasource.dart';
import '../../data/models/pr_item.dart';

class PrFormPage extends StatefulWidget {
  const PrFormPage({super.key});
  @override
  State<PrFormPage> createState() => _PrFormPageState();
}

// ── Item row data holder ───────────────────────────────────────

class _ItemRow {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final uomCtrl = TextEditingController(text: 'Pcs');
  String originType = 'LOKAL';

  String? localPhotoPath;
  String? uploadedPhotoUrl;
  bool isUploading = false;

  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    qtyCtrl.dispose();
    uomCtrl.dispose();
  }

  bool get isValid => nameCtrl.text.trim().isNotEmpty;

  PRItem toItem() => PRItem(
    id: '',
    prId: '',
    itemName: nameCtrl.text.trim(),
    description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
    originType: originType,
    qty: double.tryParse(qtyCtrl.text.trim()),
    uom: uomCtrl.text.trim().isNotEmpty ? uomCtrl.text.trim() : null,
    photoUrl: uploadedPhotoUrl,
  );
}

// ── Page state ────────────────────────────────────────────────

class _PrFormPageState extends State<PrFormPage> {
  late final RemotePrDataSource _ds;
  final _notesCtrl = TextEditingController();

  String? _carId, _carName;
  String? _divisionId, _divisionName;
  DateTime? _targetDate;
  String _priority = 'NORMAL';
  List<Map<String, dynamic>> _cars = [];
  List<Map<String, dynamic>> _divisions = [];
  bool _lockDivisionToOwn = false;

  final List<_ItemRow> _items = [_ItemRow()];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ds = RemotePrDataSource(apiClient: sl(), sessionManager: sl());
    _loadCars();

    final session = sl<SessionManager>();
    _lockDivisionToOwn = _shouldLockDivision(session);
    if (_lockDivisionToOwn) {
      _divisionId = session.divisionId?.toString();
      _divisionName = session.divisionName;
    }
  }

  bool _shouldLockDivision(SessionManager session) {
    return session.isKdAccess || session.isKpAccess;
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
    if (ownId == null && (ownName == null || ownName.isEmpty)) return [];
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

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_carId == null) {
      _snack('Pilih unit terlebih dahulu', isError: true);
      return;
    }
    final valid = _items.where((r) => r.isValid).toList();
    if (valid.isEmpty) {
      _snack('Minimal satu item dengan nama', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final uploadSvc = sl<UploadService>();
      for (int i = 0; i < valid.length; i++) {
        final r = valid[i];
        if (r.localPhotoPath != null && r.uploadedPhotoUrl == null) {
          setState(() => r.isUploading = true);
          try {
            r.uploadedPhotoUrl = await uploadSvc.uploadPhoto(
              localPath: r.localPhotoPath!,
              unit: _carName ?? 'PR',
              division: _divisionName ?? 'PURCHASE',
              job: 'Item_${i + 1}',
              type: 'PR_Contoh',
            );
          } catch (e) {
            if (mounted) {
              _snack(
                friendlyMessage(e, fallback: 'Gagal upload foto item ${i + 1}'),
                isError: true,
              );
            }
            setState(() {
              r.isUploading = false;
              _isSubmitting = false;
            });
            return;
          }
          setState(() => r.isUploading = false);
        }
      }

      await _ds.createPr(
        carId: _carId!,
        carName: _carName,
        divisionId: _divisionId,
        divisionName: _divisionName?.isNotEmpty == true ? _divisionName : null,
        targetDate: _targetDate?.toIso8601String().split('T')[0],
        priority: _priority,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
        items: valid.map((r) => r.toItem()).toList(),
      );
      if (mounted) {
        _snack('Purchase Request berhasil dibuat!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _snack(
          friendlyMessage(e, fallback: 'Gagal menyimpan PR'),
          isError: true,
        );
      }
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

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: AppColors.textMuted),
        title: Text(
          'Buat Purchase Request',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: _isSubmitting
          ? Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [
                      _sectionLabel('Unit Kendaraan'),
                      _carPicker(),
                      SizedBox(height: 16),
                      _sectionLabel('Divisi'),
                      _divisionPicker(),
                      SizedBox(height: 16),
                      _sectionLabel('Informasi Tambahan'),
                      Row(
                        children: [
                          Expanded(child: _datePicker()),
                          SizedBox(width: 10),
                          Expanded(child: _priorityPicker()),
                        ],
                      ),
                      SizedBox(height: 10),
                      _fieldMultiline(
                        'Catatan / Keterangan',
                        Icons.sticky_note_2_outlined,
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          _sectionLabel('Daftar Item'),
                          Spacer(),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _items.add(_ItemRow())),
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
                      ...List.generate(_items.length, _buildItemForm),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
                // Submit button
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: Border(
                      top: BorderSide(color: AppColors.borderSubtle),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        'Ajukan PR',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
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
            style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
          ),
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.textMuted,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          items: _cars.map((c) {
            final String unitName = c['unit_name']?.toString() ?? '-';
            final String extraInfo =
                c['customer_name']?.toString() ??
                c['police_number']?.toString() ??
                '';
            final String displayText = extraInfo.isNotEmpty
                ? '$unitName - $extraInfo'
                : unitName;

            return DropdownMenuItem<String>(
              value: c['id'].toString(),
              child: Text(displayText),
            );
          }).toList(),
          onChanged: (v) {
            if (v == null) return;
            final c = _cars.firstWhere((x) => x['id'].toString() == v);
            setState(() {
              _carId = v;
              _carName = c['unit_name'] as String;
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
            style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
          ),
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: _lockDivisionToOwn
              ? SizedBox.shrink()
              : Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.textMuted,
                ),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          items: _divisions
              .map(
                (d) => DropdownMenuItem<String>(
                  value: d['id'].toString(),
                  child: Text(d['name'] as String),
                ),
              )
              .toList(),
          onChanged: _lockDivisionToOwn
              ? null
              : (v) {
                  if (v == null) return;
                  final d = _divisions.firstWhere(
                    (x) => x['id'].toString() == v,
                  );
                  setState(() {
                    _divisionId = v;
                    _divisionName = d['name'] as String;
                  });
                },
        ),
      ),
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate:
              _targetDate ?? DateTime.now().add(Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(Duration(days: 365)),
        );
        if (d != null) setState(() => _targetDate = d);
      },
      child: _inputDecor(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _targetDate != null
                      ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                      : 'Target Tgl',
                  style: TextStyle(
                    color: _targetDate != null
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityPicker() {
    return _inputDecor(
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _priority,
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.textMuted,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          items: [
            DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
            DropdownMenuItem(
              value: 'URGENT',
              child: Text('Urgent', style: TextStyle(color: AppColors.orange)),
            ),
          ],
          onChanged: (v) => setState(() => _priority = v ?? 'NORMAL'),
        ),
      ),
    );
  }

  Widget _buildItemForm(int idx) {
    final r = _items[idx];
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // Item header
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 6, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Item ${idx + 1}',
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
                      _items[idx].dispose();
                      _items.removeAt(idx);
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              children: [
                _inputField(
                  'Nama Sparepart / Barang *',
                  r.nameCtrl,
                  icon: Icons.inventory_2_outlined,
                ),
                SizedBox(height: 10),
                _inputField(
                  'Deskripsi / Keterangan',
                  r.descCtrl,
                  icon: Icons.description_outlined,
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _inputField(
                        'Qty',
                        r.qtyCtrl,
                        icon: Icons.numbers_rounded,
                        keyboard: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _inputField(
                        'Satuan',
                        r.uomCtrl,
                        icon: Icons.straighten_rounded,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                _inputDecor(
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: r.originType,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceCard,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      items: [
                        DropdownMenuItem(value: 'LOKAL', child: Text('Lokal')),
                        DropdownMenuItem(
                          value: 'LN',
                          child: Text('Import (LN)'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => r.originType = v ?? 'LOKAL'),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                _photoPicker(idx, r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input helpers ─────────────────────────────────────────

  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboard,
  }) => _inputDecor(
    TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 12),
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

  Widget _fieldMultiline(String hint, IconData icon) => _inputDecor(
    TextField(
      controller: _notesCtrl,
      maxLines: 3,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textDisabled, fontSize: 12),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textMuted),
        border: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(4, 12, 14, 12),
      ),
    ),
  );

  Future<void> _pickPhotoSource(int idx, _ItemRow r) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.camera_alt_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text(
                'Kamera',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text(
                'Galeri',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: source, imageQuality: 70);
        if (file != null) {
          setState(() {
            r.localPhotoPath = file.path;
          });
        }
      } catch (e) {
        if (mounted) {
          _snack(
            friendlyMessage(e, fallback: 'Gagal mengambil foto'),
            isError: true,
          );
        }
      }
    }
  }

  Widget _photoPicker(int idx, _ItemRow r) => Row(
    children: [
      Expanded(
        child: InkWell(
          onTap: r.isUploading ? null : () => _pickPhotoSource(idx, r),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (r.isUploading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                else
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                SizedBox(width: 8),
                Text(
                  r.isUploading
                      ? 'Mengupload...'
                      : ((r.localPhotoPath != null ||
                                r.uploadedPhotoUrl != null)
                            ? 'Ganti Foto'
                            : 'Ambil Foto'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (r.localPhotoPath != null || r.uploadedPhotoUrl != null) ...[
        SizedBox(width: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: r.localPhotoPath != null
              ? Image.file(
                  File(r.localPhotoPath!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  r.uploadedPhotoUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
        ),
      ],
    ],
  );
}
