import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// Sales Invoice PDF Generate karne ka function
Future<void> generateAndPrintOrShareInvoice({
  required BuildContext context,
  required String invoiceNo,
  required String partyName,
  required DateTime date,
  required List<Map<String, dynamic>> items, // [{ 'name': 'Item 1', 'qty': 2, 'price': 500 }]
  required double grandTotal,
  required String paymentMode,
  required bool isShareOnWhatsApp, // true for WhatsApp share, false for direct print
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORLIFE Mobile Accessories', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Wholesale & Retail Mobile Parts & Accessories', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    pw.Text('Invoice No: $invoiceNo'),
                    pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(date)}'),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.teal),
            pw.SizedBox(height: 10),

            // Customer Details
            pw.Text('Bill To:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Party Name: $partyName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Payment Mode: $paymentMode'),
            pw.SizedBox(height: 15),

            // Items Table
            pw.Table.fromTextArray(
              headers: ['S.No', 'Item Description', 'Qty', 'Price (₹)', 'Total (₹)'],
              data: List.generate(items.length, (index) {
                final item = items[index];
                double total = (item['qty'] ?? 1) * (item['price'] ?? 0.0);
                return [
                  '${index + 1}',
                  item['name'] ?? '',
                  '${item['qty']}',
                  '${item['price']}',
                  '${total.toStringAsFixed(2)}',
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),

            // Grand Total Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal), borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('₹ ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),

            // Footer Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('For ORLIFE Mobile Accessories', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        );
      },
    ),
  );

  if (isShareOnWhatsApp) {
    // Save to temp and share via WhatsApp
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Invoice_$invoiceNo.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Sales Invoice #$invoiceNo from ORLIFE Mobile Accessories. Total: ₹ $grandTotal');
  } else {
    // Direct Print / Preview dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
