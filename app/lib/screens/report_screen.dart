import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local_store.dart';
import '../models.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({
    super.key,
    required this.store,
    required this.onEdit,
    required this.onDelete,
  });

  final LocalStore store;
  final ValueChanged<Movimentacao> onEdit;
  final ValueChanged<Movimentacao> onDelete;

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late DateTime _month;
  late Future<Map<String, Object?>> _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _report = _load();
  }

  Future<Map<String, Object?>> _load() =>
      widget.store.monthlyReport(_month.year, _month.month);

  Future<void> _changeMonth(int offset) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _report = _load();
    });
  }

  Future<void> _reload() async {
    setState(() => _report = _load());
    await _report;
  }

  @override
  Widget build(BuildContext context) {
    final current = DateTime.now();
    final isCurrentMonth =
        _month.year == current.year && _month.month == current.month;
    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(_month);
    return FutureBuilder<Map<String, Object?>>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ReportError(error: snapshot.error!, onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final report = snapshot.data!;
        final summary = FinancialSummary.fromJson(
          report['resumo']! as Map<String, Object?>,
        );
        final sales = (report['vendas']! as List<Object?>)
            .map((item) => Movimentacao.fromSale(item! as Map<String, Object?>))
            .toList();
        final expenses = (report['gastos']! as List<Object?>)
            .map(
              (item) => Movimentacao.fromExpense(item! as Map<String, Object?>),
            )
            .toList();
        final items = [...sales, ...expenses]
          ..sort((a, b) {
            final dateOrder = b.date.compareTo(a.date);
            return dateOrder != 0 ? dateOrder : b.time.compareTo(a.time);
          });

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Mês anterior',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      _capitalize(monthName),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Próximo mês',
                    onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: 'Resultado líquido',
                value: summary.net,
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xff087f68),
                emphasized: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Faturamento',
                      value: summary.sales,
                      subtitle: '${summary.salesCount} vendas',
                      icon: Icons.trending_up,
                      color: const Color(0xff16815f),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: 'Gastos',
                      value: summary.expenses,
                      subtitle: '${summary.expenseCount} lançamentos',
                      icon: Icons.trending_down,
                      color: const Color(0xffc05750),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Lançamentos do mês',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 35),
                  child: Center(
                    child: Text('Nenhum lançamento registrado neste mês.'),
                  ),
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TransactionTile(
                      transaction: item,
                      onEdit: () => widget.onEdit(item),
                      onDelete: () => widget.onDelete(item),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            const Text('Não foi possível carregar o relatório.'),
            const SizedBox(height: 6),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
