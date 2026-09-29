import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _configuredApiUrl = String.fromEnvironment('API_BASE_URL');

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'access_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    String? baseUrl,
    this.tokenStore = const SecureTokenStore(),
    http.Client? client,
  }) : baseUrl = (baseUrl ?? _configuredApiUrl).trim(),
       _client = client ?? http.Client();

  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _client;

  bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        (uri.scheme == 'https' || (kDebugMode && uri.scheme == 'http')) &&
        uri.host.isNotEmpty;
  }

  Future<String?> readToken() => tokenStore.read();

  Future<void> logout() => tokenStore.delete();

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _request(
      'POST',
      '/usuarios',
      authenticated: false,
      body: {'nome': name, 'email': email, 'senha': password},
    );
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _request(
      'POST',
      '/auth/login',
      authenticated: false,
      body: {'email': email, 'senha': password},
    );
    final token = response['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('A API não retornou um token de acesso válido.');
    }
    await tokenStore.write(token);
  }

  Future<Map<String, Object?>> dashboard() => _request('GET', '/dashboard');

  Future<Map<String, Object?>> monthlyReport(int year, int month) =>
      _request('GET', '/relatorios/mes/$year/$month');

  Future<List<Map<String, Object?>>> categories() async =>
      _listFromResponse(await _request('GET', '/categorias/gastos'));

  Future<Map<String, Object?>> createExpenseCategory(String name) =>
      _request('POST', '/categorias/gastos', body: {'nome': name});

  Future<List<Map<String, Object?>>> sales({
    String? startDate,
    String? endDate,
    String? paymentMethod,
  }) async {
    final query = <String, String>{};
    if (startDate != null) query['inicio'] = startDate;
    if (endDate != null) query['fim'] = endDate;
    if (paymentMethod != null) query['forma_pagamento'] = paymentMethod;
    return _listFromResponse(await _request('GET', '/vendas', query: query));
  }

  Future<List<Map<String, Object?>>> expenses({
    String? startDate,
    String? endDate,
    int? categoryId,
  }) async {
    final query = <String, String>{};
    if (startDate != null) query['inicio'] = startDate;
    if (endDate != null) query['fim'] = endDate;
    if (categoryId != null) query['categoria_id'] = '$categoryId';
    return _listFromResponse(await _request('GET', '/gastos', query: query));
  }

  Future<void> saveSale(Map<String, Object?> sale, {int? id}) async {
    await _request(
      id == null ? 'POST' : 'PUT',
      id == null ? '/vendas' : '/vendas/$id',
      body: sale,
    );
  }

  Future<void> saveExpense(Map<String, Object?> expense, {int? id}) async {
    await _request(
      id == null ? 'POST' : 'PUT',
      id == null ? '/gastos' : '/gastos/$id',
      body: expense,
    );
  }

  Future<void> deleteSale(int id) async {
    await _request('DELETE', '/vendas/$id');
  }

  Future<void> deleteExpense(int id) async {
    await _request('DELETE', '/gastos/$id');
  }

  Uri _uri(String path, Map<String, String>? query) {
    if (!isConfigured) {
      throw const ApiException(
        'Endereço da API ausente ou inválido. Em produção, configure uma URL '
        'HTTPS ao compilar com --dart-define=API_BASE_URL=https://seu-servidor/api.',
      );
    }
    final root = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$root$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    bool authenticated = true,
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final token = authenticated ? await tokenStore.read() : null;
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    late final http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const ApiException(
        'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
      );
    } on TimeoutException {
      throw const ApiException(
        'A conexão demorou demais. Tente novamente em alguns instantes.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Não foi possível conectar ao servidor. Verifique o endereço da API.',
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return <String, Object?>{};
      }
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        response.statusCode >= 200 && response.statusCode < 300
            ? 'A API retornou uma resposta inválida.'
            : 'Não foi possível concluir a solicitação (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'A API retornou dados em um formato inesperado.',
        statusCode: response.statusCode,
      );
    }
    final result = Map<String, Object?>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = result['erro'];
      final errorMap = error is Map<String, dynamic> ? error : null;
      final message = errorMap?['mensagem'] ?? errorMap?['message'];
      final code = errorMap?['codigo'];
      if (response.statusCode == 401 && authenticated) {
        await tokenStore.delete();
      }
      throw ApiException(
        message is String && message.isNotEmpty
            ? message
            : 'Não foi possível concluir a solicitação (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
        code: code is String ? code : null,
      );
    }
    return result;
  }

  List<Map<String, Object?>> _listFromResponse(Map<String, Object?> response) {
    final data = response['dados'];
    if (data is! List) {
      throw const ApiException('A API retornou uma lista em formato inválido.');
    }
    return data
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const ApiException('A API retornou um lançamento inválido.');
          }
          return Map<String, Object?>.from(item);
        })
        .toList(growable: false);
  }
}
