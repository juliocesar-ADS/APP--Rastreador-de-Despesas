import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.api,
    required this.isSale,
    this.initial,
  });

  final ApiClient api;
  final bool isSale;
  final Movimentacao? initial;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _observation;
  late DateTime _date;
  late TimeOfDay _time;
  late String? _paymentMethod;
  late int? _categoryId;
  late Future<List<Map<String, Object?>>> _categories;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _description = TextEditingController(text: initial?.description ?? '');
    _amount = TextEditingController(
      text: initial?.amount.replaceAll('.', ',') ?? '',
    );
    _observation = TextEditingController(text: initial?.observation ?? '');
    _date = initial == null ? DateTime.now() : DateTime.parse(initial.date);
    _time = initial == null
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: int.parse(initial.time.substring(0, 2)),
            minute: int.parse(initial.time.substring(3, 5)),
          );
    _paymentMethod = initial?.paymentMethod ?? 'dinheiro';
    _categoryId = initial?.categoryId;
    _categories = widget.api.categories();
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _observation.dispose();
    super.dispose();
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

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome da categoria'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome da categoria.');
      return;
    }

    setState(() => _error = null);
    try {
      final created = await widget.api.createExpenseCategory(name);
      final categories = await widget.api.categories();
      if (mounted) {
        setState(() {
          _categoryId = created['id']! as int;
          _categories = Future.value(categories);
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  String? _validateAmount(String? value) {
    final normalized = _normalizeAmount(value ?? '');
    if (!RegExp(r'^\d{1,11}(?:\.\d{1,2})?$').hasMatch(normalized)) {
      return 'Informe um valor válido, com até duas casas decimais.';
    }
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0) {
      return 'O valor deve ser maior que zero.';
    }
    return null;
  }

  String _normalizeAmount(String value) {
    final trimmed = value.trim();
    if (trimmed.contains(',')) {
      return trimmed.replaceAll('.', '').replaceAll(',', '.');
    }
    return trimmed;
  }

  String _amountAsDecimal() {
    final normalized = _normalizeAmount(_amount.text);
    if (!normalized.contains('.')) return '$normalized.00';
    final decimals = normalized.split('.').last;
    return decimals.length == 1 ? '${normalized}0' : normalized;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (!widget.isSale && _categoryId == null) {
      setState(() => _error = 'Selecione uma categoria para o gasto.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final date = DateFormat('yyyy-MM-dd').format(_date);
    final time =
        '${_time.hour.toString().padLeft(2, '0')}:'
        '${_time.minute.toString().padLeft(2, '0')}';
    final common = <String, Object?>{
      'descricao': _description.text.trim(),
      'valor': _amountAsDecimal(),
      'observacao': _observation.text.trim().isEmpty
          ? null
          : _observation.text.trim(),
    };
    try {
      if (widget.isSale) {
        await widget.api.saveSale({
          ...common,
          'data_venda': date,
          'hora_venda': time,
          'forma_pagamento': _paymentMethod,
        }, id: widget.initial?.id);
      } else {
        await widget.api.saveExpense({
          ...common,
          'categoria_id': _categoryId,
          'data_gasto': date,
          'hora_gasto': time,
        }, id: widget.initial?.id);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSale ? 'Venda' : 'Gasto';
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar $title' : 'Nova $title')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: [
              TextFormField(
                controller: _description,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex.: Venda no balcão',
                  prefixIcon: Icon(Icons.short_text),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe uma descrição.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: '0,00',
                  prefixText: 'R\$ ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 18),
              if (widget.isSale)
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pagamento',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'dinheiro',
                      child: Text('Dinheiro'),
                    ),
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
                  onChanged: (value) => setState(() => _paymentMethod = value),
                )
              else
                FutureBuilder<List<Map<String, Object?>>>(
                  future: _categories,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _CategoryError(
                        error: snapshot.error!,
                        onRetry: () => setState(
                          () => _categories = widget.api.categories(),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final categories = snapshot.data!;
                    if (_categoryId == null && categories.isNotEmpty) {
                      _categoryId = categories.first['id']! as int;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _categoryId,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: categories
                              .map(
                                (category) => DropdownMenuItem<int>(
                                  value: category['id']! as int,
                                  child: Text(category['nome']! as String),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _categoryId = value),
                          validator: (value) =>
                              value == null ? 'Selecione uma categoria.' : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _saving ? null : _addCategory,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nova categoria'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 18),
              Row(
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
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _observation,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_editing ? 'Salvar alterações' : 'Salvar $title'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryError extends StatelessWidget {
  const _CategoryError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Não foi possível carregar as categorias: $error'),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}
