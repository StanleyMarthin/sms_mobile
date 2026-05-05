import 'dart:io';

import 'package:flutter/foundation.dart';
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
      if (!file.existsSync()) {
        throw Exception('File foto tidak ditemukan di device: $localPath');
      }

      // 1. Build path: unit/divisi/bulan/tanggal/{jobdesc} {panel}_{type}.jpg
      final now = DateTime.now();
      final monthNames = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      final monthFolder = monthNames[now.month];
      final dateFolder =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final safeUnit = _sanitize(unit, fallback: 'UNIT');
      final safeDiv = _sanitize(division, fallback: 'DIVISI');
      final safeJob = _sanitize(job, fallback: 'JOB');
      final safePanel = _sanitize(panel);
      final safeType = _sanitize(type, fallback: 'FOTO');

      final fileStem = safePanel.isEmpty
          ? '${safeJob}_$safeType'
          : '$safeJob ${safePanel}_$safeType';
      final targetPath =
          '$safeUnit/$safeDiv/$monthFolder/$dateFolder/$fileStem.jpg';

      // 2. Request Upload Ticket from backend
      final res = await apiClient.get(
        ApiEndpoints.tasksUploadTicket,
        queryParameters: {'filename': targetPath},
      );

      final raw = res.data as Map<String, dynamic>? ?? {};
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final uploadUrl = data['upload_url']?.toString();
      final publicUrl = data['public_url']?.toString();

      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw Exception('Gagal mendapatkan upload_url dari server: $raw');
      }
      if (publicUrl == null || publicUrl.isEmpty) {
        throw Exception('Gagal mendapatkan public_url dari server: $raw');
      }

      final uploadResult = await _uploadToR2(
        file: file,
        uploadUrl: uploadUrl,
        targetPath: targetPath,
      );

      if (uploadResult) {
        return publicUrl;
      }

      throw Exception('R2 upload gagal untuk $targetPath');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TaskUpload] Upload failed: $e');
      }
      throw Exception('Gagal upload foto: $e');
    }
  }

  Future<bool> _uploadToR2({
    required File file,
    required String uploadUrl,
    required String targetPath,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final response = await http
          .put(
            Uri.parse(uploadUrl),
            headers: {
              'Content-Type': 'image/jpeg',
              'Content-Length': bytes.length.toString(),
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }

      if (kDebugMode) {
        debugPrint(
          '[TaskUpload] Simple PUT failed '
          'status=${response.statusCode} target=$targetPath body=${response.body}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TaskUpload] Simple PUT exception for $targetPath: $e');
      }
    }

    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
    request.headers['Content-Type'] = 'image/jpeg';
    request.headers['Content-Length'] = file.lengthSync().toString();

    file.openRead().listen(
          (data) => request.sink.add(data),
          onDone: () => request.sink.close(),
          onError: (e) => request.sink.addError(e),
          cancelOnError: true,
        );

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 60));

    if (streamedResponse.statusCode == 200 ||
        streamedResponse.statusCode == 204) {
      if (kDebugMode) {
        debugPrint('[TaskUpload] Streamed PUT success for $targetPath');
      }
      return true;
    }

    final body = await streamedResponse.stream.bytesToString();
    throw Exception(
      'Upload HTTP ${streamedResponse.statusCode} untuk $targetPath: $body',
    );
  }

  /// Sanitize a string for use in a file path — keep letters, digits, dash, underscore, space
  static String _sanitize(String? value, {String fallback = ''}) {
    final sanitized = (value ?? '')
        .trim()
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_')
        .trim();
    return sanitized.isEmpty ? fallback : sanitized;
  }
}
