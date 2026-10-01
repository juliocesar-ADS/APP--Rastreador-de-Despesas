import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;

class LocalStoreException implements Exception {
  const LocalStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalStore {
  LocalStore({this._database, this.databaseFactory, this.databasePath});

  static const _databaseName = 'rastreador_despesas.db';
  static const _databaseVersion = 2;
  static const _defaultCategories = [
    'Alimentação',
    'Moradia',
    'Transporte',
    'Saúde',
    'Contas',
    'Compras',
    'Lazer',
    'Outros',
  ];

  sqflite.Database? _database;
  final sqflite.DatabaseFactory? databaseFactory;
  final String? databasePath;
  Future<sqflite.Database>? _opening;

  Future<void> initialize() async {
    await _db;
  }

  Future<void> close() async {
    final database = _database;
    if (database != null) {
      await database.close();
      _database = null;
      _opening = null;
    }
  }

  Future<sqflite.Database> get _db async {
    if (_database case final database?) return database;
    return _opening ??= _openDatabase();
  }

  Future<sqflite.Database> _openDatabase() async {
    try {
      final databaseFilePath =
          databasePath ??
          path.join(await sqflite.getDatabasesPath(), _databaseName);
      final factory = databaseFactory ?? sqflite.databaseFactory;
      final database = await factory.openDatabase(
        databaseFilePath,
        options: sqflite.OpenDatabaseOptions(
          version: _databaseVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: _createSchema,
          onUpgrade: _upgradeSchema,
        ),
      );
      _database = database;
      return database;
    } on sqflite.DatabaseException catch (error) {
      _opening = null;
      throw LocalStoreException('Não foi possível abrir o banco local: $error');
    }
  }

  static Future<void> _createSchema(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL COLLATE NOCASE UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE vendas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        valor_centavos INTEGER NOT NULL CHECK (valor_centavos > 0),
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
        valor_centavos INTEGER NOT NULL CHECK (valor_centavos > 0),
        data_gasto TEXT NOT NULL,
        hora_gasto TEXT NOT NULL,
        observacao TEXT,
        FOREIGN KEY (categoria_id) REFERENCES categorias (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_vendas_data_hora ON vendas (data_venda, hora_venda, id)',
    );
    await db.execute(
      'CREATE INDEX idx_gastos_data_hora ON gastos (data_gasto, hora_gasto, id)',
    );
    await _createProductSchema(db);
    final batch = db.batch();
    for (final name in _defaultCategories) {
      batch.insert('categorias', {'nome': name});
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _upgradeSchema(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _createProductSchema(db);
  }

  static Future<void> _createProductSchema(sqflite.Database db) async {
    await db.execute('''
      CREATE TABLE produtos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL COLLATE NOCASE UNIQUE,
        preco_centavos INTEGER NOT NULL CHECK (preco_centavos > 0),
        ativo INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE venda_itens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id INTEGER NOT NULL,
        produto_id INTEGER,
        produto_nome TEXT NOT NULL,
        quantidade_milesimos INTEGER NOT NULL CHECK (quantidade_milesimos > 0),
        preco_unitario_centavos INTEGER NOT NULL CHECK (preco_unitario_centavos > 0),
        total_centavos INTEGER NOT NULL CHECK (total_centavos > 0),
        FOREIGN KEY (venda_id) REFERENCES vendas (id) ON DELETE CASCADE,
        FOREIGN KEY (produto_id) REFERENCES produtos (id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_venda_itens_venda ON venda_itens (venda_id, id)',
    );
  }

  Future<List<Map<String, Object?>>> categories() async {
    final db = await _db;
    return db.query('categorias', orderBy: 'nome COLLATE NOCASE');
  }

  Future<Map<String, Object?>> createExpenseCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const LocalStoreException('Informe um nome de categoria válido.');
    }
    final db = await _db;
    try {
      final id = await db.insert('categorias', {'nome': trimmed});
      return {'id': id, 'nome': trimmed};
    } on sqflite.DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const LocalStoreException('Essa categoria já existe.');
      }
      throw LocalStoreException('Não foi possível salvar a categoria: $error');
    }
  }

  Future<List<Map<String, Object?>>> products({String? search}) async {
    final db = await _db;
    final trimmed = search?.trim();
    return db
        .query(
          'produtos',
          where: trimmed == null || trimmed.isEmpty
              ? 'ativo = 1'
              : 'ativo = 1 AND nome LIKE ?',
          whereArgs: trimmed == null || trimmed.isEmpty ? null : ['%$trimmed%'],
          orderBy: 'nome COLLATE NOCASE',
        )
        .then(
          (rows) => rows
              .map(
                (row) => {
                  'id': row['id'],
                  'nome': row['nome'],
                  'valor': _centsToAmount(row['preco_centavos']! as int),
                },
              )
              .toList(growable: false),
        );
  }

  Future<Map<String, Object?>> createProduct({
    required String name,
    required String price,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 120) {
      throw const LocalStoreException('Informe um nome de produto válido.');
    }
    final cents = _amountToCents(price);
    final db = await _db;
    try {
      final id = await db.insert('produtos', {
        'nome': trimmed,
        'preco_centavos': cents,
      });
      return {'id': id, 'nome': trimmed, 'valor': _centsToAmount(cents)};
    } on sqflite.DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const LocalStoreException('Já existe um produto com esse nome.');
      }
      throw LocalStoreException('Não foi possível salvar o produto: $error');
    }
  }

  Future<List<Map<String, Object?>>> sales({
    String? startDate,
    String? endDate,
    String? paymentMethod,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (startDate != null) {
      conditions.add('data_venda >= ?');
      arguments.add(startDate);
    }
    if (endDate != null) {
      conditions.add('data_venda <= ?');
      arguments.add(endDate);
    }
    if (paymentMethod != null) {
      conditions.add('forma_pagamento = ?');
      arguments.add(paymentMethod);
    }
    final rows = await db.rawQuery('''
      SELECT v.*, COUNT(vi.id) AS quantidade_itens
      FROM vendas v
      LEFT JOIN venda_itens vi ON vi.venda_id = v.id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      GROUP BY v.id
      ORDER BY v.data_venda DESC, v.hora_venda DESC, v.id DESC
      ''', arguments);
    return rows.map(_saleForApiShape).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> expenses({
    String? startDate,
    String? endDate,
    int? categoryId,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (startDate != null) {
      conditions.add('g.data_gasto >= ?');
      arguments.add(startDate);
    }
    if (endDate != null) {
      conditions.add('g.data_gasto <= ?');
      arguments.add(endDate);
    }
    if (categoryId != null) {
      conditions.add('g.categoria_id = ?');
      arguments.add(categoryId);
    }
    final rows = await db.rawQuery('''
      SELECT g.id, g.descricao, g.categoria_id, c.nome AS categoria_nome,
        g.valor_centavos, g.data_gasto, g.hora_gasto, g.observacao
      FROM gastos g
      JOIN categorias c ON c.id = g.categoria_id
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ORDER BY g.data_gasto DESC, g.hora_gasto DESC, g.id DESC
      ''', arguments);
    return rows.map(_expenseForApiShape).toList(growable: false);
  }

  Future<int> saveSale(Map<String, Object?> sale, {int? id}) async {
    final db = await _db;
    final items = sale['itens'];
    final itemRows = items is List
        ? items.cast<Map<String, Object?>>()
        : const <Map<String, Object?>>[];
    final totalCents = itemRows.isEmpty
        ? _amountToCents(sale['valor'])
        : itemRows.fold<int>(0, (total, item) => total + _saleItemTotal(item));
    final description = itemRows.isEmpty
        ? sale['descricao']
        : itemRows.length == 1
        ? itemRows.single['produto_nome']
        : '${itemRows.length} produtos';
    final values = <String, Object?>{
      'descricao': description,
      'valor_centavos': totalCents,
      'data_venda': sale['data_venda'],
      'hora_venda': sale['hora_venda'],
      'forma_pagamento': sale['forma_pagamento'],
      'observacao': sale['observacao'],
    };
    try {
      return await db.transaction((txn) async {
        late final int saleId;
        if (id == null) {
          saleId = await txn.insert('vendas', values);
        } else {
          final changed = await txn.update(
            'vendas',
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
          if (changed != 1) {
            throw const LocalStoreException('Venda não encontrada.');
          }
          saleId = id;
          await txn.delete(
            'venda_itens',
            where: 'venda_id = ?',
            whereArgs: [saleId],
          );
        }
        for (final item in itemRows) {
          final productId = item['produto_id'] as int?;
          await txn.insert('venda_itens', {
            'venda_id': saleId,
            'produto_id': productId,
            'produto_nome': item['produto_nome'] ?? item['descricao'],
            'quantidade_milesimos': _quantityToMillis(item['quantidade']),
            'preco_unitario_centavos': _amountToCents(item['valor_unitario']),
            'total_centavos': _saleItemTotal(item),
          });
        }
        return saleId;
      });
    } on sqflite.DatabaseException catch (error) {
      throw LocalStoreException('Não foi possível salvar a venda: $error');
    }
  }

  Future<void> saveExpense(Map<String, Object?> expense, {int? id}) async {
    await saveExpenses([expense], id: id);
  }

  Future<void> saveExpenses(
    List<Map<String, Object?>> expenses, {
    int? id,
  }) async {
    if (expenses.isEmpty) {
      throw const LocalStoreException('Adicione ao menos um gasto.');
    }
    final db = await _db;
    try {
      await db.transaction((txn) async {
        if (id != null) {
          if (expenses.length != 1) {
            throw const LocalStoreException(
              'Edite um gasto por vez para manter o histórico correto.',
            );
          }
          final changed = await txn.update(
            'gastos',
            _expenseValues(expenses.single),
            where: 'id = ?',
            whereArgs: [id],
          );
          if (changed != 1) {
            throw const LocalStoreException('Gasto não encontrado.');
          }
          return;
        }
        for (final expense in expenses) {
          await txn.insert('gastos', _expenseValues(expense));
        }
      });
    } on sqflite.DatabaseException catch (error) {
      throw LocalStoreException('Não foi possível salvar o gasto: $error');
    }
  }

  Map<String, Object?> _expenseValues(Map<String, Object?> expense) => {
    'categoria_id': expense['categoria_id'],
    'descricao': expense['descricao'],
    'valor_centavos': _amountToCents(expense['valor']),
    'data_gasto': expense['data_gasto'],
    'hora_gasto': expense['hora_gasto'],
    'observacao': expense['observacao'],
  };

  Future<Map<String, Object?>> saleReceipt(int saleId) async {
    final db = await _db;
    final sales = await db.query(
      'vendas',
      where: 'id = ?',
      whereArgs: [saleId],
    );
    if (sales.isEmpty) throw const LocalStoreException('Venda não encontrada.');
    final sale = sales.single;
    final rows = await db.query(
      'venda_itens',
      where: 'venda_id = ?',
      whereArgs: [saleId],
      orderBy: 'id',
    );
    return {
      'id': saleId,
      'data': sale['data_venda'],
      'hora': sale['hora_venda'],
      'pagamento': sale['forma_pagamento'],
      'observacao': sale['observacao'],
      'descricao': sale['descricao'],
      'total': _centsToAmount(sale['valor_centavos']! as int),
      'itens': rows
          .map(
            (row) => {
              'produto_id': row['produto_id'],
              'produto_nome': row['produto_nome'],
              'quantidade': _milliToQuantity(
                row['quantidade_milesimos']! as int,
              ),
              'valor_unitario': _centsToAmount(
                row['preco_unitario_centavos']! as int,
              ),
              'total': _centsToAmount(row['total_centavos']! as int),
            },
          )
          .toList(growable: false),
    };
  }

  Future<void> deleteSale(int id) async {
    final db = await _db;
    final deleted = await db.delete('vendas', where: 'id = ?', whereArgs: [id]);
    if (deleted != 1) throw const LocalStoreException('Venda não encontrada.');
  }

  Future<void> deleteExpense(int id) async {
    final db = await _db;
    final deleted = await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
    if (deleted != 1) throw const LocalStoreException('Gasto não encontrado.');
  }

  Future<Map<String, Object?>> dashboard() async {
    final now = DateTime.now();
    final date = _dateKey(now);
    final firstDay = _dateKey(DateTime(now.year, now.month));
    final lastDay = _dateKey(DateTime(now.year, now.month + 1, 0));
    final todaySales = await sales(startDate: date, endDate: date);
    final todayExpenses = await expenses(startDate: date, endDate: date);
    final monthSales = await sales(startDate: firstDay, endDate: lastDay);
    final monthExpenses = await expenses(startDate: firstDay, endDate: lastDay);

    final dailyPoints = <Map<String, Object?>>[];
    final salesByDate = await _totalsByDate(
      'vendas',
      'data_venda',
      firstDay,
      lastDay,
    );
    final expensesByDate = await _totalsByDate(
      'gastos',
      'data_gasto',
      firstDay,
      lastDay,
    );
    for (var day = 1; day <= now.day; day++) {
      final key = _dateKey(DateTime(now.year, now.month, day));
      dailyPoints.add({
        'data': key,
        'vendas': _centsToAmount(salesByDate[key] ?? 0),
        'gastos': _centsToAmount(expensesByDate[key] ?? 0),
      });
    }

    final monthlyPoints = <Map<String, Object?>>[];
    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset);
      final start = _dateKey(DateTime(month.year, month.month));
      final end = _dateKey(DateTime(month.year, month.month + 1, 0));
      final salesTotal = await _sumForPeriod(
        'vendas',
        'data_venda',
        start,
        end,
      );
      final expensesTotal = await _sumForPeriod(
        'gastos',
        'data_gasto',
        start,
        end,
      );
      monthlyPoints.add({
        'mes': '${month.year}-${month.month.toString().padLeft(2, '0')}',
        'vendas': _centsToAmount(salesTotal),
        'gastos': _centsToAmount(expensesTotal),
      });
    }

    return {
      'data': date,
      'hoje': await _summary(todaySales, todayExpenses),
      'mes': await _summary(monthSales, monthExpenses),
      'graficos': {
        'vendas_gastos_por_dia': dailyPoints,
        'evolucao_mensal': monthlyPoints,
      },
    };
  }

  Future<Map<String, Object?>> monthlyReport(int year, int month) async {
    if (month < 1 || month > 12) {
      throw const LocalStoreException('Mês inválido.');
    }
    final start = _dateKey(DateTime(year, month));
    final end = _dateKey(DateTime(year, month + 1, 0));
    final monthSales = await sales(startDate: start, endDate: end);
    final monthExpenses = await expenses(startDate: start, endDate: end);
    return {
      'resumo': await _summary(monthSales, monthExpenses),
      'vendas': monthSales,
      'gastos': monthExpenses,
    };
  }

  Future<Map<String, Object?>> _summary(
    List<Map<String, Object?>> sales,
    List<Map<String, Object?>> expenses,
  ) async {
    final salesTotal = sales.fold<int>(
      0,
      (total, item) => total + _amountToCents(item['valor']),
    );
    final expensesTotal = expenses.fold<int>(
      0,
      (total, item) => total + _amountToCents(item['valor']),
    );
    return {
      'total_vendas': _centsToAmount(salesTotal),
      'total_gastos': _centsToAmount(expensesTotal),
      'resultado_liquido': _centsToAmount(salesTotal - expensesTotal),
      'quantidade_vendas': sales.length,
      'quantidade_gastos': expenses.length,
    };
  }

  Future<Map<String, int>> _totalsByDate(
    String table,
    String dateColumn,
    String start,
    String end,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT $dateColumn AS data, SUM(valor_centavos) AS total '
      'FROM $table WHERE $dateColumn BETWEEN ? AND ? GROUP BY $dateColumn',
      [start, end],
    );
    return {
      for (final row in rows) row['data']! as String: row['total']! as int,
    };
  }

  Future<int> _sumForPeriod(
    String table,
    String dateColumn,
    String start,
    String end,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(valor_centavos), 0) AS total FROM $table '
      'WHERE $dateColumn BETWEEN ? AND ?',
      [start, end],
    );
    return rows.single['total']! as int;
  }

  Map<String, Object?> _saleForApiShape(Map<String, Object?> row) => {
    'id': row['id'],
    'descricao': row['descricao'],
    'valor': _centsToAmount(row['valor_centavos']! as int),
    'quantidade_itens': row['quantidade_itens'] ?? 0,
    'data_venda': row['data_venda'],
    'hora_venda': row['hora_venda'],
    'forma_pagamento': row['forma_pagamento'],
    'observacao': row['observacao'],
  };

  Map<String, Object?> _expenseForApiShape(Map<String, Object?> row) => {
    'id': row['id'],
    'descricao': row['descricao'],
    'categoria_id': row['categoria_id'],
    'categoria_nome': row['categoria_nome'],
    'valor': _centsToAmount(row['valor_centavos']! as int),
    'data_gasto': row['data_gasto'],
    'hora_gasto': row['hora_gasto'],
    'observacao': row['observacao'],
  };

  int _amountToCents(Object? value) {
    if (value is! String) {
      throw const LocalStoreException('O valor informado não é válido.');
    }
    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) {
      throw const LocalStoreException(
        'O valor deve ter até duas casas decimais.',
      );
    }
    final whole = int.parse(match.group(1)!);
    final decimals = (match.group(2) ?? '').padRight(2, '0');
    final cents = whole * 100 + (decimals.isEmpty ? 0 : int.parse(decimals));
    if (cents <= 0) {
      throw const LocalStoreException('O valor precisa ser maior que zero.');
    }
    return cents;
  }

  int _quantityToMillis(Object? value) {
    if (value is! String) {
      throw const LocalStoreException('Informe uma quantidade válida.');
    }
    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,3}))?$').firstMatch(normalized);
    if (match == null) {
      throw const LocalStoreException(
        'A quantidade pode ter até três casas decimais.',
      );
    }
    final whole = int.parse(match.group(1)!);
    final decimals = int.parse((match.group(2) ?? '').padRight(3, '0'));
    final milli = whole * 1000 + decimals;
    if (milli <= 0) {
      throw const LocalStoreException(
        'A quantidade precisa ser maior que zero.',
      );
    }
    return milli;
  }

  String _milliToQuantity(int milli) {
    final whole = milli ~/ 1000;
    final decimals = (milli % 1000).toString().padLeft(3, '0');
    final trimmed = decimals.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
  }

  int _saleItemTotal(Map<String, Object?> item) {
    final quantity = _quantityToMillis(item['quantidade']);
    final price = _amountToCents(item['valor_unitario']);
    final total = (price * quantity + 500) ~/ 1000;
    if (total <= 0) {
      throw const LocalStoreException(
        'O total do produto precisa ser maior que zero.',
      );
    }
    return total;
  }

  String _centsToAmount(int cents) {
    final absolute = cents.abs();
    final amount =
        '${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
    return cents < 0 ? '-$amount' : amount;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
