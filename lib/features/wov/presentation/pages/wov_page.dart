import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/remote_wov_datasource.dart';

class WovPage extends StatefulWidget {
  const WovPage({super.key});

  @override
  State<WovPage> createState() => _WovPageState();
}

class _WovPageState extends State<WovPage> {
  late final RemoteWovDataSource _wovDataSource;
  List<Map<String, dynamic>> _wovs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _wovDataSource = RemoteWovDataSource(
      apiClient: sl(),
      sessionManager: sl(),
    );
    _fetchWovs();
  }

  Future<void> _fetchWovs() async {
    setState(() => _isLoading = true);
    try {
      final items = await _wovDataSource.getWovs();
      setState(() => _wovs = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat WOV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String reqId, String status) async {
    try {
      await _wovDataSource.updateStatus(reqId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status WOV diperbarui')),
        );
      }
      _fetchWovs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal perbarui WOV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Order Vendor'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : _wovs.isEmpty
              ? const Center(child: Text('Tidak ada WOV ditemukan'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _wovs.length,
                  itemBuilder: (context, index) {
                    final item = _wovs[index];
                    final reqId = '${item['reqId'] ?? ''}';
                    final status = '${item['status'] ?? 'UNKNOWN'}';
                    return Card(
                      color: AppColors.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        title: Text(
                          reqId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'Catatan: ${item['notes'] ?? '-'}\nStatus: $status',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: AppColors.textPrimary),
                          onSelected: (newStatus) =>
                              _updateStatus(reqId, newStatus),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'SENT', child: Text('Tandai SENT')),
                            const PopupMenuItem(
                                value: 'PROSES_VENDOR',
                                child: Text('Tandai PROSES VENDOR')),
                            const PopupMenuItem(
                                value: 'DONE_VENDOR',
                                child: Text('Tandai DONE VENDOR')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
