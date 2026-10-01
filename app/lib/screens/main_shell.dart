import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local_store.dart';
import '../models.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import 'report_screen.dart';
import 'transaction_form_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final LocalStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedTab = 0;
  int _refreshKey = 0;

  Future<void> _newTransaction(bool isSale) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TransactionFormScreen(store: widget.store, isSale: isSale),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _refreshKey++);
    }
  }

  Future<void> _editTransaction(Movimentacao transaction) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          store: widget.store,
          isSale: transaction.isSale,
          initial: transaction,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _refreshKey++);
    }
  }

  Future<void> _deleteTransaction(Movimentacao transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text(
          '“${transaction.description}” será removido deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (transaction.isSale) {
        await widget.store.deleteSale(transaction.id);
      } else {
        await widget.store.deleteExpense(transaction.id);
      }
      if (mounted) {
        setState(() => _refreshKey++);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lançamento excluído.')));
      }
    } on LocalStoreException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _chooseNewTransaction() async {
    final isSale = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Registrar venda'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Registrar gasto'),
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (isSale != null && mounted) await _newTransaction(isSale);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Visão geral', 'Lançamentos', 'Relatórios'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedTab]),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Tooltip(
              message: 'Dados salvos somente neste aparelho',
              child: Icon(Icons.phone_android_rounded),
            ),
          ),
        ],
      ),
      body: switch (_selectedTab) {
        0 => DashboardScreen(
          key: ValueKey('dashboard-$_refreshKey'),
          store: widget.store,
        ),
        1 => HistoryScreen(
          key: ValueKey('history-$_refreshKey'),
          store: widget.store,
          onEdit: _editTransaction,
          onDelete: _deleteTransaction,
        ),
        _ => MonthlyReportScreen(
          key: ValueKey('report-$_refreshKey'),
          store: widget.store,
          onEdit: _editTransaction,
          onDelete: _deleteTransaction,
        ),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _chooseNewTransaction,
        icon: const Icon(Icons.add),
        label: const Text('Novo lançamento'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.store});

  final LocalStore store;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _dashboard = _load();

  Future<DashboardData> _load() async =>
      DashboardData.fromJson(await widget.store.dashboard());

  Future<void> _reload() async {
    setState(() => _dashboard = _load());
    await _dashboard;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RetryState(error: snapshot.error!, onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
            children: [
              Text(
                _greeting(),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(data.date),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text('Hoje', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Vendas',
                      value: data.today.sales,
                      subtitle: '${data.today.salesCount} lançamentos',
                      icon: Icons.trending_up,
                      color: const Color(0xff16815f),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: 'Gastos',
                      value: data.today.expenses,
                      subtitle: '${data.today.expenseCount} lançamentos',
                      icon: Icons.trending_down,
                      color: const Color(0xffc05750),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: 'Resultado líquido de hoje',
                value: data.today.net,
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xff087f68),
                emphasized: true,
              ),
              const SizedBox(height: 22),
              Text('Este mês', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Faturamento',
                      value: data.month.sales,
                      icon: Icons.savings_outlined,
                      color: const Color(0xff16815f),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SummaryCard(
                      title: 'Gastos',
                      value: data.month.expenses,
                      icon: Icons.payments_outlined,
                      color: const Color(0xffc05750),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _ChartCard(
                title: 'Vendas e gastos por dia',
                subtitle: DateFormat('MMMM yyyy', 'pt_BR').format(data.date),
                dailyPoints: data.dailyChart,
              ),
              const SizedBox(height: 16),
              _MonthlyEvolution(points: data.monthlyChart),
            ],
          ),
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia!';
    if (hour < 18) return 'Boa tarde!';
    return 'Boa noite!';
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.dailyPoints,
  });

  final String title;
  final String subtitle;
  final List<DailyChartPoint> dailyPoints;

  @override
  Widget build(BuildContext context) {
    final maximum = dailyPoints.fold<double>(
      0,
      (value, point) => math.max(value, math.max(point.sales, point.expenses)),
    );
    final maxY = maximum == 0 ? 100.0 : maximum * 1.25;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          const _ChartLegend(),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barGroups: dailyPoints.indexed.map((entry) {
                  final index = entry.$1;
                  final point = entry.$2;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: point.sales,
                        width: 5,
                        color: const Color(0xff16815f),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: point.expenses,
                        width: 5,
                        color: const Color(0xffe18a55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                gridData: const FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dailyPoints.length) {
                          return const SizedBox.shrink();
                        }
                        final day = dailyPoints[index].date.day;
                        if (day != 1 && day % 5 != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(meta: meta, child: Text('$day'));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LegendItem(color: Color(0xff16815f), label: 'Vendas'),
        SizedBox(width: 18),
        _LegendItem(color: Color(0xffe18a55), label: 'Gastos'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MonthlyEvolution extends StatelessWidget {
  const _MonthlyEvolution({required this.points});

  final List<MonthlyChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final maximum = points.fold<double>(
      0,
      (value, point) => math.max(value, math.max(point.sales, point.expenses)),
    );
    final maxY = maximum == 0 ? 100.0 : maximum * 1.2;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolução dos últimos 6 meses',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const _ChartLegend(),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barGroups: points.indexed.map((entry) {
                  final index = entry.$1;
                  final point = entry.$2;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: point.sales,
                        width: 8,
                        color: const Color(0xff16815f),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: point.expenses,
                        width: 8,
                        color: const Color(0xffe18a55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                gridData: const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.parse(
                          '${points[index].month}-01',
                        );
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(DateFormat('MMM', 'pt_BR').format(date)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.store,
    required this.onEdit,
    required this.onDelete,
  });

  final LocalStore store;
  final ValueChanged<Movimentacao> onEdit;
  final ValueChanged<Movimentacao> onDelete;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _start;
  DateTime? _end;
  late Future<_HistoryData> _entries = _load();

  Future<_HistoryData> _load() async {
    final start = _start == null
        ? null
        : DateFormat('yyyy-MM-dd').format(_start!);
    final end = _end == null ? null : DateFormat('yyyy-MM-dd').format(_end!);
    final results = await Future.wait([
      widget.store.sales(startDate: start, endDate: end),
      widget.store.expenses(startDate: start, endDate: end),
    ]);
    return _HistoryData(
      sales: results[0].map(Movimentacao.fromSale).toList(growable: false),
      expenses: results[1]
          .map(Movimentacao.fromExpense)
          .toList(growable: false),
    );
  }

  Future<void> _reload() async {
    setState(() => _entries = _load());
    await _entries;
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: start ? 'Data inicial' : 'Data final',
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
        if (_end != null && _end!.isBefore(selected)) _end = null;
      } else {
        _end = selected;
        if (_start != null && _start!.isAfter(selected)) _start = null;
      }
      _entries = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: true),
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(
                      _start == null
                          ? 'Data inicial'
                          : DateFormat('dd/MM/yy').format(_start!),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 17),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: false),
                    icon: const Icon(Icons.event_outlined, size: 17),
                    label: Text(
                      _end == null
                          ? 'Data final'
                          : DateFormat('dd/MM/yy').format(_end!),
                    ),
                  ),
                ),
                if (_start != null || _end != null)
                  IconButton(
                    tooltip: 'Limpar período',
                    onPressed: () {
                      setState(() {
                        _start = null;
                        _end = null;
                        _entries = _load();
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Tudo'),
              Tab(text: 'Vendas'),
              Tab(text: 'Gastos'),
            ],
          ),
          Expanded(
            child: FutureBuilder<_HistoryData>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _RetryState(error: snapshot.error!, onRetry: _reload);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final all = [...data.sales, ...data.expenses]
                  ..sort(_compareTransactions);
                return TabBarView(
                  children: [
                    _TransactionList(
                      items: all,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
                    _TransactionList(
                      items: data.sales,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
                    _TransactionList(
                      items: data.expenses,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryData {
  const _HistoryData({required this.sales, required this.expenses});

  final List<Movimentacao> sales;
  final List<Movimentacao> expenses;
}

int _compareTransactions(Movimentacao first, Movimentacao second) {
  final dateOrder = second.date.compareTo(first.date);
  return dateOrder != 0 ? dateOrder : second.time.compareTo(first.time);
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Movimentacao> items;
  final ValueChanged<Movimentacao> onEdit;
  final ValueChanged<Movimentacao> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nenhum lançamento por aqui',
        subtitle: 'Use “Novo lançamento” para registrar uma venda ou gasto.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => TransactionTile(
        transaction: items[index],
        onEdit: () => onEdit(items[index]),
        onDelete: () => onDelete(items[index]),
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.error, required this.onRetry});

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
            Icon(
              Icons.storage_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar os dados deste aparelho.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
