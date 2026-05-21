import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../supabase_config.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/share_report_dialog.dart';
import '../../services/lab_report_pdf_service.dart';
import 'package:storage_client/storage_client.dart' show FileOptions, StorageException;

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
  bool _isGeneratingPdf = false;
  String? _resultStage;
  String? _confidenceScore;
  String? _pdfFilePath;
  String? _currentReportDocId; // ✅ Naya variable: Taake current report ko share kiya ja sake

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
      print("✅ Model loaded successfully");
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
        _pdfFilePath = null;
        _currentReportDocId = null;
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
      _currentReportDocId = null;
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

      // IF SUCCESSFUL
      setState(() {
        _resultStage = _classes[predictedIndex];
        _confidenceScore = "${(maxProb * 100).toStringAsFixed(2)}%";
        _isAnalyzing = false;
      });

      await _autoSaveScanToLabReports();

    } catch (e) {
      if (mounted) Navigator.pop(context);

      print("Inference Error: $e");
      setState(() {
        _isAnalyzing = false;
        _resultStage = "Error processing scan";
        _confidenceScore = "0%";
      });
    }
  }

  Future<({
    String patientName,
    String patientEmail,
    String reportId,
  })> _resolvePatientContext({String? existingReportId}) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    String? firestoreName;
    String? firestoreEmail;

    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          firestoreName = (data['name'] as String?)?.trim();
          firestoreEmail = (data['email'] as String?)?.trim();
        }
      } catch (_) {}
    }

    String firstNonEmpty(List<String?> values, String fallback) {
      for (final v in values) {
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return fallback;
    }

    final patientName = firstNonEmpty(
        [firestoreName, prefs.getString('name'), user?.displayName], 'Patient');
    final patientEmail = firstNonEmpty(
        [firestoreEmail, prefs.getString('email'), user?.email],
        'Email Not Provided');

    if (patientName != 'Patient') await prefs.setString('name', patientName);
    if (patientEmail != 'Email Not Provided') {
      await prefs.setString('email', patientEmail);
    }

    var reportId =
        'TN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    if (_currentReportDocId != null) {
      final existing = await FirebaseFirestore.instance
          .collection('mri_reports')
          .doc(_currentReportDocId!)
          .get();
      if (existing.exists) {
        reportId = (existing.data()?['reportId'] ?? reportId).toString();
      }
    } else if (existingReportId != null && existingReportId.isNotEmpty) {
      reportId = existingReportId;
    }

    return (
      patientName: patientName,
      patientEmail: patientEmail,
      reportId: reportId,
    );
  }

  Future<String?> _buildSaveAndPublishPdf({
    required String reportId,
    required String patientName,
    required String patientEmail,
    required Uint8List imageBytes,
    String? updateDocId,
  }) async {
    if (_resultStage == null || _confidenceScore == null) return null;

    setState(() => _isGeneratingPdf = true);
    try {
      final clinicalNotes =
          LabReportPdfService.clinicalDescriptionForStage(_resultStage!);
      final pdfBytes = await LabReportPdfService.generateReportPdf(
        reportId: reportId,
        patientName: patientName,
        patientEmail: patientEmail,
        stage: _resultStage!,
        confidence: _confidenceScore!,
        clinicalNotes: clinicalNotes,
        mriImageBytes: imageBytes,
      );

      final localPath = await LabReportPdfService.savePdfToDocuments(
        reportId: reportId,
        pdfBytes: pdfBytes,
      );

      final docId = await _publishMriReportToFirebase(
        reportId: reportId,
        patientName: patientName,
        patientEmail: patientEmail,
        stage: _resultStage!,
        confidence: _confidenceScore!,
        clinicalNotes: clinicalNotes,
        pdfBytes: pdfBytes,
        localPdfPath: localPath,
        imageBytes: imageBytes,
        mriSourceFile: _selectedMRI!,
        updateDocId: updateDocId,
      );

      if (mounted) {
        setState(() {
          _pdfFilePath = localPath;
          _currentReportDocId = docId ?? _currentReportDocId;
        });
      }
      return localPath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _generateAndDownloadPDF() async {
    if (_resultStage == null || _selectedMRI == null || _isGeneratingPdf) {
      return;
    }

    try {
      final imageBytes = await _selectedMRI!.readAsBytes();
      final ctx = await _resolvePatientContext();
      final localPath = await _buildSaveAndPublishPdf(
        reportId: ctx.reportId,
        patientName: ctx.patientName,
        patientEmail: ctx.patientEmail,
        imageBytes: imageBytes,
        updateDocId: _currentReportDocId,
      );

      if (localPath == null) return;

      try {
        await LabReportPdfService.openPdf(localPath);
      } catch (e) {
        debugPrint('OpenFilex failed (PDF still saved): $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'PDF report ready. Use Share PDF to send it anywhere.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  ({String ext, String mime}) _mriStorageFormat(File mriFile) {
    final lower = mriFile.path.toLowerCase();
    if (lower.endsWith('.png')) return (ext: 'png', mime: 'image/png');
    if (lower.endsWith('.webp')) return (ext: 'webp', mime: 'image/webp');
    return (ext: 'jpg', mime: 'image/jpeg');
  }

  /// Saves scan + PDF to Lab Reports immediately after AI analysis.
  Future<void> _autoSaveScanToLabReports() async {
    if (_selectedMRI == null ||
        _resultStage == null ||
        _confidenceScore == null ||
        _currentReportDocId != null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final imageBytes = await _selectedMRI!.readAsBytes();
      final ctx = await _resolvePatientContext();
      final localPath = await _buildSaveAndPublishPdf(
        reportId: ctx.reportId,
        patientName: ctx.patientName,
        patientEmail: ctx.patientEmail,
        imageBytes: imageBytes,
        updateDocId: null,
      );

      if (localPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Lab report and PDF saved. Open it from My Lab Reports.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Auto-save scan failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved but PDF failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<String?> _publishMriReportToFirebase({
    required String reportId,
    required String patientName,
    required String patientEmail,
    required String stage,
    required String confidence,
    required String clinicalNotes,
    Uint8List? pdfBytes,
    String? localPdfPath,
    required Uint8List imageBytes,
    required File mriSourceFile,
    String? updateDocId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    String? pdfUrl;
    String? imageUrl;

    try {
      final fmt = _mriStorageFormat(mriSourceFile);
      final storage = Supabase.instance.client.storage.from(SupabaseConfig.supabaseBucket);
      final imagePath = '${user.uid}/$reportId.${fmt.ext}';
      final pdfPath = '${user.uid}/$reportId.pdf';

      await storage.uploadBinary(imagePath, imageBytes, fileOptions: FileOptions(contentType: fmt.mime, upsert: true));
      imageUrl = storage.getPublicUrl(imagePath);

      if (pdfBytes != null) {
        await storage.uploadBinary(pdfPath, pdfBytes, fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
        pdfUrl = storage.getPublicUrl(pdfPath);
      }
    } catch (e) {
      debugPrint('Supabase upload failed: $e');
    }

    try {
      final payload = {
        'patientUid': user.uid,
        'patientName': patientName,
        'patientEmail': patientEmail,
        'reportId': reportId,
        'stage': stage,
        'confidence': confidence,
        'clinicalNotes': clinicalNotes,
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (localPdfPath != null) 'localPdfPath': localPdfPath,
        'storage': 'supabase',
        'pdfReady': pdfBytes != null,
        'sharedWith': <String>[],
      };

      final targetId = updateDocId ?? _currentReportDocId;
      if (targetId != null && targetId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('mri_reports')
            .doc(targetId)
            .set({
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted && pdfBytes != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 4),
              backgroundColor: Colors.green,
              content: Text('PDF added to your Lab Report.'),
            ),
          );
        }
        return targetId;
      }

      final docRef = await FirebaseFirestore.instance.collection('mri_reports').add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted && pdfBytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
            content: Text('Report saved to Lab Reports successfully!'),
          ),
        );
      }
      return docRef.id;
    } catch (e) {
      debugPrint('Firestore sync failed: $e');
      return null;
    }
  }

  Future<void> _sharePdfExternally() async {
    if (_pdfFilePath == null || !File(_pdfFilePath!).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generate the PDF report first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      await Share.shareXFiles(
        [XFile(_pdfFilePath!)],
        subject: 'TeleNeuro MRI Diagnostic Report',
        text: 'My TeleNeuro AI diagnostic report (${_resultStage ?? 'MRI'})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open share sheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        title: const Text("Upload MRI Scan", style: TextStyle(color: Colors.white)),
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
                height: MediaQuery.of(context).size.width - 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: _selectedMRI != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(_selectedMRI!, fit: BoxFit.cover))
                    : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text("Tap to select MRI image", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _selectedMRI != null && !_isAnalyzing ? _analyzeScan : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: _isAnalyzing
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 15),
                    Text("Processing...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                )
                    : const Text("Analyze with AI", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
                        const SizedBox(height: 10),
                        const Text("Analysis Complete", style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 5),
                        Text(_resultStage!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextDark)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("AI Confidence: ", style: TextStyle(fontSize: 16, color: Colors.grey)),
                            Text(_confidenceScore!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _generateAndDownloadPDF,
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: Text(
                        _isGeneratingPdf
                            ? 'Generating PDF...'
                            : (_pdfFilePath != null
                                ? 'Regenerate & Open PDF'
                                : 'Download PDF Report'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 5),
                    ),
                  ),
                  if (_pdfFilePath != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await LabReportPdfService.openPdf(_pdfFilePath!);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not open PDF: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new, color: kPrimaryColor),
                        label: const Text(
                          'Open PDF',
                          style: TextStyle(
                              color: kPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kPrimaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],

                  if (_pdfFilePath != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _sharePdfExternally,
                        icon: const Icon(Icons.ios_share, color: kPrimaryColor),
                        label: const Text(
                          'Share PDF',
                          style: TextStyle(
                              color: kPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kPrimaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],

                  if (_pdfFilePath != null && _currentReportDocId != null) ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        // Yahan ab hum Apna internal Share Dialog call kar rahe hain
                        onPressed: () => showShareReportDialog(
                          context,
                          reportDocId: _currentReportDocId!,
                          reportTitle: _resultStage ?? 'MRI Report',
                        ),
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text("Share Report to Doctor", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5),
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