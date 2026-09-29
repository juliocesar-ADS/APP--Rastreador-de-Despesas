import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

String formatMoney(String value) {
  final amount = double.tryParse(value) ?? 0;
  return _currencyFormat.format(amount);
}

String formatBusinessDate(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : _dateFormat.format(parsed);
}

class FinancialSummary {
  const FinancialSummary({
    required this.sales,
    required this.expenses,
    required this.net,
    required this.salesCount,
    required this.expenseCount,
  });

  final String sales;
  final String expenses;
  final String net;
  final int salesCount;
  final int expenseCount;

  factory FinancialSummary.fromJson(Map<String, Object?> json) {
    return FinancialSummary(
      sales: json['total_vendas'] as String? ?? '0.00',
      expenses: json['total_gastos'] as String? ?? '0.00',
      net: json['resultado_liquido'] as String? ?? '0.00',
      salesCount: json['quantidade_vendas'] as int? ?? 0,
      expenseCount: json['quantidade_gastos'] as int? ?? 0,
    );
  }
}

class DailyChartPoint {
  const DailyChartPoint({
    required this.date,
    required this.sales,
    required this.expenses,
  });

  final DateTime date;
  final double sales;
  final double expenses;

  factory DailyChartPoint.fromJson(Map<String, Object?> json) {
    return DailyChartPoint(
      date: DateTime.parse(json['data']! as String),
      sales: double.parse(json['vendas']! as String),
      expenses: double.parse(json['gastos']! as String),
    );
  }
}

class MonthlyChartPoint {
  const MonthlyChartPoint({
    required this.month,
    required this.sales,
    required this.expenses,
  });

  final String month;
  final double sales;
  final double expenses;

  factory MonthlyChartPoint.fromJson(Map<String, Object?> json) {
    return MonthlyChartPoint(
      month: json['mes']! as String,
      sales: double.parse(json['vendas']! as String),
      expenses: double.parse(json['gastos']! as String),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.date,
    required this.today,
    required this.month,
    required this.dailyChart,
    required this.monthlyChart,
  });

  final DateTime date;
  final FinancialSummary today;
  final FinancialSummary month;
  final List<DailyChartPoint> dailyChart;
  final List<MonthlyChartPoint> monthlyChart;

  factory DashboardData.fromJson(Map<String, Object?> json) {
    final charts = json['graficos']! as Map<String, Object?>;
    final daily = charts['vendas_gastos_por_dia']! as List<Object?>;
    final monthly = charts['evolucao_mensal']! as List<Object?>;
    return DashboardData(
      date: DateTime.parse(json['data']! as String),
      today: FinancialSummary.fromJson(json['hoje']! as Map<String, Object?>),
      month: FinancialSummary.fromJson(json['mes']! as Map<String, Object?>),
      dailyChart: daily
          .map(
            (point) => DailyChartPoint.fromJson(point! as Map<String, Object?>),
          )
          .toList(growable: false),
      monthlyChart: monthly
          .map(
            (point) =>
                MonthlyChartPoint.fromJson(point! as Map<String, Object?>),
          )
          .toList(growable: false),
    );
  }
}

class Movimentacao {
  const Movimentacao({
    required this.id,
    required this.isSale,
    required this.description,
    required this.amount,
    required this.date,
    required this.time,
    required this.observation,
    this.paymentMethod,
    this.categoryId,
    this.categoryName,
  });

  final int id;
  final bool isSale;
  final String description;
  final String amount;
  final String date;
  final String time;
  final String? observation;
  final String? paymentMethod;
  final int? categoryId;
  final String? categoryName;

  factory Movimentacao.fromSale(Map<String, Object?> json) {
    return Movimentacao(
      id: json['id']! as int,
      isSale: true,
      description: json['descricao']! as String,
      amount: json['valor']! as String,
      date: json['data_venda']! as String,
      time: json['hora_venda']! as String,
      observation: json['observacao'] as String?,
      paymentMethod: json['forma_pagamento']! as String,
    );
  }

  factory Movimentacao.fromExpense(Map<String, Object?> json) {
    return Movimentacao(
      id: json['id']! as int,
      isSale: false,
      description: json['descricao']! as String,
      amount: json['valor']! as String,
      date: json['data_gasto']! as String,
      time: json['hora_gasto']! as String,
      observation: json['observacao'] as String?,
      categoryId: json['categoria_id']! as int,
      categoryName: json['categoria_nome']! as String,
    );
  }

  Map<String, Object?> toJson() {
    final common = <String, Object?>{
      'descricao': description,
      'valor': amount,
      'observacao': observation,
    };
    if (isSale) {
      return {
        ...common,
        'data_venda': date,
        'hora_venda': time,
        'forma_pagamento': paymentMethod,
      };
    }
    return {
      ...common,
      'categoria_id': categoryId,
      'data_gasto': date,
      'hora_gasto': time,
    };
  }
}
