import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../data/local_store.dart';
import '../models.dart';
import '../services/sale_receipt_service.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.store});

  final LocalStore store;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _storeName = TextEditingController();
  final _customerName = TextEditingController();
  late Future<
    ({List<Map<String, Object?>> sales, Map<String, String> settings})
  >
  _data;
  int? _selectedId;
  bool _settingsLoaded = false;
  bool _showDate = true;
  bool _showTime = true;
  bool _showPayment = true;
  bool _showItems = true;
  bool _showQuantities = true;
  bool _showUnitPrices = true;
  bool _showLineTotals = true;
  bool _showObservation = true;
  bool _showTotal = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<({List<Map<String, Object?>> sales, Map<String, String> settings})>
  _load() async {
    final values = await Future.wait([
      widget.store.sales(),
      widget.store.receiptSettings(),
    ]);
    return (
      sales: values[0] as List<Map<String, Object?>>,
      settings: values[1] as Map<String, String>,
    );
  }

  void _initializeSettings(Map<String, String> settings) {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    _storeName.text = settings['storeName'] ?? '';
    _showDate = _setting(settings, 'showDate');
    _showTime = _setting(settings, 'showTime');
    _showPayment = _setting(settings, 'showPayment');
    _showItems = _setting(settings, 'showItems');
    _showQuantities = _setting(settings, 'showQuantities');
    _showUnitPrices = _setting(settings, 'showUnitPrices');
    _showLineTotals = _setting(settings, 'showLineTotals');
    _showObservation = _setting(settings, 'showObservation');
    _showTotal = _setting(settings, 'showTotal');
  }

  bool _setting(Map<String, String> settings, String key) =>
      settings[key] == null ? true : settings[key] == 'true';

  @override
  void dispose() {
    _storeName.dispose();
    _customerName.dispose();
    super.dispose();
  }

  Future<void> _generate(Map<String, Object?> sale) async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await widget.store.saveReceiptSettings({
        'storeName': _storeName.text.trim(),
        'showDate': '$_showDate',
        'showTime': '$_showTime',
        'showPayment': '$_showPayment',
        'showItems': '$_showItems',
        'showQuantities': '$_showQuantities',
        'showUnitPrices': '$_showUnitPrices',
        'showLineTotals': '$_showLineTotals',
        'showObservation': '$_showObservation',
        'showTotal': '$_showTotal',
      });
      final receipt = await widget.store.saleReceipt(sale['id']! as int);
      final bytes = await SaleReceiptService.createPdf(
        receipt,
        options: ReceiptOptions(
          storeName: _storeName.text.trim(),
          customerName: _customerName.text.trim(),
          showDate: _showDate,
          showTime: _showTime,
          showPayment: _showPayment,
          showItems: _showItems,
          showQuantities: _showQuantities,
          showUnitPrices: _showUnitPrices,
          showLineTotals: _showLineTotals,
          showObservation: _showObservation,
          showTotal: _showTotal,
        ),
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'comprovante-venda-${sale['id']}.pdf',
      );
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<
        ({List<Map<String, Object?>> sales, Map<String, String> settings})
      >(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar os comprovantes: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          _initializeSettings(data.settings);
          if (data.sales.isEmpty) {
            return const _NoSales();
          }
          _selectedId ??= data.sales.first['id']! as int;
          final selectedSale = data.sales.firstWhere(
            (sale) => sale['id'] == _selectedId,
            orElse: () => data.sales.first,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final selector = _saleSelector(data.sales);
              final customizer = _customizer(selectedSale);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 24 : 16,
                  12,
                  wide ? 24 : 16,
                  100,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ReceiptIntro(wide: wide),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: selector),
                              const SizedBox(width: 16),
                              Expanded(child: customizer),
                            ],
                          )
                        else ...[
                          selector,
                          const SizedBox(height: 12),
                          customizer,
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

  Widget _saleSelector(List<Map<String, Object?>> sales) => _Panel(
    title: '1. Escolha uma venda',
    subtitle: 'O comprovante usa os dados da venda já registrada.',
    child: Column(
      children: [
        for (final sale in sales)
          _SaleOption(
            sale: sale,
            selected: sale['id'] == _selectedId,
            onTap: () => setState(() => _selectedId = sale['id']! as int),
          ),
      ],
    ),
  );

  Widget _customizer(Map<String, Object?> sale) => _Panel(
    title: '2. Personalize o comprovante',
    subtitle: 'As opções ficam salvas neste aparelho para a próxima vez.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _storeName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome da loja ou negócio',
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _customerName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome do cliente (opcional)',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Informações que serão exibidas',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        _toggle('Data da venda', _showDate, (value) => _showDate = value),
        _toggle('Horário', _showTime, (value) => _showTime = value),
        _toggle(
          'Forma de pagamento',
          _showPayment,
          (value) => _showPayment = value,
        ),
        _toggle('Lista de produtos', _showItems, (value) => _showItems = value),
        if (_showItems) ...[
          _toggle(
            'Quantidades',
            _showQuantities,
            (value) => _showQuantities = value,
            nested: true,
          ),
          _toggle(
            'Preços unitários',
            _showUnitPrices,
            (value) => _showUnitPrices = value,
            nested: true,
          ),
          _toggle(
            'Totais por produto',
            _showLineTotals,
            (value) => _showLineTotals = value,
            nested: true,
          ),
        ],
        _toggle(
          'Observação da venda',
          _showObservation,
          (value) => _showObservation = value,
        ),
        _toggle('Valor total', _showTotal, (value) => _showTotal = value),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            'Não foi possível gerar o PDF: $_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _generating ? null : () => _generate(sale),
          icon: _generating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              _generating ? 'Preparando PDF…' : 'Gerar e compartilhar PDF',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Comprovante de venda sem validade fiscal.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _toggle(
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    bool nested = false,
  }) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.only(left: nested ? 22 : 0, right: 0),
    dense: true,
    title: Text(label),
    value: value,
    onChanged: (selected) => setState(() => onChanged(selected)),
  );
}

class _ReceiptIntro extends StatelessWidget {
  const _ReceiptIntro({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: wide ? 27 : 23,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.receipt_long_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprovantes',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Text('Escolha uma venda e monte o PDF do seu jeito.'),
          ],
        ),
      ),
    ],
  );
}

class _SaleOption extends StatelessWidget {
  const _SaleOption({
    required this.sale,
    required this.selected,
    required this.onTap,
  });

  final Map<String, Object?> sale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(sale['data_venda']! as String);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.check_circle : Icons.receipt_long_outlined,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          sale['descricao']! as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${date == null ? sale['data_venda'] : DateFormat('dd/MM/yyyy').format(date)}'
          ' · ${((sale['hora_venda']! as String).substring(0, 5))}'
          ' · ${sale['quantidade_itens']} itens',
        ),
        trailing: Text(
          formatMoney(sale['valor']! as String),
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _NoSales extends StatelessWidget {
  const _NoSales();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Nenhuma venda para emitir comprovante',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Registre uma venda em “Novo lançamento”. Ela aparecerá aqui.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
