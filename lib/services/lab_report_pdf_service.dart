import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds, saves, and opens TeleNeuro medical lab report PDFs.
class LabReportPdfService {
  static String clinicalDescriptionForStage(String stage) {
    switch (stage) {
      case 'Non Demented':
        return 'Clinical Evaluation: The AI analysis of the provided axial MRI scan reveals no significant structural anomalies indicative of Alzheimer\'s disease or related dementias. Cortical thickness, ventricular volume, and hippocampal structures appear to be within expected limits for a healthy cognitive profile. No immediate pathological markers were detected.';
      case 'Very Mild Demented':
        return 'Clinical Evaluation: The radiological assessment indicates subtle, early-stage structural variations. These may include incipient volumetric changes in the hippocampus or mild cortical thinning. Such features are frequently correlated with Very Mild Cognitive Impairment (MCI). Baseline cognitive testing and longitudinal clinical monitoring are recommended.';
      case 'Mild Demented':
        return 'Clinical Evaluation: The analysis highlights mild but distinct cortical atrophy alongside early signs of ventricular enlargement. These structural markers are highly consistent with Mild Dementia/Alzheimer\'s progression. A comprehensive neurological evaluation and clinical correlation are strongly advised to establish a patient care plan.';
      case 'Moderate Demented':
        return 'Clinical Evaluation: The scan reveals pronounced cerebral atrophy, significant ventricular expansion, and notable hippocampal volume loss. These prominent radiological features are highly characteristic of Moderate Dementia. Immediate consultation with a specialized neurologist is recommended for advanced disease management and intervention.';
      default:
        return 'Diagnostic analysis complete. Please consult a specialized physician for detailed clinical correlation and review.';
    }
  }

  /// Professional A4 medical report layout.
  static Future<Uint8List> generateReportPdf({
    required String reportId,
    required String patientName,
    required String patientEmail,
    required String stage,
    required String confidence,
    required String clinicalNotes,
    Uint8List? mriImageBytes,
    String? doctorNotes,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final reportDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final reportTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    pw.Widget? scanImage;
    if (mriImageBytes != null && mriImageBytes.isNotEmpty) {
      scanImage = pw.Image(
        pw.MemoryImage(mriImageBytes),
        width: 200,
        height: 200,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TeleNeuro',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'Medical Lab Report',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.Text(
                      'AI Neurological Diagnostic System',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Report ID: $reportId',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Date: $reportDate'),
                    pw.Text('Time: $reportTime'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 15),
            pw.Text(
              'PATIENT DEMOGRAPHICS',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Patient Name:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(patientName),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Account Email:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(patientEmail),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 25),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MRI / PATHOLOGY FINDINGS',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Detected Neurological Stage:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        stage,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Model Confidence Level:',
                        style: pw.TextStyle(fontSize: 14),
                      ),
                      pw.Text(
                        confidence,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'CLINICAL NOTES & OBSERVATIONS',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Paragraph(
              text: clinicalNotes,
              style: pw.TextStyle(fontSize: 11, lineSpacing: 2),
              textAlign: pw.TextAlign.justify,
            ),
            if (doctorNotes != null && doctorNotes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'DOCTOR NOTES',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Paragraph(
                text: doctorNotes.trim(),
                style: pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
            ],
            if (scanImage != null) ...[
              pw.SizedBox(height: 25),
              pw.Center(
                child: pw.Text(
                  'PROVIDED MRI SCAN (AXIAL VIEW)',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500, width: 2),
                  ),
                  child: scanImage,
                ),
              ),
            ],
            pw.SizedBox(height: 40),
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              "Examining Physician's Remarks / Signature:",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 40),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'DISCLAIMER: This diagnostic report is algorithmically generated by the TeleNeuro Vision Transformer (ViT) AI model. It is designed to act as a Clinical Decision Support System (CDSS) and does not replace professional medical advice, diagnosis, or treatment.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  /// Saves PDF under the app documents directory as `{reportId}.pdf`.
  static Future<String> savePdfToDocuments({
    required String reportId,
    required Uint8List pdfBytes,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/lab_reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final safeId = reportId.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final file = File('${reportsDir.path}/$safeId.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file.path;
  }

  static Future<void> openPdf(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  static Future<Uint8List?> downloadBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close();
      return bytes;
    } catch (e) {
      debugPrint('Download failed ($url): $e');
      return null;
    }
  }

  /// Returns a local path to an existing or newly saved PDF.
  static Future<String?> resolveLocalPdfPath({
    required String reportId,
    String? existingLocalPath,
    String? remotePdfUrl,
    required Future<Uint8List> Function() buildPdf,
  }) async {
    if (existingLocalPath != null &&
        existingLocalPath.isNotEmpty &&
        File(existingLocalPath).existsSync()) {
      return existingLocalPath;
    }

    if (remotePdfUrl != null && remotePdfUrl.isNotEmpty) {
      final remoteBytes = await downloadBytes(remotePdfUrl);
      if (remoteBytes != null) {
        return savePdfToDocuments(reportId: reportId, pdfBytes: remoteBytes);
      }
    }

    try {
      final bytes = await buildPdf();
      return savePdfToDocuments(reportId: reportId, pdfBytes: bytes);
    } catch (e) {
      debugPrint('PDF build failed: $e');
      return null;
    }
  }
}
