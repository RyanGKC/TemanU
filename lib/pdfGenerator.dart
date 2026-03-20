import 'dart:io';
import 'dart:typed_data';
import 'package:printing/printing.dart';
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
  // ===========================================================================
  // 1. HEALTH BIOMARKER REPORT GENERATION
  // ===========================================================================
  
  static Future<Uint8List> _buildPdfBytes({
    required List<Map<String, dynamic>> selectedMetrics,
    required Map<String, String> patientData,
    required List<dynamic> activeMedications, // --- NEW PARAMETER ---
  }) async {
    final PdfColor primaryBg = PdfColor.fromHex('#040F31');
    final PdfColor accentCyan = PdfColor.fromHex('#00E5FF');
    final PdfColor cardBg = PdfColor.fromHex('#1A3F6B');

    final ByteData bytes = await rootBundle.load('assets/img/TemanU-logo-transparent.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    pw.Widget buildInfoRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: const pw.TextStyle(color: PdfColors.black, fontSize: 11)),
        ]),
      );
    }

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final italicFont = await PdfGoogleFonts.openSansItalic();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont, italic: italicFont),
    );

    pdf.addPage(
      // --- UPDATED: MultiPage allows it to safely flow onto a second page if needed! ---
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logoImage, width: 60, height: 60),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("COMPREHENSIVE HEALTH REPORT", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryBg)),
                    pw.SizedBox(height: 4),
                    pw.Text("Generated: ${DateTime.now().toString().split(' ')[0]}", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
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
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("PATIENT INFORMATION", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: cardBg)),
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

            // DATA TABLE 1: BIOMARKERS
            if (selectedMetrics.isNotEmpty) ...[
              pw.Text("Recent Metrics Overview", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryBg)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Biomarker', 'Value', 'Unit'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: cardBg),
                cellHeight: 40,
                cellStyle: const pw.TextStyle(fontSize: 12),
                cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center},
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                data: selectedMetrics.map((m) => [m['title'], m['value'], m['unit']]).toList(),
              ),
              pw.SizedBox(height: 30),
            ],

            // --- THE NEW FIX: DATA TABLE 2: MEDICATIONS ---
            if (activeMedications.isNotEmpty) ...[
              pw.Text("Active Prescriptions & Adherence", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryBg)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Medication', 'Dosage', 'Schedule', 'Amount Left', 'Adherence'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: cardBg),
                cellHeight: 40,
                cellStyle: const pw.TextStyle(fontSize: 12),
                cellAlignments: {
                  0: pw.Alignment.centerLeft, 
                  1: pw.Alignment.centerLeft, 
                  2: pw.Alignment.centerLeft, 
                  3: pw.Alignment.center, 
                  4: pw.Alignment.center
                },
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                data: activeMedications.map((med) {
                  int score = med['adherence_score'] ?? 100;
                  return [
                    med['name'],
                    "${med['dosage']} ${med['unit']}",
                    (med['times'] as List).join(', '),
                    "${med['inventory']} ${med['unit']}",
                    "$score%",
                  ];
                }).toList(),
              ),
            ],
            // --------------------------------------------------

            pw.SizedBox(height: 40),

            // FOOTER
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 5),
            pw.Center(
              child: pw.Text(
                "Generated securely via Temanu Health App",
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // --- Update the share/save functions to accept the new parameter ---
  static Future<void> generateAndShare({
    required List<Map<String, dynamic>> selectedMetrics,
    required Map<String, String> patientData,
    required List<dynamic> activeMedications, // <-- NEW
  }) async {
    final Uint8List pdfBytes = await _buildPdfBytes(selectedMetrics: selectedMetrics, patientData: patientData, activeMedications: activeMedications);
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Comprehensive_Health_Report.pdf");
    await file.create(recursive: true);
    await file.writeAsBytes(pdfBytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  static Future<void> generateAndSave({
    required List<Map<String, dynamic>> selectedMetrics,
    required Map<String, String> patientData,
    required List<dynamic> activeMedications, // <-- NEW
    required BuildContext context,
  }) async {
    final Uint8List pdfBytes = await _buildPdfBytes(selectedMetrics: selectedMetrics, patientData: patientData, activeMedications: activeMedications);

    if (kIsWeb) {
      await FileSaver.instance.saveFile(name: 'Comprehensive_Health_Report', bytes: pdfBytes, ext: 'pdf', mimeType: MimeType.pdf);
    } else {
      final String? outputPath = await FilePicker.platform.saveFile(dialogTitle: 'Save Health Report', fileName: 'Comprehensive_Health_Report.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
      if (outputPath != null) {
        await File(outputPath).writeAsBytes(pdfBytes);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved successfully!')));
      }
    }
  }


  // ===========================================================================
  // 2. MEDICATION ADHERENCE REPORT GENERATION (NEW)
  // ===========================================================================

  static Future<Uint8List> _buildMedicationPdfBytes({
    required List<dynamic> medications,
    required Map<String, String> patientData,
    required bool includeAdherence, // --- NEW PARAMETER ---
  }) async {
    final PdfColor primaryBg = PdfColor.fromHex('#040F31');
    final PdfColor accentCyan = PdfColor.fromHex('#00E5FF');
    final PdfColor cardBg = PdfColor.fromHex('#1A3F6B');

    final ByteData bytes = await rootBundle.load('assets/img/TemanU-logo-transparent.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    pw.Widget buildInfoRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: const pw.TextStyle(color: PdfColors.black, fontSize: 11)),
        ]),
      );
    }

    PdfColor getAdherenceColor(int score) {
      if (score >= 80) return PdfColors.green700;
      if (score >= 50) return PdfColors.orange700;
      return PdfColors.red700;
    }

    double totalScore = 0;
    for (var med in medications) {
      totalScore += (med['adherence_score'] ?? 100);
    }
    int overallAdherence = medications.isEmpty ? 0 : (totalScore / medications.length).round();

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
                      pw.Text("MEDICATION REPORT", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryBg)),
                      pw.SizedBox(height: 4),
                      pw.Text("Generated: ${DateTime.now().toString().split(' ')[0]}", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Container(height: 3, width: double.infinity, color: accentCyan),
              pw.SizedBox(height: 20),

              // PATIENT INFO BOX & OPTIONAL OVERALL SCORE
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("PATIENT INFORMATION", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: cardBg)),
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
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    buildInfoRow("Gender:", patientData['gender'] ?? ''),
                                    buildInfoRow("Weight:", patientData['weight'] ?? ''),
                                    buildInfoRow("Conditions:", patientData['conditions'] ?? ''),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // --- CONDITIONALLY RENDER OVERALL SCORE ---
                  if (includeAdherence) ...[
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(15),
                        decoration: pw.BoxDecoration(
                          color: getAdherenceColor(overallAdherence).shade(.1),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: getAdherenceColor(overallAdherence)),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text("OVERALL ADHERENCE", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: getAdherenceColor(overallAdherence))),
                            pw.SizedBox(height: 8),
                            pw.Text("$overallAdherence%", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: getAdherenceColor(overallAdherence))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              pw.SizedBox(height: 30),

              pw.Text("Active Prescriptions", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryBg)),
              pw.SizedBox(height: 10),

              // --- CONDITIONALLY RENDER TABLE HEADERS & DATA ---
              pw.TableHelper.fromTextArray(
                headers: includeAdherence 
                    ? ['Medication', 'Dosage', 'Schedule', 'Adherence'] 
                    : ['Medication', 'Dosage', 'Schedule'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: cardBg),
                cellHeight: 40,
                cellStyle: const pw.TextStyle(fontSize: 12),
                cellAlignments: includeAdherence 
                    ? {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.center}
                    : {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft},
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                data: medications.map((med) {
                  int score = med['adherence_score'] ?? 100;
                  return includeAdherence 
                      ? [med['name'], "${med['dosage']} ${med['unit']}", (med['times'] as List).join(', '), "$score%"]
                      : [med['name'], "${med['dosage']} ${med['unit']}", (med['times'] as List).join(', ')];
                }).toList(),
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 5),
              
              // --- CONDITIONALLY RENDER FOOTNOTE ---
              if (includeAdherence) ...[
                pw.Text(
                  "* Adherence score is calculated based on the user's logged intake versus their prescribed schedule over the last 7 days.",
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 2),
              ],
              
              pw.Center(
                child: pw.Text("Generated securely via Temanu Health App", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  static Future<void> generateAndShareMedicationReport({
    required List<dynamic> medications,
    required Map<String, String> patientData,
    required bool includeAdherence, // --- NEW PARAMETER ---
  }) async {
    if (medications.isEmpty) return;
    final Uint8List pdfBytes = await _buildMedicationPdfBytes(medications: medications, patientData: patientData, includeAdherence: includeAdherence);
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Medication_Report.pdf");
    await file.create(recursive: true);
    await file.writeAsBytes(pdfBytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  static Future<void> generateAndSaveMedicationReport({
    required List<dynamic> medications,
    required Map<String, String> patientData,
    required bool includeAdherence, // --- NEW PARAMETER ---
    required BuildContext context,
  }) async {
    if (medications.isEmpty) return;
    final Uint8List pdfBytes = await _buildMedicationPdfBytes(medications: medications, patientData: patientData, includeAdherence: includeAdherence);

    if (kIsWeb) {
      await FileSaver.instance.saveFile(name: 'Medication_Report', bytes: pdfBytes, ext: 'pdf', mimeType: MimeType.pdf);
    } else {
      final String? outputPath = await FilePicker.platform.saveFile(dialogTitle: 'Save Medication Report', fileName: 'Medication_Report.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
      if (outputPath != null) {
        await File(outputPath).writeAsBytes(pdfBytes);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medication Report saved successfully!')));
      }
    }
  }
}