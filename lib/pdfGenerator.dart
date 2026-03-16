import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfGenerator {
  // --- Builds and returns the PDF bytes (shared by both share and save) ---
  static Future<Uint8List> _buildPdfBytes({
    required List<Map<String, dynamic>> selectedMetrics,
    required Map<String, String> patientData,
  }) async {
    final PdfColor primaryBg = PdfColor.fromHex('#040F31');
    final PdfColor accentCyan = PdfColor.fromHex('#00E5FF');
    final PdfColor cardBg = PdfColor.fromHex('#1A3F6B');

    final ByteData bytes =
    await rootBundle.load('assets/img/TemanU-logo-transparent.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    pw.Widget buildInfoRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(children: [
          pw.Text(label,
              style: pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text(value,
              style: const pw.TextStyle(color: PdfColors.black, fontSize: 11)),
        ]),
      );
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logoImage, width: 60, height: 60),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "HEALTH BIOMARKER REPORT",
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryBg),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Generated: ${DateTime.now().toString().split(' ')[0]}",
                        style: pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Container(height: 3, width: double.infinity, color: accentCyan),
              pw.SizedBox(height: 20),

              // PATIENT INFO BOX
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("PATIENT INFORMATION",
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: cardBg)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              buildInfoRow("Name:", patientData['name'] ?? ''),
                              buildInfoRow("DOB:", patientData['dob'] ?? ''),
                              buildInfoRow("Age:", patientData['age'] ?? ''),
                              buildInfoRow("Gender:", patientData['gender'] ?? ''),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              buildInfoRow("Height:", patientData['height'] ?? ''),
                              buildInfoRow("Weight:", patientData['weight'] ?? ''),
                              buildInfoRow("Blood Type:", patientData['bloodType'] ?? ''),
                              buildInfoRow("Conditions:", patientData['conditions'] ?? ''),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // DATA TABLE
              pw.Text(
                "Recent Metrics Overview",
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBg),
              ),
              pw.SizedBox(height: 10),

              pw.TableHelper.fromTextArray(
                headers: ['Biomarker', 'Value', 'Unit'],
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: cardBg),
                cellHeight: 40,
                cellStyle: const pw.TextStyle(fontSize: 12),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                },
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(
                          color: PdfColors.grey300, width: 0.5)),
                ),
                data: selectedMetrics
                    .map((m) => [m['title'], m['value'], m['unit']])
                    .toList(),
              ),

              pw.Spacer(),

              // FOOTER
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  "Generated securely via Temanu Health App",
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey500,
                      fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Generates the PDF and opens the native share sheet.
  static Future<void> generateAndShare({
    required List<Map<String, dynamic>> selectedMetrics,
    required Map<String, String> patientData,
  }) async {
    if (selectedMetrics.isEmpty) return;

    final Uint8List pdfBytes = await _buildPdfBytes(
      selectedMetrics: selectedMetrics,
      patientData: patientData,
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Health_Report.pdf");
    await file.create(recursive: true);
    await file.writeAsBytes(pdfBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
      ),
    );
  }

  /// Generates the PDF and saves it to the user's device.
  static Future<void> generateAndSave({
    required List<Map<String, dynamic>> selectedMetrics,
    required Map<String, String> patientData,
    required BuildContext context,
  }) async {
    if (selectedMetrics.isEmpty) return;

    final Uint8List pdfBytes = await _buildPdfBytes(
      selectedMetrics: selectedMetrics,
      patientData: patientData,
    );

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: 'Health_Report',
        bytes: pdfBytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    } else {
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Health Report',
        fileName: 'Health_Report.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath != null) {
        await File(outputPath).writeAsBytes(pdfBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved successfully!')),
        );
      }
    }
  }
}