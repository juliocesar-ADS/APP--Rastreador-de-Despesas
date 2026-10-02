import 'dart:io';

import 'package:controle_gastos/data/local_store.dart';
import 'package:controle_gastos/services/sale_receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('salva venda com itens e gera PDF personalizável não fiscal', () async {
    final productA = await store.createProduct(name: 'Café', price: '12.50');
    final productB = await store.createProduct(name: 'Pão', price: '2.00');
    final saleId = await store.saveSale({
      'descricao': 'Venda com itens',
      'valor': '0.01',
      'itens': [
        {
          'produto_id': productA['id'],
          'produto_nome': 'Café',
          'quantidade': '2',
          'valor_unitario': '12.50',
        },
        {
          'produto_id': productB['id'],
          'produto_nome': 'Pão',
          'quantidade': '1.5',
          'valor_unitario': '2.00',
        },
      ],
      'data_venda': '2026-10-01',
      'hora_venda': '09:15',
      'forma_pagamento': 'pix',
      'observacao': null,
    });

    final receipt = await store.saleReceipt(saleId);
    expect(receipt['total'], '28.00');
    expect(receipt['itens'], hasLength(2));
    expect((receipt['itens']! as List).last['total'], '3.00');
    expect((await store.sales()).single['valor'], '28.00');

    final pdf = await SaleReceiptService.createPdf(
      receipt,
      options: const ReceiptOptions(
        storeName: 'Loja da Ana',
        customerName: 'Cliente Teste',
        showPayment: false,
        showObservation: false,
      ),
    );
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });

  test('salva lote de gastos atomicamente', () async {
    final category = (await store.categories()).first;
    final expenses = [
      {
        'descricao': 'Material',
        'valor': '10.00',
        'data_gasto': '2026-10-01',
        'hora_gasto': '10:00',
        'categoria_id': category['id'],
        'observacao': null,
      },
      {
        'descricao': 'Entrega',
        'valor': '5.50',
        'data_gasto': '2026-10-01',
        'hora_gasto': '10:01',
        'categoria_id': category['id'],
        'observacao': null,
      },
    ];

    await store.saveExpenses(expenses);
    expect(await store.expenses(), hasLength(2));

    await expectLater(
      store.saveExpenses([
        expenses.first,
        {...expenses.last, 'valor': 'inválido'},
      ]),
      throwsA(isA<LocalStoreException>()),
    );
    expect(await store.expenses(), hasLength(2));
  });

  test('migra banco v1 preservando vendas e gastos existentes', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'rastreador-v1-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final database = await databaseFactoryFfi.openDatabase(
      file.path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE categorias (id INTEGER PRIMARY KEY, nome TEXT NOT NULL UNIQUE)',
          );
          await db.execute('''
            CREATE TABLE vendas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              descricao TEXT NOT NULL,
              valor_centavos INTEGER NOT NULL,
              data_venda TEXT NOT NULL,
              hora_venda TEXT NOT NULL,
              forma_pagamento TEXT NOT NULL,
              observacao TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE gastos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              categoria_id INTEGER NOT NULL,
              descricao TEXT NOT NULL,
              valor_centavos INTEGER NOT NULL,
              data_gasto TEXT NOT NULL,
              hora_gasto TEXT NOT NULL,
              observacao TEXT,
              FOREIGN KEY (categoria_id) REFERENCES categorias (id)
            )
          ''');
          await db.insert('categorias', {'nome': 'Categoria antiga'});
          await db.insert('vendas', {
            'descricao': 'Venda antiga',
            'valor_centavos': 1234,
            'data_venda': '2026-09-30',
            'hora_venda': '12:00',
            'forma_pagamento': 'dinheiro',
          });
          await db.insert('gastos', {
            'categoria_id': 1,
            'descricao': 'Gasto antigo',
            'valor_centavos': 500,
            'data_gasto': '2026-09-30',
            'hora_gasto': '12:30',
          });
        },
      ),
    );
    await database.close();

    final migratedStore = LocalStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: file.path,
    );
    await migratedStore.initialize();
    expect((await migratedStore.sales()).single['valor'], '12.34');
    expect((await migratedStore.expenses()).single['valor'], '5.00');
    expect(await migratedStore.products(), isEmpty);
    await migratedStore.saveReceiptSettings({
      'storeName': 'Mercadinho do bairro',
      'showPayment': 'false',
    });
    expect(await migratedStore.receiptSettings(), {
      'storeName': 'Mercadinho do bairro',
      'showPayment': 'false',
    });
    await migratedStore.close();
    await file.delete();
  });

  test(
    'migra banco v2 e preserva produtos e itens de vendas existentes',
    () async {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'rastreador-v2-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final database = await databaseFactoryFfi.openDatabase(
        file.path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE categorias (id INTEGER PRIMARY KEY, nome TEXT NOT NULL UNIQUE)',
            );
            await db.execute('''
            CREATE TABLE vendas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              descricao TEXT NOT NULL,
              valor_centavos INTEGER NOT NULL,
              data_venda TEXT NOT NULL,
              hora_venda TEXT NOT NULL,
              forma_pagamento TEXT NOT NULL,
              observacao TEXT
            )
          ''');
            await db.execute('''
            CREATE TABLE gastos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              categoria_id INTEGER NOT NULL,
              descricao TEXT NOT NULL,
              valor_centavos INTEGER NOT NULL,
              data_gasto TEXT NOT NULL,
              hora_gasto TEXT NOT NULL,
              observacao TEXT,
              FOREIGN KEY (categoria_id) REFERENCES categorias (id)
            )
          ''');
            await db.execute('''
            CREATE TABLE produtos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nome TEXT NOT NULL COLLATE NOCASE UNIQUE,
              preco_centavos INTEGER NOT NULL,
              ativo INTEGER NOT NULL DEFAULT 1
            )
          ''');
            await db.execute('''
            CREATE TABLE venda_itens (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              venda_id INTEGER NOT NULL,
              produto_id INTEGER,
              produto_nome TEXT NOT NULL,
              quantidade_milesimos INTEGER NOT NULL,
              preco_unitario_centavos INTEGER NOT NULL,
              total_centavos INTEGER NOT NULL,
              FOREIGN KEY (venda_id) REFERENCES vendas (id) ON DELETE CASCADE,
              FOREIGN KEY (produto_id) REFERENCES produtos (id) ON DELETE SET NULL
            )
          ''');
            await db.insert('categorias', {'nome': 'Outros'});
            await db.insert('produtos', {
              'nome': 'Caderno',
              'preco_centavos': 800,
            });
            await db.insert('vendas', {
              'descricao': 'Venda antiga com produto',
              'valor_centavos': 1600,
              'data_venda': '2026-09-30',
              'hora_venda': '12:00',
              'forma_pagamento': 'pix',
            });
            await db.insert('venda_itens', {
              'venda_id': 1,
              'produto_id': 1,
              'produto_nome': 'Caderno',
              'quantidade_milesimos': 2000,
              'preco_unitario_centavos': 800,
              'total_centavos': 1600,
            });
          },
        ),
      );
      await database.close();

      final migratedStore = LocalStore(
        databaseFactory: databaseFactoryFfi,
        databasePath: file.path,
      );
      await migratedStore.initialize();
      expect((await migratedStore.sales()).single['valor'], '16.00');
      expect((await migratedStore.saleReceipt(1))['itens'], hasLength(1));
      expect((await migratedStore.products()).single['nome'], 'Caderno');
      expect(await migratedStore.receiptSettings(), isEmpty);
      await migratedStore.close();
      await file.delete();
    },
  );
}
