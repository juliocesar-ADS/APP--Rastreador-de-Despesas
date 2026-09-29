import 'dart:convert';

import 'package:controle_gastos/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

void main() {
  group('ApiClient', () {
    test('salva o token retornado pelo login', () async {
      final store = MemoryTokenStore();
      final client = ApiClient(
        baseUrl: 'https://api.exemplo.com/api',
        tokenStore: store,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/login');
          expect(jsonDecode(request.body), {
            'email': 'ana@example.com',
            'senha': 'senha-segura',
          });
          return http.Response(
            jsonEncode({
              'access_token': 'jwt-de-teste',
              'token_type': 'Bearer',
            }),
            200,
          );
        }),
      );

      await client.login(email: 'ana@example.com', password: 'senha-segura');

      expect(await client.readToken(), 'jwt-de-teste');
    });

    test('envia o token salvo nas rotas privadas', () async {
      final store = MemoryTokenStore()..token = 'jwt-de-teste';
      final client = ApiClient(
        baseUrl: 'https://api.exemplo.com/api/',
        tokenStore: store,
        client: MockClient((request) async {
          expect(request.url.path, '/api/dashboard');
          expect(request.headers['Authorization'], 'Bearer jwt-de-teste');
          return http.Response(jsonEncode({'hoje': <String, Object?>{}}), 200);
        }),
      );

      final response = await client.dashboard();

      expect(response['hoje'], isA<Map<String, Object?>>());
    });

    test('mostra a mensagem da API e limpa sessão após HTTP 401', () async {
      final store = MemoryTokenStore()..token = 'jwt-expirado';
      final client = ApiClient(
        baseUrl: 'https://api.exemplo.com/api',
        tokenStore: store,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'erro': {
                'codigo': 'token_expirado',
                'mensagem': 'O token expirou. Entre novamente.',
              },
            }),
            401,
          ),
        ),
      );

      await expectLater(
        client.dashboard(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'mensagem',
            'O token expirou. Entre novamente.',
          ),
        ),
      );
      expect(await client.readToken(), isNull);
    });

    test('recusa chamadas sem endereço configurado', () async {
      final client = ApiClient(
        baseUrl: '',
        tokenStore: MemoryTokenStore(),
        client: MockClient(
          (_) async => throw StateError('Não deveria conectar'),
        ),
      );

      await expectLater(client.dashboard(), throwsA(isA<ApiException>()));
    });
  });
}
