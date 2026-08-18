/*
Tujuan: Mengubah error teknis (Failure/DioException/Exception) menjadi pesan
        yang aman dan manusiawi untuk ditampilkan di UI.
Caller: Repository catch-block, halaman (AppNotification/SnackBar/AlertDialog),
        dan Bloc yang menampilkan pesan error.
Dependensi: failures.dart (Failure), api_client.dart (ApiClient.mapDioError),
            package:dio.
Main Functions: friendlyMessage(Object?, {String fallback}).
Side Effects: Tidak ada.
*/
library;

import 'package:dio/dio.dart';

import '../network/api_client.dart';
import '../utils/app_messages.dart';
import 'failures.dart';

/// Pesan error yang aman ditampilkan ke user.
///
/// - [Failure] -> pesan milik failure (default-nya sudah berbahasa Indonesia).
/// - [DioException] -> dipetakan via [ApiClient.mapDioError].
/// - Error lain -> [fallback]; detail teknis tidak dibocorkan ke user.
String friendlyMessage(
  Object? error, {
  String fallback = AppMessages.http500,
}) {
  if (error is Failure) {
    return _nonEmpty(error.message) ?? fallback;
  }
  if (error is DioException) {
    final failure = ApiClient.mapDioError(error);
    return _nonEmpty(failure.message) ?? fallback;
  }
  return fallback;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
