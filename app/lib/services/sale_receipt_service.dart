import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SaleReceiptService {
  static final _money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _date = DateFormat('dd/MM/yyyy');

  static Future<Uint8List> createPdf(Map<String, Object?> receipt) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/pdf_fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/pdf_fonts/Roboto-Bold.ttf'),
    );
    final pdf = pw.Document(
      title: 'Comprovante de venda ${receipt['id']}',
      author: 'Rastreador de Despesas',
    );
    final items = (receipt['itens'] as List<Object?>?) ?? const [];
    final rows = items.isEmpty
        ? [
            {
              'produto_nome': receipt['descricao'] ?? 'Venda',
              'quantidade': '1',
              'valor_unitario': receipt['total'],
              'total': receipt['total'],
            },
          ]
        : items.cast<Map<String, Object?>>();
    final total = _parseMoney(receipt['total']);
    final date = DateTime.tryParse(receipt['data']! as String);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(22),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#087F68'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'COMPROVANTE DE VENDA',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Documento não fiscal',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  '#${receipt['id']}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          pw.Row(
            children: [
              _info('DATA', date == null ? '--' : _date.format(date)),
              pw.SizedBox(width: 34),
              _info('HORÁRIO', (receipt['hora']! as String).substring(0, 5)),
              pw.SizedBox(width: 34),
              _info(
                'PAGAMENTO',
                _paymentLabel(receipt['pagamento'] as String?),
              ),
            ],
          ),
          pw.SizedBox(height: 26),
          pw.Text(
            'PRODUTOS',
            style: pw.TextStyle(
              color: PdfColor.fromHex('#087F68'),
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 9),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300),
              bottom: pw.BorderSide(color: PdfColors.grey400),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.1),
              2: const pw.FlexColumnWidth(1.7),
              3: const pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EFF6F3'),
                ),
                children: [
                  _cell('PRODUTO', header: true),
                  _cell('QTD.', header: true, align: pw.TextAlign.right),
                  _cell('UNITÁRIO', header: true, align: pw.TextAlign.right),
                  _cell('TOTAL', header: true, align: pw.TextAlign.right),
                ],
              ),
              ...rows.map(
                (item) => pw.TableRow(
                  children: [
                    _cell(item['produto_nome'] as String? ?? 'Produto'),
                    _cell(
                      item['quantidade'] as String? ?? '1',
                      align: pw.TextAlign.right,
                    ),
                    _cell(
                      _formatMoney(item['valor_unitario']),
                      align: pw.TextAlign.right,
                    ),
                    _cell(
                      _formatMoney(item['total']),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 235,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EFF6F3'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#17352F'),
                    ),
                  ),
                  pw.Text(
                    _money.format(total),
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#087F68'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if ((receipt['observacao'] as String?)?.isNotEmpty == true) ...[
            pw.SizedBox(height: 22),
            _info('OBSERVAÇÃO', receipt['observacao']! as String),
          ],
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Center(
            child: pw.Text(
              'Comprovante gerado pelo Rastreador de Despesas. '
              'Este documento não substitui nota fiscal.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.Widget _info(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          color: PdfColors.grey700,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
    ],
  );

  static pw.Widget _cell(
    String value, {
    bool header = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: pw.Text(
      value,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: header ? 8 : 10,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: header ? PdfColors.grey700 : PdfColors.grey900,
      ),
    ),
  );

  static double _parseMoney(Object? value) {
    if (value is! String) return 0;
    return double.tryParse(value) ?? 0;
  }

  static String _formatMoney(Object? value) =>
      _money.format(_parseMoney(value));

  static String _paymentLabel(String? method) => switch (method) {
    'dinheiro' => 'Dinheiro',
    'pix' => 'Pix',
    'cartao_debito' => 'Cartão de débito',
    'cartao_credito' => 'Cartão de crédito',
    _ => 'Outro',
  };
}
