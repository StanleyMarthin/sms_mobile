import 'dart:io';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class UploadService {
  final ApiClient apiClient;

  UploadService({
    required this.apiClient,
  });

  /// Requests a presigned URL then uploads the binary file using standard HTTP PUT.
  /// Returns the public cloud URL.
  ///
  /// Path convention: unit/divisi/bulanNama/tanggal/{jobdesc} {panel}_{type}.jpg
  /// Example: KM-108/Mekanik/April/2026-04-30/Overhaul_Mesin Panel_A_bef.jpg
  Future<String?> uploadPhoto({
    required String localPath,
    required String unit,
    required String division,
    String? job,
    String? panel,
    String type = 'foto',
  }) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      // 1. Build path: unit/divisi/bulan/tanggal/{jobdesc} {panel}_{type}.jpg
      final now = DateTime.now();
      final monthNames = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];
      final monthFolder = monthNames[now.month];
      final dateFolder =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final safeUnit = _sanitize(unit);
      final safeDiv = _sanitize(division);
      final safeJob = _sanitize(job ?? 'job');
      final safePanel = _sanitize(panel ?? 'panel');
      final safeType = _sanitize(type);

      // unit/divisi/Bulan/tanggal/{job} {panel}_{type}.jpg
      final targetPath =
          '$safeUnit/$safeDiv/$monthFolder/$dateFolder/${safeJob} ${safePanel}_$safeType.jpg';

      // 2. Request Upload Ticket from backend
      final res = await apiClient.get(
        ApiEndpoints.tasksUploadTicket,
        queryParameters: {'filename': targetPath},
      );

      final data = res.data as Map<String, dynamic>? ?? {};
      final uploadUrl = data['upload_url'] as String?;
      final publicUrl = data['public_url'] as String?;

      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw Exception('Gagal mendapatkan upload_url dari server');
      }

      // 3. Upload via simple PUT (readAsBytes) — more reliable than streaming
      //    for photos under ~5MB. Avoids race-condition / lost-connection issues.
      final bytes = await file.readAsBytes();
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': bytes.length.toString(),
        },
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return publicUrl ?? targetPath;
      }

      throw Exception(
          'R2 Upload returns status: ${response.statusCode} - ${response.body}');
    } catch (e) {
      throw Exception('Gagal upload foto: $e');
    }
  }

  /// Sanitize a string for use in a file path — keep letters, digits, dash, underscore, space
  static String _sanitize(String value) {
    return value
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_')
        .trim();
  }
}
