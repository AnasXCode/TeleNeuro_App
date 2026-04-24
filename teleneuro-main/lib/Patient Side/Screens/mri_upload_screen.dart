import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart'; // YEH NAYA PACKAGE ADD HUA HAI

// Theme Colors
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kSecondaryColor = Color(0xFF42A5F5);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);

class MRIUploadPage extends StatefulWidget {
  const MRIUploadPage({super.key});

  @override
  State<MRIUploadPage> createState() => _MRIUploadPageState();
}

class _MRIUploadPageState extends State<MRIUploadPage> {
  File? _selectedMRI;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  String? _resultStage;
  String? _confidenceScore;
  String? _pdfFilePath; // YEH NAYA VARIABLE SHARE BUTTON KE LIYE HAI

  Interpreter? _interpreter;
  final List<String> _classes = [
    'Mild Demented',
    'Moderate Demented',
    'Non Demented',
    'Very Mild Demented',
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // --- MODEL LOAD FUNCTION ---
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/vit_fyp_direct.tflite',
      );
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  // --- GALLERY IMAGE PICKER ---
  Future<void> _pickMRI() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedMRI = File(image.path);
        _resultStage = null;
        _confidenceScore = null;
        _pdfFilePath = null; // Naya image aane par purani file ka path hata dein
      });
    }
  }

  // --- AI ANALYSIS FUNCTION ---
  Future<void> _analyzeScan() async {
    if (_selectedMRI == null || _interpreter == null) return;

    setState(() {
      _isAnalyzing = true;
      _resultStage = null;
      _confidenceScore = null;
      _pdfFilePath = null;
    });

    try {
      final imageBytes = await _selectedMRI!.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) throw Exception("Image decode fail ho gayi");

      img.Image resized256 = img.copyResize(
        originalImage,
        width: 256,
        height: 256,
      );
      int offset = (256 - 192) ~/ 2;
      img.Image cropped = img.copyCrop(
        resized256,
        x: offset,
        y: offset,
        width: 192,
        height: 192,
      );
      img.grayscale(cropped);
      img.Image finalImage = img.copyResize(cropped, width: 224, height: 224);

      var input = List.generate(
        1,
            (i) => List.generate(
          3,
              (c) => List.generate(224, (y) => List.filled(224, 0.0)),
        ),
      );

      final mean = [0.485, 0.456, 0.406];
      final std = [0.229, 0.224, 0.225];

      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = finalImage.getPixel(x, y);
          input[0][0][y][x] = ((pixel.r / 255.0) - mean[0]) / std[0];
          input[0][1][y][x] = ((pixel.g / 255.0) - mean[1]) / std[1];
          input[0][2][y][x] = ((pixel.b / 255.0) - mean[2]) / std[2];
        }
      }

      var output = List.generate(1, (i) => List.filled(4, 0.0));
      _interpreter!.run(input, output);

      List<double> logits = output[0];
      double maxLogit = logits.reduce(max);
      double sumExp = 0.0;
      List<double> probs = [];

      for (double logit in logits) {
        double expVal = exp(logit - maxLogit);
        probs.add(expVal);
        sumExp += expVal;
      }
      probs = probs.map((e) => e / sumExp).toList();

      print("🧠 AI MODEL RAW CALCULATION: $probs");

      int predictedIndex = 0;
      double maxProb = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > maxProb) {
          maxProb = probs[i];
          predictedIndex = i;
        }
      }

      if (maxProb < 0.50) {
        setState(() {
          _isAnalyzing = false;
          _resultStage = null;
          _confidenceScore = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Unrecognized image! Please upload a clear Brain MRI scan.",
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() {
        _resultStage = _classes[predictedIndex];
        _confidenceScore = "${(maxProb * 100).toStringAsFixed(2)}%";
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _resultStage = "Error processing scan";
        _confidenceScore = "0%";
      });
    }
  }

  // --- MEDICAL PARAGRAPH GENERATOR ---
  String _getClinicalDescription(String stage) {
    switch (stage) {
      case 'Non Demented':
        return "Clinical Evaluation: The AI analysis of the provided axial MRI scan reveals no significant structural anomalies indicative of Alzheimer's disease or related dementias. Cortical thickness, ventricular volume, and hippocampal structures appear to be within expected limits for a healthy cognitive profile. No immediate pathological markers were detected.";
      case 'Very Mild Demented':
        return "Clinical Evaluation: The radiological assessment indicates subtle, early-stage structural variations. These may include incipient volumetric changes in the hippocampus or mild cortical thinning. Such features are frequently correlated with Very Mild Cognitive Impairment (MCI). Baseline cognitive testing and longitudinal clinical monitoring are recommended.";
      case 'Mild Demented':
        return "Clinical Evaluation: The analysis highlights mild but distinct cortical atrophy alongside early signs of ventricular enlargement. These structural markers are highly consistent with Mild Dementia/Alzheimer's progression. A comprehensive neurological evaluation and clinical correlation are strongly advised to establish a patient care plan.";
      case 'Moderate Demented':
        return "Clinical Evaluation: The scan reveals pronounced cerebral atrophy, significant ventricular expansion, and notable hippocampal volume loss. These prominent radiological features are highly characteristic of Moderate Dementia. Immediate consultation with a specialized neurologist is recommended for advanced disease management and intervention.";
      default:
        return "Diagnostic analysis complete. Please consult a specialized physician for detailed clinical correlation and review.";
    }
  }

  // --- DETAILED PDF REPORT GENERATION FUNCTION ---
  Future<void> _generateAndDownloadPDF() async {
    if (_resultStage == null || _selectedMRI == null) return;

    try {
      final pdf = pw.Document();
      final imageBytes = await _selectedMRI!.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      // ASAL DATA FETCHING FROM LOGIN SESSION
      final prefs = await SharedPreferences.getInstance();
      String patientName = prefs.getString('name') ?? "Name Not Provided";
      String patientEmail = prefs.getString('email') ?? "Email Not Provided";
      String reportDate = DateTime.now().toString().substring(0, 10);
      String reportTime = DateTime.now().toString().substring(11, 16);
      String patientID = "TN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

      String clinicalNotes = _getClinicalDescription(_resultStage!);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // --- Header ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("TeleNeuro", style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text("AI Neurological Diagnostic System", style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Report ID: $patientID", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Date: $reportDate"),
                      pw.Text("Time: $reportTime"),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 15),

              // --- Real Patient Information Table ---
              pw.Text("PATIENT DEMOGRAPHICS", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
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
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Patient Name:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(patientName)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Account Email:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(patientEmail)),
                  ]),
                ],
              ),
              pw.SizedBox(height: 25),

              // --- AI Diagnosis Result ---
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.blue200)
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("AI DIAGNOSTIC SUMMARY", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Detected Neurological Stage:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text(_resultStage!, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Model Confidence Level:", style: const pw.TextStyle(fontSize: 14)),
                        pw.Text(_confidenceScore!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // --- Proper Clinical Paragraph ---
              pw.Text("CLINICAL NOTES & OBSERVATIONS", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 8),
              pw.Paragraph(
                text: clinicalNotes,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 25),

              // --- MRI Scan Image ---
              pw.Center(child: pw.Text("PROVIDED MRI SCAN (AXIAL VIEW)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500, width: 2),
                  ),
                  child: pw.Image(pdfImage, width: 200, height: 200),
                ),
              ),

              pw.SizedBox(height: 40),

              // --- Footer & Disclaimer ---
              pw.Divider(color: PdfColors.grey400),
              pw.Text("Examining Physician's Remarks / Signature:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 40),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "DISCLAIMER: This diagnostic report is algorithmically generated by the TeleNeuro Vision Transformer (ViT) AI model. It is designed to act as a Clinical Decision Support System (CDSS) and does not replace professional medical advice, diagnosis, or treatment. Final clinical decisions must be made by a certified healthcare professional.",
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/TeleNeuro_Report_${patientID}.pdf");
      await file.writeAsBytes(await pdf.save());

      List<String> savedReports = prefs.getStringList('saved_reports') ?? [];
      savedReports.add(file.path);
      await prefs.setStringList('saved_reports', savedReports);

      // 👇 YAHAN PATH SAVE KIYA JAA RAHA HAI SHARE BUTTON KE LIYE 👇
      setState(() {
        _pdfFilePath = file.path;
      });

      await OpenFile.open(file.path);

    } catch (e) {
      print("PDF Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error generating detailed report!")));
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text(
          "Upload MRI Scan",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: kAccentColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kSecondaryColor.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: kPrimaryColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Please upload a clear, top-down view (Axial) MRI scan of the brain for accurate AI diagnosis.",
                      style: TextStyle(color: kTextDark, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            GestureDetector(
              onTap: _pickMRI,
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _selectedMRI != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.file(_selectedMRI!, fit: BoxFit.cover),
                )
                    : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Tap to select MRI image",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _selectedMRI != null && !_isAnalyzing
                    ? _analyzeScan
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: _isAnalyzing
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 15),
                    Text(
                      "AI is processing...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                    : const Text(
                  "Analyze with AI",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            if (_resultStage != null)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 50,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Analysis Complete",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _resultStage!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: kTextDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "AI Confidence: ",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _confidenceScore!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PDF DOWNLOAD BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _generateAndDownloadPDF,
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Download PDF Report",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),

                  // 👇 NAYA SHARE BUTTON 👇
                  if (_pdfFilePath != null) ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Share.shareXFiles(
                            [XFile(_pdfFilePath!)],
                            text: 'Hello Doctor, please find my TeleNeuro MRI Diagnostic Report attached for our consultation.',
                          );
                        },
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text(
                          "Share Report to Doctor",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Share button ka naya color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}