import 'dart:convert';

import 'package:controle_gastos/api/api_client.dart';
import 'package:controle_gastos/main.dart';
import 'package:flutter/material.dart';
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
  testWidgets(
    'mostra autenticação e informa quando a API não foi configurada',
    (tester) async {
      final api = ApiClient(
        baseUrl: '',
        tokenStore: MemoryTokenStore(),
        client: MockClient(
          (_) async => throw StateError('Não deveria conectar'),
        ),
      );

      await tester.pumpWidget(ControleGastosApp(apiClient: api));
      await tester.pumpAndSettle();

      expect(find.text('Seu dinheiro,\nmais organizado.'), findsOneWidget);
      expect(
        find.text('Endereço da API ainda não foi configurado.'),
        findsNothing,
      );
      expect(
        find.textContaining('endereço da API está ausente ou inválido'),
        findsOneWidget,
      );
      expect(find.text('Entrar'), findsOneWidget);
    },
  );

  testWidgets('faz login e abre o painel com dados retornados pela API', (
    tester,
  ) async {
    final tokenStore = MemoryTokenStore();
    final api = ApiClient(
      baseUrl: 'https://api.exemplo.com/api',
      tokenStore: tokenStore,
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({'access_token': 'jwt-teste', 'token_type': 'Bearer'}),
            200,
          );
        }
        if (request.url.path == '/api/dashboard') {
          return http.Response(
            jsonEncode({
              'data': '2026-09-29',
              'hoje': {
                'total_vendas': '100.00',
                'total_gastos': '25.00',
                'resultado_liquido': '75.00',
                'quantidade_vendas': 1,
                'quantidade_gastos': 1,
              },
              'mes': {
                'total_vendas': '500.00',
                'total_gastos': '100.00',
                'resultado_liquido': '400.00',
                'quantidade_vendas': 5,
                'quantidade_gastos': 2,
              },
              'graficos': {'vendas_gastos_por_dia': [], 'evolucao_mensal': []},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(ControleGastosApp(apiClient: api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-segura');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(tokenStore.token, 'jwt-teste');
    expect(find.text('Este mês'), findsOneWidget);
    expect(find.textContaining('100,00'), findsNWidgets(2));
  });
}
