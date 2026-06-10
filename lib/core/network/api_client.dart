/// Dio-based HTTP client with interceptors for auth, response parsing,
/// and error mapping.
///
/// All feature datasources should use [ApiClient] instead of raw Dio.
/// Standard response format: `{ "success": true, "message": "...", "data": {} }`
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/failures.dart';
import '../session/session_manager.dart';
import 'api_endpoints.dart';

/// Parsed API response wrapper.
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({required this.success, required this.message, this.data});
}

class _CacheEntry {
  final Response response;
  final DateTime expiry;
  _CacheEntry(this.response, this.expiry);
}

/// Central HTTP client wrapping Dio with auth & error interceptors.
class ApiClient {
  final Dio _dio;
  final SessionManager _sessionManager;
  Future<bool>? _refreshFuture;
  final Map<String, _CacheEntry> _cache = {};

  ApiClient({required SessionManager sessionManager, Dio? dio})
    : _sessionManager = sessionManager,
      _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers = {'Content-Type': 'application/json'};

    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(_cacheInterceptor());
    _dio.interceptors.add(_retryInterceptor());
    _dio.interceptors.add(_responseInterceptor());
  }

  /// Exposes Dio for direct access when needed (e.g. multipart uploads).
  Dio get dio => _dio;

  // ─── Interceptors ─────────────────────────────────────────

  /// Injects `Authorization: Bearer <token>` on every request.
  /// Uses tempToken for device-init/login and the Redis session token
  /// for all authenticated feature calls.
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.extra['skipAuth'] == true) {
          handler.next(options);
          return;
        }
        final token = _sessionManager.token ?? _sessionManager.tempToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    );
  }

  /// Caches responses for GET requests if `useCache` is true in `extra`.
  Interceptor _cacheInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'GET' && options.extra['useCache'] == true) {
          final cacheKey = '${options.uri}';
          final entry = _cache[cacheKey];
          if (entry != null && DateTime.now().isBefore(entry.expiry)) {
            handler.resolve(entry.response);
            return;
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (response.requestOptions.method == 'GET' && response.requestOptions.extra['useCache'] == true) {
          final cacheKey = '${response.requestOptions.uri}';
          final duration = response.requestOptions.extra['cacheDuration'] as Duration? ?? const Duration(minutes: 5);
          _cache[cacheKey] = _CacheEntry(response, DateTime.now().add(duration));
        }
        handler.next(response);
      },
    );
  }

  /// Parses standard API response format.
  /// On `success: false`, rejects with a [DioException] carrying the
  /// mapped [Failure] in `error`.
  Interceptor _responseInterceptor() {
    return InterceptorsWrapper(
      onResponse: (response, handler) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final success = data['success'] as bool? ?? true;
          if (!success) {
            final errorCode =
                (data['errorCode'] as String?) ??
                (data['error'] as String?) ??
                '';
            final message = data['message'] as String? ?? 'Terjadi kesalahan';
            final failure = ApiErrorCode.fromCode(errorCode, message);
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
                error: failure,
              ),
            );
            return;
          }
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode ?? 0;
        final isAuthError =
            statusCode == 401 || statusCode == 403 || statusCode == 404;

        // If already mapped (from response interceptor) and not an auth HTTP error, pass through
        if (error.error is Failure && !isAuthError) {
          handler.next(error);
          return;
        }

        if (_shouldAttemptRefresh(error)) {
          await _retryAfterRefresh(error, handler);
          return;
        }

        if (isAuthError) {
          await _sessionManager.logout();
        }

        handler.next(error);
      },
    );
  }

  Interceptor _retryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        if (!_shouldRetry(error)) {
          handler.next(error);
          return;
        }

        final request = error.requestOptions;
        final retryCount = (request.extra['retryCount'] as int? ?? 0) + 1;
        request.extra['retryCount'] = retryCount;

        final delay = Duration(milliseconds: 300 * (1 << (retryCount - 1)));
        await Future<void>.delayed(delay);

        try {
          final response = await _dio.fetch(request);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    );
  }

  bool _shouldRetry(DioException error) {
    final request = error.requestOptions;
    final retryCount = request.extra['retryCount'] as int? ?? 0;
    if (retryCount >= 3) return false;
    if (request.cancelToken?.isCancelled == true) return false;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        return error.response?.statusCode == 503;
      default:
        return false;
    }
  }

  bool _shouldAttemptRefresh(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    final request = error.requestOptions;
    return statusCode == 401 &&
        request.extra['skipRefresh'] != true &&
        request.path != ApiEndpoints.refresh &&
        (_sessionManager.refreshToken ?? '').isNotEmpty &&
        (_sessionManager.deviceId ?? '').isNotEmpty;
  }

  Future<void> _retryAfterRefresh(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final refreshed = await _refreshSession();
      if (!refreshed || _sessionManager.token == null) {
        handler.next(error);
        return;
      }

      final request = error.requestOptions;
      request.headers['Authorization'] = 'Bearer ${_sessionManager.token}';
      request.extra['skipRefresh'] = true;

      final response = await _dio.fetch(request);
      handler.resolve(response);
    } catch (_) {
      handler.next(error);
    }
  }

  Future<bool> _refreshSession() async {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final completer = Completer<bool>();
    _refreshFuture = completer.future;

    try {
      final refreshToken = _sessionManager.refreshToken;
      final deviceId = _sessionManager.deviceId;
      if (refreshToken == null ||
          refreshToken.isEmpty ||
          deviceId == null ||
          deviceId.isEmpty) {
        completer.complete(false);
        return false;
      }

      final refreshDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken, 'deviceId': deviceId},
      );

      final raw = response.data as Map<String, dynamic>? ?? {};
      final data = raw['data'] as Map<String, dynamic>? ?? {};
      final user = data['user'] as Map<String, dynamic>? ?? {};

      final newToken = '${data['token'] ?? ''}';
      final newRefreshToken = '${data['refreshToken'] ?? ''}';
      final employeeId = '${user['employeeId'] ?? ''}';
      final userId = '${user['userId'] ?? ''}';
      if (newToken.isEmpty ||
          newRefreshToken.isEmpty ||
          employeeId.isEmpty ||
          userId.isEmpty) {
        completer.complete(false);
        return false;
      }

      final permissions = (user['permissions'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList();

      await _sessionManager.login(
        token: newToken,
        refreshToken: newRefreshToken,
        userId: userId,
        employeeId: employeeId,
        fullName: '${user['fullname'] ?? ''}',
        role: '${user['roleName'] ?? ''}',
        divisionName: '${user['division'] ?? ''}',
        jabatan: '${user['grade'] ?? ''}',
        divisionId: (user['divisionId'] as num?)?.toInt() ?? 0,
        permissions: permissions,
        accessBucket: user['accessBucket'] as String?,
        roleLevel:
            ((user['roleProfile'] as Map<String, dynamic>?)?['roleLevel']
                    as num?)
                ?.toInt(),
        scopeBasis:
            ((user['roleProfile'] as Map<String, dynamic>?)?['scopeBasis']
                as String?),
        webEnabled:
            ((user['roleProfile'] as Map<String, dynamic>?)?['webEnabled']
                as bool?),
        mobileEnabled:
            ((user['roleProfile'] as Map<String, dynamic>?)?['mobileEnabled']
                as bool?),
        approvalRank:
            ((user['roleProfile'] as Map<String, dynamic>?)?['approvalRank']
                    as num?)
                ?.toInt(),
        canViewAllUnits:
            ((user['scope'] as Map<String, dynamic>?)?['canViewAllUnits']
                as bool?),
        canViewAssignedUnits:
            ((user['scope'] as Map<String, dynamic>?)?['canViewAssignedUnits']
                as bool?),
        managedDivisionIds:
            (((user['scope'] as Map<String, dynamic>?)?['managedDivisionIds']
                        as List<dynamic>? ??
                    user['managedDivisions'] as List<dynamic>?)
                ?.map((e) => int.tryParse('$e'))
                .whereType<int>()
                .toList()) ??
            const [],
        managedUnitIds:
            (((user['scope'] as Map<String, dynamic>?)?['unitIds']
                        as List<dynamic>? ??
                    user['managedUnits'] as List<dynamic>?)
                ?.map((e) => '$e')
                .where((e) => e.trim().isNotEmpty)
                .toList()) ??
            const [],
      );

      completer.complete(true);
      return true;
    } on DioException catch (exc) {
      final statusCode = exc.response?.statusCode ?? 0;
      if (statusCode == 401 || statusCode == 403) {
        await _sessionManager.logout();
      }
      if (kDebugMode) {
        debugPrint('Refresh session failed: $exc');
      }
      completer.complete(false);
      return false;
    } catch (exc) {
      if (kDebugMode) {
        debugPrint('Refresh session failed: $exc');
      }
      completer.complete(false);
      return false;
    } finally {
      _refreshFuture = null;
    }
  }

  // ─── Convenience methods ──────────────────────────────────

  /// GET request. Returns parsed `data` field from standard response.
  Future<ApiResponse<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final response = await _dio.get(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
    return _parseResponse(response);
  }

  /// POST request.
  Future<ApiResponse<dynamic>> post(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      path,
      data: data,
      cancelToken: cancelToken,
    );
    return _parseResponse(response);
  }

  /// PUT request.
  Future<ApiResponse<dynamic>> put(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.put(path, data: data, cancelToken: cancelToken);
    return _parseResponse(response);
  }

  /// DELETE request.
  Future<ApiResponse<dynamic>> delete(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.delete(
      path,
      data: data,
      cancelToken: cancelToken,
    );
    return _parseResponse(response);
  }

  /// PATCH request.
  Future<ApiResponse<dynamic>> patch(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.patch(
      path,
      data: data,
      cancelToken: cancelToken,
    );
    return _parseResponse(response);
  }

  /// POST multipart form data (for file uploads).
  Future<ApiResponse<dynamic>> postMultipart(
    String path, {
    required FormData formData,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      cancelToken: cancelToken,
    );
    return _parseResponse(response);
  }

  // ─── Internal helpers ─────────────────────────────────────

  ApiResponse<dynamic> _parseResponse(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return ApiResponse(
        success: data['success'] as bool? ?? true,
        message: data['message'] as String? ?? '',
        data: data['data'],
      );
    }
    return ApiResponse(success: true, message: '', data: data);
  }

  /// Maps [DioException] to domain [Failure].
  /// Call this in repository catch blocks.
  static Failure mapDioError(DioException e) {
    // Already mapped by response interceptor
    if (e.error is Failure) return e.error as Failure;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final body = e.response?.data;
        String? message;
        String? errorCode;
        if (body is Map<String, dynamic>) {
          message = body['message'] as String?;
          errorCode =
              (body['errorCode'] as String?) ?? (body['error'] as String?);
        }
        if (errorCode != null) {
          return ApiErrorCode.fromCode(errorCode, message);
        }
        if (statusCode >= 500) {
          return ServerFailure(
            message: message ?? 'Server error',
            statusCode: statusCode,
          );
        }
        if (statusCode == 401) {
          return UnauthorizedFailure(message: message);
        }
        if (statusCode == 403) {
          return ForbiddenFailure(message: message);
        }
        return ClientFailure(
          message: message ?? 'Request gagal',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return const ClientFailure(message: 'Request dibatalkan');
      default:
        return const NetworkFailure();
    }
  }
}
