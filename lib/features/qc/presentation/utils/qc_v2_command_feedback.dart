/*
Tujuan: Helper pesan aman dan sinyal refresh untuk konflik command QC V2.
Caller: QC V2 pages dan unit test.
Dependensi: DioException, Failure, ApiClient, friendlyMessage.
Main Functions: QcV2CommandFeedback.
Side Effects: Tidak ada.
*/

library;

import 'package:dio/dio.dart';

import '../../../../core/errors/error_message.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';

abstract class QcV2CommandFeedback {
  static bool shouldRefresh(Object error) {
    final code = _code(error);
    return {
      'ERR_STALE_QC',
      'ERR_IDEMPOTENCY_CONFLICT',
      'ERR_V2_CORE_OWNED',
    }.contains(code);
  }

  static String message(Object error) {
    return switch (_code(error)) {
      'ERR_STALE_QC' => 'Data QC sudah berubah. Memuat ulang data terbaru.',
      'ERR_IDEMPOTENCY_CONFLICT' =>
        'Command ID sudah dipakai untuk data berbeda.',
      'ERR_V2_CORE_OWNED' =>
        'Core ini dikelola Job Plan V2. Muat ulang antrean QC.',
      _ => friendlyMessage(error, fallback: 'Gagal memproses QC V2'),
    };
  }

  static String? _code(Object error) {
    if (error is Failure) return error.errorCode;
    if (error is DioException) return ApiClient.mapDioError(error).errorCode;
    return null;
  }
}
