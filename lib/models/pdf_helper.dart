import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class PdfHelper {
  /// Universal function to generate, print, or share invoices/orders/returns
  static Future<void> generateAndPrintOrShare({
    required String title, // e.g., "TAX INVOICE (GST)", "PURCHASE RETURN", "SALES ORDER"
    required String voucherNoKey, // e.g., "Invoice No", "Return No", "Order No"
    required String voucherNoValue,
    required String date,
    required String partyLabel, // e.g., "Bill To", "Supplier Name", "Customer Name"
    required String partyName,
    required List<Map<String, dynamic>> items, // Each item: {'name': '...', 'sku': '...', 'qty': 1, 'price': 100.0}
    required double subTotal,
    required List<Map<String, dynamic>> extraCharges, // Each charge: {'name': '...', 'rate': 50.0}
    required double taxAmount,
    required double grandTotal,
    required bool isGstActive,
    required String companyGstin,
    required double gstRate,
    required bool isShare, // true to share via WhatsApp/Apps, false to print/view PDF
    required PdfColor themeColor, // e.g., Colors.teal, Colors.blue900, Colors.amber900
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ORLIFE Mobile Accessories', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: themeColor)),
                      pw.Text('Wholesale & Retail Mobile Parts & Accessories', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (isGstActive && companyGstin.isNotEmpty)
                        pw.Text('GSTIN: $companyGstin', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: themeColor)),
                      pw.Text('$voucherNoKey: $voucherNoValue', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: themeColor),
              pw.SizedBox(height: 10),

              // Party Details Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$partyLabel:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(partyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Items Table
              pw.Table.fromTextArray(
                headers: ['S.No', 'Item Description & SKU', 'Qty', 'Price (₹)', 'Total (₹)'],
                data: List.generate(items.length, (index) {
                  final item = items[index];
                  double total = (item['qty'] as num) * (item['price'] as num);
                  return [
                    '${index + 1}',
                    '${item['name']} [${item['sku'] ?? "-"}]',
                    '${item['qty']}',
                    '${item['price']}',
                    total.toStringAsFixed(2),
                  ];
                }),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: themeColor),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(70),
                },
              ),
              pw.SizedBox(height: 20),

              // Totals Summary Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: themeColor),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 11)),
                            pw.Text('₹ ${subTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        for (var charge in extraCharges) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('${charge['name']}:', style: const pw.TextStyle(fontSize: 11)),
                              pw.Text('₹ ${(charge['rate']).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ],
                        if (isGstActive) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('GST (${gstRate.toStringAsFixed(1)}%):', style: const TextStyle(fontSize: 11)),
                              pw.Text('₹ ${taxAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ],
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: themeColor)),
                            pw.Text('₹ ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: themeColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (isShare) {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/${voucherNoKey}_$voucherNoValue.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: '$title #$voucherNoValue. Total: ₹ ${grandTotal.toStringAsFixed(2)}');
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
  }
}
