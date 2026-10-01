import 'dart:io';

import 'package:controle_gastos/data/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    store = LocalStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await store.initialize();
  });

  tearDown(() => store.close());

  test('cria categorias iniciais no primeiro uso', () async {
    final categories = await store.categories();

    expect(categories.map((item) => item['nome']), contains('Alimentação'));
    expect(categories, hasLength(8));
  });

  test('salva venda e gasto e calcula totais exatos', () async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final category = (await store.categories()).first;

    await store.saveSale({
      'descricao': 'Venda no balcão',
      'valor': '125.90',
      'data_venda': date,
      'hora_venda': '10:30',
      'forma_pagamento': 'pix',
      'observacao': null,
    });
    await store.saveExpense({
      'descricao': 'Compra de material',
      'valor': '25.35',
      'data_gasto': date,
      'hora_gasto': '11:00',
      'categoria_id': category['id'],
      'observacao': null,
    });

    final dashboard = await store.dashboard();
    final today = dashboard['hoje']! as Map<String, Object?>;
    expect(today['total_vendas'], '125.90');
    expect(today['total_gastos'], '25.35');
    expect(today['resultado_liquido'], '100.55');
    expect(today['quantidade_vendas'], 1);
    expect(today['quantidade_gastos'], 1);
  });

  test('filtra, edita e exclui lançamentos', () async {
    final category = (await store.categories()).first;
    await store.saveSale({
      'descricao': 'Venda',
      'valor': '10.00',
      'data_venda': '2026-01-15',
      'hora_venda': '09:00',
      'forma_pagamento': 'dinheiro',
      'observacao': null,
    });
    await store.saveSale({
      'descricao': 'Outra venda',
      'valor': '20.00',
      'data_venda': '2026-02-15',
      'hora_venda': '09:00',
      'forma_pagamento': 'pix',
      'observacao': null,
    });

    final january = await store.sales(
      startDate: '2026-01-01',
      endDate: '2026-01-31',
    );
    expect(january, hasLength(1));
    final saleId = january.single['id']! as int;
    await store.saveSale({
      'descricao': 'Venda atualizada',
      'valor': '12.30',
      'data_venda': '2026-01-15',
      'hora_venda': '09:00',
      'forma_pagamento': 'dinheiro',
      'observacao': null,
    }, id: saleId);
    final updated = (await store.sales()).singleWhere(
      (sale) => sale['id'] == saleId,
    );
    expect(updated['descricao'], 'Venda atualizada');

    await store.saveExpense({
      'descricao': 'Gasto para excluir',
      'valor': '2.50',
      'data_gasto': '2026-01-15',
      'hora_gasto': '10:00',
      'categoria_id': category['id'],
      'observacao': null,
    });
    final expenses = await store.expenses(startDate: '2026-01-01');
    expect(expenses.single['categoria_nome'], category['nome']);
    await store.deleteExpense(expenses.single['id']! as int);
    expect(await store.expenses(), isEmpty);
    await store.deleteSale(saleId);
    expect(
      await store.sales(startDate: '2026-01-01', endDate: '2026-01-31'),
      isEmpty,
    );
  });

  test('preserva dados no arquivo local depois de reabrir o banco', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'rastreador-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final path = file.path;
    await store.close();

    store = LocalStore(databaseFactory: databaseFactoryFfi, databasePath: path);
    await store.initialize();
    await store.saveSale({
      'descricao': 'Venda persistente',
      'valor': '1.00',
      'data_venda': '2026-09-30',
      'hora_venda': '12:00',
      'forma_pagamento': 'pix',
      'observacao': null,
    });
    await store.close();

    store = LocalStore(databaseFactory: databaseFactoryFfi, databasePath: path);
    expect((await store.sales()).single['descricao'], 'Venda persistente');
    await store.close();
    await file.delete();
    store = LocalStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await store.initialize();
  });

  test('rejeita valores monetários inválidos', () async {
    await expectLater(
      store.saveSale({
        'descricao': 'Valor inválido',
        'valor': '1.999',
        'data_venda': '2026-09-30',
        'hora_venda': '12:00',
        'forma_pagamento': 'pix',
        'observacao': null,
      }),
      throwsA(isA<LocalStoreException>()),
    );
  });
}
