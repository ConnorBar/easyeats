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
);
