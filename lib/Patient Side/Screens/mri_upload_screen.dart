import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../services/mri_report_service.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

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
  String? _pdfFilePath;
  String? _selectedDoctorId;
  String? _selectedDoctorName;

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
        'assets/vit_fyp_direct.tflite',
      );
      debugPrint("✅ Model loaded successfully");
    } catch (e) {
      debugPrint("❌ Error loading model: $e");
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
        _pdfFilePath = null;
        _selectedDoctorId = null;
        _selectedDoctorName = null;
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
      _selectedDoctorId = null;
      _selectedDoctorName = null;
    });

    // 1. SHOW WAITING DIALOG
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            CircularProgressIndicator(color: kPrimaryColor),
            SizedBox(height: 20),
            Text(
              "Please Wait...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              "AI is deeply analyzing the scan.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final imageBytes = await _selectedMRI!.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) throw Exception("Image decoding failed");

      // Preprocessing exactly matching PyTorch Pipeline
      img.Image resized256 = img.copyResize(originalImage, width: 256, height: 256);
      int offset = (256 - 192) ~/ 2;
      img.Image cropped = img.copyCrop(resized256, x: offset, y: offset, width: 192, height: 192);

      img.Image grayImage = img.grayscale(cropped);
      img.Image finalImage = img.copyResize(grayImage, width: 224, height: 224);

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

          num r = pixel.r;
          num g = pixel.g;
          num b = pixel.b;

          input[0][0][y][x] = ((r / 255.0) - mean[0]) / std[0];
          input[0][1][y][x] = ((g / 255.0) - mean[1]) / std[1];
          input[0][2][y][x] = ((b / 255.0) - mean[2]) / std[2];
        }
      }

      var output = List.generate(1, (i) => List.filled(4, 0.0));
      _interpreter!.run(input, output);

      // Softmax Calculation
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

      debugPrint("🧠 AI MODEL CONFIDENCE: $probs");

      int predictedIndex = 0;
      double maxProb = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > maxProb) {
          maxProb = probs[i];
          predictedIndex = i;
        }
      }

      // CLOSE WAITING DIALOG
      if (mounted) Navigator.pop(context);

      // 2. SECURITY CHECK FOR INVALID IMAGES (Threshold strict at 80%)
      if (maxProb < 0.80) {
        setState(() {
          _isAnalyzing = false;
          _resultStage = null;
          _confidenceScore = null;
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 30),
                  SizedBox(width: 10),
                  Text("Invalid or Unclear Scan", style: TextStyle(color: Colors.red, fontSize: 18)),
                ],
              ),
              content: const Text(
                "The AI is not highly confident about this image (Confidence < 80%). Please upload a clearer, standard axial Brain MRI scan.",
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK, I'll try again", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // IF SUCCESSFUL (>= 80% Confidence)
      setState(() {
        _resultStage = _classes[predictedIndex];
        _confidenceScore = "${(maxProb * 100).toStringAsFixed(2)}%";
        _isAnalyzing = false;
      });

    } catch (e) {
      if (mounted) Navigator.pop(context);

      debugPrint("Inference Error: $e");
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

      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;

      String? firestoreName;
      String? firestoreEmail;
      String firestoreStatus;
      if (user == null) {
        firestoreStatus = 'no-auth';
      } else {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = doc.data();
          if (data == null) {
            firestoreStatus = 'no-doc';
          } else {
            firestoreName = (data['name'] as String?)?.trim();
            firestoreEmail = (data['email'] as String?)?.trim();
            firestoreStatus = 'ok';
          }
        } catch (e) {
          firestoreStatus = 'error: $e';
          debugPrint('Could not load patient profile from Firestore: $e');
        }
      }

      String firstNonEmpty(List<String?> values, String fallback) {
        for (final v in values) {
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
        return fallback;
      }

      final String patientName = firstNonEmpty(
        [firestoreName, prefs.getString('name'), user?.displayName],
        'Patient',
      );
      final String patientEmail = firstNonEmpty(
        [firestoreEmail, prefs.getString('email'), user?.email],
        'Email Not Provided',
      );

      if (patientName != 'Patient') await prefs.setString('name', patientName);
      if (patientEmail != 'Email Not Provided') await prefs.setString('email', patientEmail);

      debugPrint('[PDF] firestore=$firestoreStatus uid=${user?.uid} name="$patientName" email="$patientEmail"');
      if (mounted && (patientName == 'Patient' || patientEmail == 'Email Not Provided')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.orange.shade800,
            content: Text(
              'Profile lookup → $firestoreStatus\nName: $patientName\nEmail: $patientEmail',
            ),
          ),
        );
      }

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

              pw.Text("CLINICAL NOTES & OBSERVATIONS", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 8),
              pw.Paragraph(
                text: clinicalNotes,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 25),

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

      final pdfBytes = Uint8List.fromList(await pdf.save());

      String? libraryDocId;
      String uploadStatus = 'skipped';

      if (user != null) {
        final saveResult = await MriReportService.saveToPatientLibrary(
          patientUid: user.uid,
          patientName: patientName,
          patientEmail: patientEmail,
          reportId: patientID,
          stage: _resultStage!,
          confidence: _confidenceScore!,
          clinicalNotes: clinicalNotes,
          pdfBytes: pdfBytes,
          imageBytes: imageBytes,
          mriSourceFile: _selectedMRI!,
        );
        libraryDocId = saveResult.docId;
        uploadStatus = saveResult.uploadStatus;

        if (_selectedDoctorId != null && _selectedDoctorId!.isNotEmpty && libraryDocId != null) {
          final shareResult = await MriReportService.shareReportWithDoctor(
            libraryDocId: libraryDocId,
            reportData: {
              'patientUid': user.uid,
              'patientName': patientName,
              'patientEmail': patientEmail,
              'reportId': patientID,
              'stage': _resultStage!,
              'confidence': _confidenceScore!,
              'clinicalNotes': clinicalNotes,
              'pdfUrl': saveResult.pdfUrl,
              'imageUrl': saveResult.imageUrl,
              'storage': 'supabase',
            },
            doctorId: _selectedDoctorId!,
            doctorName: _selectedDoctorName ?? 'Doctor',
          );

          if (mounted && !shareResult.ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(shareResult.message), backgroundColor: Colors.orange),
            );
          }
        }

        if (mounted) {
          final uploaded = uploadStatus == 'ok';
          final sharedNow = _selectedDoctorId != null && _selectedDoctorId!.isNotEmpty;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: uploaded ? 4 : 10),
              backgroundColor: uploaded ? Colors.green : Colors.deepOrange,
              content: Text(
                uploaded
                    ? sharedNow
                    ? 'Report saved to Lab Reports and shared with Dr. ${_selectedDoctorName ?? 'Doctor'}.'
                    : 'Report saved to Lab Reports. Share it with a doctor anytime from there.'
                    : 'Report saved to Lab Reports locally; cloud upload failed.\n$uploadStatus',
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.deepOrange,
            duration: Duration(seconds: 6),
            content: Text(
              'PDF saved on this device only.\n'
                  'Sign in to save the report to Lab Reports and share with your doctor.',
            ),
          ),
        );
      }

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/TeleNeuro_Report_$patientID.pdf");
      await file.writeAsBytes(pdfBytes);

      List<String> savedReports = prefs.getStringList('saved_reports') ?? [];
      savedReports.add(file.path);
      await prefs.setStringList('saved_reports', savedReports);

      setState(() {
        _pdfFilePath = file.path;
      });

      try {
        await OpenFile.open(file.path);
      } catch (e) {
        debugPrint('OpenFile failed (PDF still saved): $e');
      }
    } catch (e) {
      debugPrint("PDF Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating report: $e")),
        );
      }
    }
  }

  Widget _buildDoctorSelector() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Text(
          'Sign in to share this report with your doctor.',
          style: TextStyle(color: kTextDark, fontSize: 13),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: MriReportService.appointmentDoctorsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }

        final doctors = MriReportService.doctorsFromAppointments(snapshot.data?.docs ?? []);

        if (doctors.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text(
              'No active appointments found. Book an appointment first to share this report with a doctor.',
              style: TextStyle(color: kTextDark, fontSize: 13),
            ),
          );
        }

        final entries = doctors.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        final selectedId = _selectedDoctorId != null && doctors.containsKey(_selectedDoctorId)
            ? _selectedDoctorId
            : null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kSecondaryColor.withValues(alpha: 0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedId,
              hint: const Text(
                'Optionally share now with a doctor',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              items: entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                  value: e.key,
                  child: Text('Dr. ${e.value}', style: const TextStyle(fontSize: 14)),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedDoctorId = value;
                  _selectedDoctorName = doctors[value];
                });
              },
            ),
          ),
        );
      },
    );
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
                border: Border.all(color: kSecondaryColor.withValues(alpha: 0.5)),
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
                // Screen ki width ke mutabiq perfect square banane ke liye height set ki hai (minus padding)
                height: MediaQuery.of(context).size.width - 40,
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
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _selectedMRI != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.file(_selectedMRI!, fit: BoxFit.cover), // Square box mein cover theek bethega
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
                      "Processing...",
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
                          color: Colors.green.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Share with doctor',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDoctorSelector(),

                  const SizedBox(height: 20),

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

                  if (_pdfFilePath != null) ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_selectedDoctorId == null || _selectedDoctorId!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a doctor before sharing the report.'),
                              ),
                            );
                            return;
                          }
                          final doctorLabel = _selectedDoctorName ?? 'Doctor';
                          await Share.shareXFiles(
                            [XFile(_pdfFilePath!)],
                            text:
                            'Hello Dr. $doctorLabel, please find my TeleNeuro MRI Diagnostic Report attached for our consultation.',
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
                          backgroundColor: Colors.blue,
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