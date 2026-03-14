/// Dio-based HTTP client with interceptors for auth, response parsing,
/// and error mapping.
///
/// All feature datasources should use [ApiClient] instead of raw Dio.
/// Standard response format: `{ "success": true, "message": "...", "data": {} }`
library;

import 'package:dio/dio.dart';

import '../errors/failures.dart';
import '../session/session_manager.dart';
import 'api_endpoints.dart';

/// Parsed API response wrapper.
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });
}

/// Central HTTP client wrapping Dio with auth & error interceptors.
class ApiClient {
  final Dio _dio;
  final SessionManager _sessionManager;

  ApiClient({
    required SessionManager sessionManager,
    Dio? dio,
  })  : _sessionManager = sessionManager,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = ApiEndpoints.baseUrl
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers = {'Content-Type': 'application/json'};

    _dio.interceptors.add(_authInterceptor());
    _dio.interceptors.add(_responseInterceptor());
  }

  /// Exposes Dio for direct access when needed (e.g. multipart uploads).
  Dio get dio => _dio;

  // ─── Interceptors ─────────────────────────────────────────

  /// Injects `Authorization: Bearer <token>` on every request.
  /// Uses tempToken for device-init/login, JWT for all other calls.
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _sessionManager.token ?? _sessionManager.tempToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
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
            final errorCode = data['error'] as String? ?? '';
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
      onError: (error, handler) {
        // If already mapped (from response interceptor), pass through
        if (error.error is Failure) {
          handler.next(error);
          return;
        }
        handler.next(error);
      },
    );
  }

  // ─── Convenience methods ──────────────────────────────────

  /// GET request. Returns parsed `data` field from standard response.
  Future<ApiResponse<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return _parseResponse(response);
  }

  /// POST request.
  Future<ApiResponse<dynamic>> post(
    String path, {
    dynamic data,
  }) async {
    final response = await _dio.post(path, data: data);
    return _parseResponse(response);
  }

  /// PUT request.
  Future<ApiResponse<dynamic>> put(
    String path, {
    dynamic data,
  }) async {
    final response = await _dio.put(path, data: data);
    return _parseResponse(response);
  }

  /// PATCH request.
  Future<ApiResponse<dynamic>> patch(
    String path, {
    dynamic data,
  }) async {
    final response = await _dio.patch(path, data: data);
    return _parseResponse(response);
  }

  /// POST multipart form data (for file uploads).
  Future<ApiResponse<dynamic>> postMultipart(
    String path, {
    required FormData formData,
  }) async {
    final response = await _dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
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
          errorCode = body['error'] as String?;
        }
        if (errorCode != null) {
          return ApiErrorCode.fromCode(errorCode, message);
        }
        if (statusCode >= 500) {
          return ServerFailure(message: message ?? 'Server error', statusCode: statusCode);
        }
        if (statusCode == 401) {
          return UnauthorizedFailure(message: message);
        }
        if (statusCode == 403) {
          return ForbiddenFailure(message: message);
        }
        return ClientFailure(message: message ?? 'Request gagal', statusCode: statusCode);
      case DioExceptionType.cancel:
        return const ClientFailure(message: 'Request dibatalkan');
      default:
        return const NetworkFailure();
    }
  }
}
