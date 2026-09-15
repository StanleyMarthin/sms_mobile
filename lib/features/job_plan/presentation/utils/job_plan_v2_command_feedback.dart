/*
Tujuan: Helper pesan aman dan sinyal refresh untuk konflik command Job Plan V2.
Caller: Page mutation Job Plan V2 dan unit test.
Dependensi: DioException, Failure, ApiClient, friendlyMessage.
Main Functions: JobPlanV2CommandFeedback.
Side Effects: Tidak ada.
*/
library;

import 'package:dio/dio.dart';
import 'package:sm_system/core/errors/error_message.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/core/network/api_client.dart';

abstract class JobPlanV2CommandFeedback {
  static bool shouldRefresh(Object error) {
    final code = _code(error);
    return code == 'ERR_STALE_PLAN' || code == 'ERR_IDEMPOTENCY_CONFLICT';
  }

  static String message(Object error) {
    return switch (_code(error)) {
      'ERR_STALE_PLAN' => 'Data Job Plan berubah. Memuat ulang data terbaru.',
      'ERR_IDEMPOTENCY_CONFLICT' =>
        'Command ID sudah dipakai untuk data berbeda.',
      _ => friendlyMessage(error, fallback: 'Gagal memproses Job Plan'),
    };
  }

  static String? _code(Object error) {
    if (error is Failure) return error.errorCode;
    if (error is DioException) {
      final mapped = ApiClient.mapDioError(error);
      return mapped.errorCode;
    }
    return null;
  }
}
