import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/errors/failure.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiService {
  ApiService({
    required this.client,
    required this.firebaseAuth,
    required this.baseUrl,
  });

  final http.Client client;
  final FirebaseAuth firebaseAuth;
  final String baseUrl;

  Future<Either<Failure, R>> get<R>(
    String path, {
    Map<String, String>? queryParameters,
    R Function(dynamic data)? decoder,
  }) {
    return _request<R>(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      decoder: decoder,
    );
  }

  Future<Either<Failure, R>> post<R>(
    String path, {
    Object? body,
    R Function(dynamic data)? decoder,
  }) {
    return _request<R>(
      method: 'POST',
      path: path,
      body: body,
      decoder: decoder,
    );
  }

  Future<Either<Failure, R>> put<R>(
    String path, {
    Object? body,
    R Function(dynamic data)? decoder,
  }) {
    return _request<R>(
      method: 'PUT',
      path: path,
      body: body,
      decoder: decoder,
    );
  }

  Future<Either<Failure, R>> patch<R>(
    String path, {
    Object? body,
    R Function(dynamic data)? decoder,
  }) {
    return _request<R>(
      method: 'PATCH',
      path: path,
      body: body,
      decoder: decoder,
    );
  }

  Future<Either<Failure, R>> delete<R>(
    String path, {
    Object? body,
    R Function(dynamic data)? decoder,
  }) {
    return _request<R>(
      method: 'DELETE',
      path: path,
      body: body,
      decoder: decoder,
    );
  }

  Future<Either<Failure, R>> _request<R>({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Object? body,
    R Function(dynamic data)? decoder,
  }) async {
    final uri = Uri.parse(baseUrl).resolve(path).replace(
          queryParameters: queryParameters,
        );
    try {
      final headers = await _buildHeaders();
      final requestBody = body == null ? null : jsonEncode(body);
      http.Response response;
      switch (method) {
        case 'GET':
          response = await client.get(uri, headers: headers);
          break;
        case 'POST':
          response = await client.post(uri, headers: headers, body: requestBody);
          break;
        case 'PUT':
          response = await client.put(uri, headers: headers, body: requestBody);
          break;
        case 'PATCH':
          response = await client.patch(uri, headers: headers, body: requestBody);
          break;
        case 'DELETE':
          response = await client.delete(uri, headers: headers, body: requestBody);
          break;
        default:
          return left(
            Failure(message: 'Метод $method не поддерживается'),
          );
      }

      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          return _request<R>(
            method: method,
            path: path,
            queryParameters: queryParameters,
            body: body,
            decoder: decoder,
          );
        }
        return left(
          UnauthorizedFailure(
            message: 'Сессия истекла. Войдите заново.',
            statusCode: response.statusCode,
          ),
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return right(_decodeSuccess<R>(null, decoder));
        }
        final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
        return right(_decodeSuccess<R>(data, decoder));
      }

      if (response.statusCode >= 500) {
        return left(
          ServerFailure(
            message: _parseErrorMessage(response.body) ??
                'Ошибка сервера. Повторите попытку позже.',
            statusCode: response.statusCode,
          ),
        );
      }

      if (response.statusCode == 400) {
        return left(
          Failure(
            message: _parseErrorMessage(response.body) ?? 'Неверный запрос.',
            statusCode: response.statusCode,
          ),
        );
      }

      return left(
        Failure(
          message: _parseErrorMessage(response.body) ??
              'Неизвестная ошибка (${response.statusCode})',
          statusCode: response.statusCode,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('API $method $path error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return left(
        NetworkFailure(message: 'Проблема с сетью. Проверьте подключение.'),
      );
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final user = firebaseAuth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      } catch (error) {
        debugPrint('Token fetch error: $error');
      }
    }
    return headers;
  }

  bool _refreshing = false;

  Future<bool> _refreshToken() async {
    if (_refreshing) {
      return false;
    }
    _refreshing = true;
    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        return false;
      }
      await user.getIdToken(true);
      return true;
    } catch (error) {
      debugPrint('Token refresh error: $error');
      return false;
    } finally {
      _refreshing = false;
    }
  }

  R _decodeSuccess<R>(dynamic data, R Function(dynamic data)? decoder) {
    if (decoder != null) {
      return decoder(data);
    }
    return data as R;
  }

  String? _parseErrorMessage(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ?? decoded['error']?.toString();
      }
      return decoded.toString();
    } catch (_) {
      return body;
    }
  }
}
