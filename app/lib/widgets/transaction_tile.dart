import 'package:flutter/material.dart';

import '../models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
    this.onReceipt,
  });

  final Movimentacao transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReceipt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = transaction.isSale ? const Color(0xff16815f) : colors.error;
    final detail = transaction.isSale
        ? _paymentLabel(transaction.paymentMethod)
        : transaction.categoryName ?? 'Gasto';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.11),
          foregroundColor: color,
          child: Icon(
            transaction.isSale
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
          ),
        ),
        title: Text(
          transaction.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatBusinessDate(transaction.date)} · ${transaction.time.substring(0, 5)} · $detail',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${transaction.isSale ? '+' : '-'} ${formatMoney(transaction.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções do lançamento',
              onSelected: (value) {
                if (value == 'editar') onEdit();
                if (value == 'excluir') onDelete();
                if (value == 'comprovante') onReceipt?.call();
              },
              itemBuilder: (context) => [
                if (onReceipt != null)
                  const PopupMenuItem(
                    value: 'comprovante',
                    child: Text('Gerar comprovante PDF'),
                  ),
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _paymentLabel(String? method) {
    return switch (method) {
      'dinheiro' => 'Dinheiro',
      'pix' => 'Pix',
      'cartao_debito' => 'Cartão de débito',
      'cartao_credito' => 'Cartão de crédito',
      _ => 'Outro',
    };
  }
}
