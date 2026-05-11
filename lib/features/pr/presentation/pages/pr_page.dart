/// Tujuan: Halaman daftar dan pembuatan Purchase Request (PR).
/// Caller: AppRouter (/pr).
/// Dependensi: RemotePrDataSource, ApiClient, SessionManager.
/// Main Functions: _fetchPrs(), _approvePr(), _showCreatePrSheet().
/// Side Effects: HTTP GET/POST ke backend PR service.

import 'package:flutter/material.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/datasources/remote_pr_datasource.dart';

class PrPage extends StatefulWidget {
  const PrPage({super.key});

  @override
  State<PrPage> createState() => _PrPageState();
}

class _PrPageState extends State<PrPage> {
  late final RemotePrDataSource _prDataSource;
  List<Map<String, dynamic>> _prs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prDataSource = RemotePrDataSource(
      apiClient: sl(),
      sessionManager: sl(),
    );
    _fetchPrs();
  }

  Future<void> _fetchPrs() async {
    setState(() => _isLoading = true);
    try {
      final prs = await _prDataSource.getPrs();
      setState(() => _prs = prs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat Purchase Requests: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approvePr(String reqId) async {
    try {
      await _prDataSource.approvePr(reqId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PR berhasil di-approve')),
        );
      }
      _fetchPrs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal approve PR: $e')),
        );
      }
    }
  }

  /// Whether the current user can approve this PR based on status + role.
  bool _canApprove(String status) {
    final role = (sl<SessionManager>().role ?? '').toUpperCase();
    if (status == 'PENDING_KP' && (role == 'KP' || role == 'KEPALA_PROJECT')) return true;
    if (status == 'PENDING_MP' && (role == 'MP' || role == 'MANAGER_PRODUKSI' || role == 'PM')) return true;
    if (status == 'PENDING_PUR' && (role == 'PUR' || role == 'ADMIN')) return true;
    return false;
  }

  Future<void> _showCreatePrSheet(BuildContext context) async {
    String? selectedCarId;
    String? selectedCarName;
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final uomCtrl = TextEditingController(text: 'Pcs');
    final typeCtrl = TextEditingController(text: 'SPAREPART');
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final divisionCtrl = TextEditingController();
    
    // Optional query to filter dummy cars
    List<Map<String,dynamic>> matchingCars = [];
    var carQuery = '';
    
    // Fetch real cars
    sl<ApiClient>().get(ApiEndpoints.jobPlanDropdowns).then((res) {
      final data = res.data['data'] ?? res.data;
      if (data != null && data['cars'] is List) {
        if (mounted) {
           matchingCars = (data['cars'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }).catchError((_) {}).whenComplete(() {
      if (mounted) {
        // Force rebuild of sheet state if possible, though StatefulBuilder will do it.
      }
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filteredCars = matchingCars.where((c) {
             final n = '${c['unit_name']}'.toLowerCase();
             final p = '${c['police_number']}'.toLowerCase();
             return n.contains(carQuery) || p.contains(carQuery);
          }).take(5).toList();

          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  children: [
                    const Text('Buat Purchase Request Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: [
                          TextField(
                            decoration: const InputDecoration(labelText: 'Tipe Request (SPAREPART / MATERIAL / JASA)'),
                            controller: typeCtrl,
                          ),
                          const SizedBox(height: 12),
                          const Text('Pilih Unit (Ketik untuk filter):', style: TextStyle(color: AppColors.textPrimary)),
                          TextField(
                            onChanged: (v) => setSheetState(() => carQuery = v.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'Cari Unit...',
                              suffixIcon: matchingCars.isEmpty ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                            ),
                          ),
                          if (filteredCars.isNotEmpty)
                             ...filteredCars.map((c) => ListTile(
                                title: Text('${c['unit_name']}', style: const TextStyle(color: AppColors.textPrimary)),
                                subtitle: Text('${c['police_number']}', style: const TextStyle(color: AppColors.textMuted)),
                                tileColor: selectedCarId == c['id'] ? AppColors.gold.withValues(alpha: 0.2) : null,
                                onTap: () {
                                  setSheetState(() {
                                    selectedCarId = c['id'] as String;
                                    selectedCarName = c['unit_name'] as String;
                                  });
                                }
                             )),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(labelText: 'Divisi (Opsional)'),
                            controller: divisionCtrl,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(labelText: 'Nama Item'),
                            controller: itemCtrl,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Qty'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  controller: qtyCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'UoM (Pcs, Set, Liter...)'),
                                  controller: uomCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(labelText: 'Harga Estimasi (Opsional)'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: priceCtrl,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(labelText: 'Catatan'),
                            controller: notesCtrl,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () async {
                          if (selectedCarId == null || itemCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit, Nama Item, dan Qty wajib diisi!')));
                            return;
                          }
                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          try {
                            await _prDataSource.createPr(
                              carId: selectedCarId!,
                              carName: selectedCarName,
                              itemName: itemCtrl.text.trim(),
                              qty: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                              uom: uomCtrl.text.trim(),
                              requestType: typeCtrl.text.trim(),
                              estimatedPrice: double.tryParse(priceCtrl.text.trim()),
                              divisionName: divisionCtrl.text.trim().isNotEmpty ? divisionCtrl.text.trim() : null,
                              notes: notesCtrl.text.trim(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Request berhasil dibuat!')));
                            _fetchPrs();
                          } catch (e) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat PR: $e')));
                          }
                        },
                        child: const Text('Buat PR', style: TextStyle(color: AppColors.background)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Requests'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressBinding())
          : _prs.isEmpty
              ? const Center(child: Text('Tidak ada PR ditemukan'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _prs.length,
                  itemBuilder: (context, index) {
                    final pr = _prs[index];
                    final reqId = '${pr['reqId'] ?? ''}';
                    final status = '${pr['status'] ?? 'UNKNOWN'}';
                    final orderNumber = '${pr['reqNumber'] ?? pr['orderNumber'] ?? reqId}';
                    return Card(
                      color: AppColors.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        title: Text(
                          orderNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          '${pr['item_name'] ?? pr['itemName'] ?? '-'} • ${pr['qty'] ?? ''} ${pr['uom'] ?? ''}\nStatus: $status',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: _canApprove(status)
                            ? ElevatedButton(
                                onPressed: () => _approvePr(reqId),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold),
                                child: const Text('Approve',
                                    style:
                                        TextStyle(color: AppColors.background)),
                              )
                            : Chip(
                                backgroundColor: AppColors.background,
                                side: const BorderSide(color: AppColors.border),
                                label: Text(status,
                                    style: const TextStyle(
                                        fontSize: 10, color: AppColors.gold)),
                              ),
                      ),
                    );
                  },
                ),
      floatingActionButton: hasPermission(sl<SessionManager>().role, Permission.prCreate)
          ? FloatingActionButton(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              onPressed: () => _showCreatePrSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class CircularProgressBinding extends StatelessWidget {
  const CircularProgressBinding({super.key});
  @override
  Widget build(BuildContext context) =>
      const CircularProgressIndicator(color: AppColors.gold);
}
