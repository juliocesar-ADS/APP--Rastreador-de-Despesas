import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../data/local_store.dart';
import '../models.dart';
import '../services/sale_receipt_service.dart';

class TransactionFormResult {
  const TransactionFormResult({
    required this.isSale,
    this.saleId,
    this.pdfError,
  });

  final bool isSale;
  final int? saleId;
  final String? pdfError;
}

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.store,
    required this.isSale,
    this.initial,
  });

  final LocalStore store;
  final bool isSale;
  final Movimentacao? initial;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _observation = TextEditingController();
  final _saleLines = <_SaleLine>[];
  final _expenseLines = <_ExpenseLine>[];
  late DateTime _date;
  late TimeOfDay _time;
  late String _paymentMethod;
  late Future<void> _ready;
  List<Map<String, Object?>> _products = [];
  List<Map<String, Object?>> _categories = [];
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial == null ? DateTime.now() : DateTime.parse(initial.date);
    _time = initial == null
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: int.parse(initial.time.substring(0, 2)),
            minute: int.parse(initial.time.substring(3, 5)),
          );
    _paymentMethod = initial?.paymentMethod ?? 'dinheiro';
    _observation.text = initial?.observation ?? '';
    if (widget.isSale) {
      _saleLines.add(
        _SaleLine(
          productId: null,
          name: initial?.description ?? '',
          unitPrice: initial?.amount ?? '',
          quantity: '1',
        ),
      );
    } else {
      _expenseLines.add(
        _ExpenseLine(
          description: initial?.description ?? '',
          amount: initial?.amount ?? '',
          categoryId: initial?.categoryId,
        ),
      );
    }
    _ready = _loadOptions();
  }

  Future<void> _loadOptions() async {
    final values = await Future.wait([
      widget.store.products(),
      widget.store.categories(),
    ]);
    _products = values[0];
    _categories = values[1];
    if (_editing && widget.isSale) {
      final receipt = await widget.store.saleReceipt(widget.initial!.id);
      final savedItems = receipt['itens']! as List<Object?>;
      if (savedItems.isNotEmpty) {
        for (final item in savedItems.cast<Map<String, Object?>>()) {
          _saleLines.add(
            _SaleLine(
              productId: item['produto_id'] as int?,
              name: item['produto_nome']! as String,
              unitPrice: item['valor_unitario']! as String,
              quantity: item['quantidade']! as String,
            ),
          );
        }
        _saleLines.removeAt(0).dispose();
      } else {
        _saleLines.first.productId = null;
      }
    }
    if (_editing && !widget.isSale && _expenseLines.single.categoryId == null) {
      _expenseLines.single.categoryId = _categories.firstOrNull?['id'] as int?;
    }
    if (!widget.isSale && _expenseLines.single.categoryId == null) {
      _expenseLines.single.categoryId = _categories.firstOrNull?['id'] as int?;
    }
  }

  @override
  void dispose() {
    _observation.dispose();
    for (final line in _saleLines) {
      line.dispose();
    }
    for (final line in _expenseLines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _addProduct() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadastrar produto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome do produto',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Preço unitário',
                prefixText: 'R\$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (name.text.trim(), price.text.trim())),
            child: const Text('Salvar produto'),
          ),
        ],
      ),
    );
    try {
      if (result == null) return;
      final created = await widget.store.createProduct(
        name: result.$1,
        price: _normalizeAmount(result.$2),
      );
      if (!mounted) return;
      setState(() {
        _products = [..._products, created]
          ..sort(
            (a, b) => (a['nome']! as String).compareTo(b['nome']! as String),
          );
        final emptyLine = _saleLines.indexWhere(
          (line) => line.productId == null && line.name.text.trim().isEmpty,
        );
        final line = emptyLine < 0 ? _SaleLine() : _saleLines[emptyLine];
        if (emptyLine < 0) _saleLines.add(line);
        line
          ..productId = created['id']! as int
          ..name.text = created['nome']! as String
          ..unitPrice.text = created['valor']! as String;
      });
    } on LocalStoreException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      name.dispose();
      price.dispose();
    }
  }

  void _removeSaleLine(int index) {
    if (_saleLines.length == 1) return;
    setState(() => _saleLines.removeAt(index).dispose());
  }

  _ExpenseLine _addExpenseLine() {
    final line = _ExpenseLine(
      categoryId: _categories.firstOrNull?['id'] as int?,
    );
    setState(() => _expenseLines.add(line));
    return line;
  }

  void _removeExpenseLine(int index) {
    if (_expenseLines.length == 1) return;
    setState(() => _expenseLines.removeAt(index).dispose());
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data do lançamento',
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Horário do lançamento',
    );
    if (selected != null) setState(() => _time = selected);
  }

  String _normalizeAmount(String value) {
    final trimmed = value.trim();
    if (trimmed.contains(',')) {
      return trimmed.replaceAll('.', '').replaceAll(',', '.');
    }
    return trimmed;
  }

  bool _validAmount(String value) {
    final normalized = _normalizeAmount(value);
    return RegExp(r'^\d{1,11}(?:\.\d{1,2})?$').hasMatch(normalized) &&
        (double.tryParse(normalized) ?? 0) > 0;
  }

  bool _validQuantity(String value) {
    final normalized = _normalizeAmount(value);
    return RegExp(r'^\d{1,8}(?:\.\d{1,3})?$').hasMatch(normalized) &&
        (double.tryParse(normalized) ?? 0) > 0;
  }

  String _amountAsDecimal(String value) {
    final normalized = _normalizeAmount(value);
    if (!normalized.contains('.')) return '$normalized.00';
    final decimals = normalized.split('.').last;
    return decimals.length == 1 ? '${normalized}0' : normalized;
  }

  String _quantityAsDecimal(String value) {
    final normalized = _normalizeAmount(value);
    if (!normalized.contains('.')) return normalized;
    final decimals = normalized.split('.').last.padRight(3, '0');
    return '${normalized.split('.').first}.${decimals.substring(0, 3)}';
  }

  int _lineTotalCents(_SaleLine line) {
    if (!_validAmount(line.unitPrice.text) ||
        !_validQuantity(line.quantity.text)) {
      return 0;
    }
    final priceCents =
        (double.parse(_normalizeAmount(line.unitPrice.text)) * 100).round();
    final milli = (double.parse(_normalizeAmount(line.quantity.text)) * 1000)
        .round();
    return (priceCents * milli + 500) ~/ 1000;
  }

  String _saleTotal() {
    final cents = _saleLines.fold<int>(
      0,
      (sum, line) => sum + _lineTotalCents(line),
    );
    return 'R\$ ${(cents ~/ 100)},${(cents % 100).toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _error = null);
    final valid = _formKey.currentState?.validate() ?? false;
    final lineData = <Map<String, Object?>>[];
    if (valid && widget.isSale) {
      for (final line in _saleLines) {
        if (line.productId == null && line.name.text.trim().isEmpty) {
          setState(() => _error = 'Escolha ou informe o nome de cada produto.');
          return;
        }
        if (line.productId == null && !_validAmount(line.unitPrice.text)) {
          setState(() => _error = 'Informe um preço válido para cada produto.');
          return;
        }
        if (!_validQuantity(line.quantity.text)) {
          setState(() => _error = 'Confira as quantidades dos produtos.');
          return;
        }
        lineData.add({
          'produto_id': line.productId,
          'produto_nome': line.name.text.trim(),
          'quantidade': _quantityAsDecimal(line.quantity.text),
          'valor_unitario': _amountAsDecimal(line.unitPrice.text),
        });
      }
    }
    if (!valid) return;
    if (!widget.isSale) {
      for (final line in _expenseLines) {
        if (line.categoryId == null) {
          setState(() => _error = 'Selecione uma categoria para cada gasto.');
          return;
        }
      }
    }
    setState(() => _saving = true);
    final date = DateFormat('yyyy-MM-dd').format(_date);
    final time =
        '${_time.hour.toString().padLeft(2, '0')}:'
        '${_time.minute.toString().padLeft(2, '0')}';
    final observation = _observation.text.trim().isEmpty
        ? null
        : _observation.text.trim();
    try {
      if (widget.isSale) {
        final saleId = await widget.store.saveSale({
          'descricao': lineData.map((item) => item['produto_nome']).join(', '),
          'valor': '0.01',
          'itens': lineData,
          'data_venda': date,
          'hora_venda': time,
          'forma_pagamento': _paymentMethod,
          'observacao': observation,
        }, id: widget.initial?.id);
        String? pdfError;
        if (!_editing) {
          try {
            final receipt = await widget.store.saleReceipt(saleId);
            final bytes = await SaleReceiptService.createPdf(receipt);
            await Printing.sharePdf(
              bytes: bytes,
              filename: 'comprovante-venda-$saleId.pdf',
            );
          } on Exception catch (error) {
            pdfError = error.toString();
          }
        }
        if (mounted) {
          Navigator.pop(
            context,
            TransactionFormResult(
              isSale: true,
              saleId: saleId,
              pdfError: pdfError,
            ),
          );
        }
        return;
      }

      final expenses = _expenseLines
          .map(
            (line) => <String, Object?>{
              'descricao': line.description.text.trim(),
              'valor': _amountAsDecimal(line.amount.text),
              'categoria_id': line.categoryId,
              'data_gasto': date,
              'hora_gasto': time,
              'observacao': observation,
            },
          )
          .toList(growable: false);
      await widget.store.saveExpenses(expenses, id: widget.initial?.id);
      if (mounted) {
        Navigator.pop(context, const TransactionFormResult(isSale: false));
      }
    } on LocalStoreException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSale ? 'Venda' : 'Gastos';
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar $title' : 'Registrar $title'),
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Não foi possível carregar os dados: ${snapshot.error}',
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                return Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 16,
                      12,
                      wide ? 28 : 16,
                      30,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _QuickHeader(
                                isSale: widget.isSale,
                                editing: _editing,
                              ),
                              const SizedBox(height: 16),
                              if (widget.isSale)
                                _saleEditor(wide, constraints.maxWidth)
                              else
                                _expenseEditor(wide, constraints.maxWidth),
                              const SizedBox(height: 14),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _dateTimeControls()),
                                    const SizedBox(width: 14),
                                    Expanded(child: _paymentOrObservation()),
                                  ],
                                )
                              else ...[
                                _paymentOrObservation(),
                                const SizedBox(height: 12),
                                _dateTimeControls(),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                _ErrorBanner(message: _error!),
                              ],
                              const SizedBox(height: 14),
                              if (widget.isSale) _totalCard(),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        widget.isSale
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.done_all_rounded,
                                      ),
                                label: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    _saving
                                        ? 'Salvando…'
                                        : widget.isSale
                                        ? 'Salvar venda e gerar comprovante'
                                        : _editing
                                        ? 'Salvar alteração'
                                        : _expenseLines.length == 1
                                        ? 'Salvar gasto'
                                        : 'Salvar ${_expenseLines.length} gastos',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _saleEditor(bool wide, double availableWidth) {
    final cardWidth = wide
        ? (availableWidth.clamp(760, 1100).toDouble() - 44) / 2
        : double.infinity;
    return _SectionCard(
      title: 'Produtos da venda',
      subtitle: 'Selecione produtos cadastrados e ajuste quantidade.',
      trailing: IconButton.filledTonal(
        tooltip: 'Cadastrar produto',
        onPressed: _addProduct,
        icon: const Icon(Icons.add_box_outlined),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var index = 0; index < _saleLines.length; index++)
                SizedBox(width: cardWidth, child: _saleLineCard(index)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _saleLines.add(_SaleLine())),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar outro produto'),
            ),
          ),
          if (_products.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Cadastre um produto para selecioná-lo rapidamente.'),
            ),
        ],
      ),
    );
  }

  Widget _saleLineCard(int index) {
    final line = _saleLines[index];
    final validProducts = _products;
    final productExists = validProducts.any(
      (product) => product['id'] == line.productId,
    );
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 15, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: productExists ? line.productId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Produto',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Produto avulso'),
                      ),
                      ...validProducts.map(
                        (product) => DropdownMenuItem<int?>(
                          value: product['id']! as int,
                          child: Text(
                            product['nome']! as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (id) {
                      final selected = validProducts
                          .where((product) => product['id'] == id)
                          .firstOrNull;
                      setState(() {
                        line
                          ..productId = id
                          ..name.text = selected?['nome'] as String? ?? ''
                          ..unitPrice.text =
                              selected?['valor'] as String? ?? '';
                      });
                    },
                  ),
                ),
                if (_saleLines.length > 1)
                  IconButton(
                    tooltip: 'Remover produto',
                    onPressed: () => _removeSaleLine(index),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (!productExists || line.productId == null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: line.name,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome do produto',
                        isDense: true,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe o produto.'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: line.unitPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Preço unitário',
                        prefixText: 'R\$ ',
                        isDense: true,
                      ),
                      validator: (value) =>
                          !_validAmount(value ?? '') ? 'Preço inválido.' : null,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unitário: ${formatMoney(line.unitPrice.text)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      hintText: '1',
                      isDense: true,
                    ),
                    validator: (value) => !_validQuantity(value ?? '')
                        ? 'Quantidade inválida.'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    formatMoney(
                      (_lineTotalCents(line) / 100).toStringAsFixed(2),
                    ),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseEditor(bool wide, double availableWidth) {
    final cardWidth = wide
        ? (availableWidth.clamp(760, 1100).toDouble() - 44) / 2
        : double.infinity;
    return _SectionCard(
      title: 'Gastos',
      subtitle: 'Adicione vários lançamentos e salve todos de uma vez.',
      trailing: IconButton.filledTonal(
        tooltip: 'Adicionar gasto',
        onPressed: _editing ? null : () => _addExpenseLine(),
        icon: const Icon(Icons.add),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var index = 0; index < _expenseLines.length; index++)
            SizedBox(width: cardWidth, child: _expenseLineCard(index)),
        ],
      ),
    );
  }

  Widget _expenseLineCard(int index) {
    final line = _expenseLines[index];
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 15, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: line.description,
                    autofocus: index == 0 && !_editing,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'O que foi o gasto?',
                      hintText: 'Ex.: Compra de material',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe a descrição.'
                        : null,
                  ),
                ),
                if (_expenseLines.length > 1)
                  IconButton(
                    tooltip: 'Remover gasto',
                    onPressed: () => _removeExpenseLine(index),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    initialValue: line.categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      isDense: true,
                    ),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<int>(
                            value: category['id']! as int,
                            child: Text(
                              category['nome']! as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => setState(() => line.categoryId = id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: line.amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: 'R\$ ',
                      isDense: true,
                    ),
                    validator: (value) =>
                        !_validAmount(value ?? '') ? 'Valor inválido.' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeControls() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(DateFormat('dd/MM/yyyy').format(_date)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _pickTime,
          icon: const Icon(Icons.schedule),
          label: Text(_time.format(context)),
        ),
      ),
    ],
  );

  Widget _paymentOrObservation() {
    if (widget.isSale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Forma de pagamento',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'pix', child: Text('Pix')),
              DropdownMenuItem(
                value: 'cartao_debito',
                child: Text('Cartão de débito'),
              ),
              DropdownMenuItem(
                value: 'cartao_credito',
                child: Text('Cartão de crédito'),
              ),
              DropdownMenuItem(value: 'outro', child: Text('Outro')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _paymentMethod = value);
            },
          ),
          const SizedBox(height: 12),
          _observationField(),
        ],
      );
    }
    return _observationField();
  }

  Widget _observationField() => TextFormField(
    controller: _observation,
    textCapitalization: TextCapitalization.sentences,
    maxLength: 2000,
    decoration: const InputDecoration(
      labelText: 'Observação (opcional)',
      prefixIcon: Icon(Icons.notes_outlined),
    ),
  );

  Widget _totalCard() => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('TOTAL DA VENDA'),
          Text(
            _saleTotal(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SaleLine {
  _SaleLine({
    this.productId,
    String name = '',
    String unitPrice = '',
    String quantity = '1',
  }) : name = TextEditingController(text: name),
       unitPrice = TextEditingController(text: unitPrice),
       quantity = TextEditingController(text: quantity);

  int? productId;
  final TextEditingController name;
  final TextEditingController unitPrice;
  final TextEditingController quantity;

  void dispose() {
    name.dispose();
    unitPrice.dispose();
    quantity.dispose();
  }
}

class _ExpenseLine {
  _ExpenseLine({String description = '', String amount = '', this.categoryId})
    : description = TextEditingController(text: description),
      amount = TextEditingController(text: amount);

  final TextEditingController description;
  final TextEditingController amount;
  int? categoryId;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _QuickHeader extends StatelessWidget {
  const _QuickHeader({required this.isSale, required this.editing});

  final bool isSale;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final color = isSale ? const Color(0xff16815f) : const Color(0xffc05750);
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: Icon(isSale ? Icons.point_of_sale : Icons.payments_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing
                    ? 'Edite os dados'
                    : isSale
                    ? 'Venda rápida'
                    : 'Gasto rápido',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                editing
                    ? 'Revise os campos e salve as alterações.'
                    : 'Digite, adicione os itens e conclua.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}
