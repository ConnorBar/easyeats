import 'package:dio/dio.dart';

// TODO: On Android emulator use 10.0.2.2 instead of localhost.
//       On a physical device, use the machine's LAN IP.
const String baseUrl = 'http://localhost:8000';

final dio = Dio(
  BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
)..interceptors.add(
    InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) {
        // Parse FastAPI/Pydantic 422 validation errors into a readable string
        // instead of exposing the raw DioException to the UI.
        if (error.response?.statusCode == 422) {
          final detail = error.response?.data?['detail'];
          if (detail is List && detail.isNotEmpty) {
            final messages = detail.map((e) {
              final loc = (e['loc'] as List?)?.skip(1).join(' → ') ?? '';
              final msg = (e['msg'] as String?) ?? 'invalid value';
              return loc.isNotEmpty ? '$loc: $msg' : msg;
            }).join('\n');
            // Use DioExceptionType.unknown so Dio doesn't overwrite our
            // message with its own auto-generated "status code 422..." text.
            handler.reject(DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: DioExceptionType.unknown,
              error: messages,
            ));
            return;
          }
        }
        handler.next(error);
      },
    ),
  );

/// Converts any exception from a Dio call into a short user-facing string.
/// Handles Pydantic 422s (already formatted by the interceptor above),
/// network timeouts, and generic server errors.
String friendlyApiError(Object e) {
  if (e is DioException) {
    // Interceptor stores formatted 422 text in e.error as a String
    if (e.error is String && (e.error as String).isNotEmpty) {
      return e.error as String;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out — check your connection';
      case DioExceptionType.connectionError:
        return 'Could not reach the server — check your connection';
      default:
        final status = e.response?.statusCode;
        if (status != null) return 'Server error ($status)';
        return 'Network error';
    }
  }
  return e.toString();
}
