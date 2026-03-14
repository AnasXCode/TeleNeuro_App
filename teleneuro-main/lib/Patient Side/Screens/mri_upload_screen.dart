import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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

  // --- GALLERY SE IMAGE PICK KARNE KA FUNCTION ---
  Future<void> _pickMRI() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedMRI = File(image.path);
        _resultStage = null; // Nayi image par purana result hata do
        _confidenceScore = null;
      });
    }
  }

  // --- DUMMY AI ANALYSIS FUNCTION (Baad mein yahan API call aayegi) ---
  Future<void> _analyzeScan() async {
    if (_selectedMRI == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    // Model ki processing ka wait simulate kar rahe hain (3 seconds)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      // Dummy results jo baad mein API se aayenge
      _resultStage = "Very Mild Demented";
      _confidenceScore = "92.5%";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text(
          "AI MRI Analysis",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Upload Brain MRI Scan",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please upload a clear, top-down MRI scan of the brain from your gallery to detect early signs of Alzheimer's.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // --- IMAGE UPLOAD BOX ---
            GestureDetector(
              onTap: _pickMRI,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedMRI == null
                        ? kPrimaryColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 2,
                    style: _selectedMRI == null
                        ? BorderStyle.solid
                        : BorderStyle.none,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _selectedMRI == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_search_rounded,
                            size: 60,
                            color: kPrimaryColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "Tap to select from Gallery",
                            style: TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          _selectedMRI!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),

            // --- ANALYZE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_selectedMRI == null || _isAnalyzing)
                    ? null
                    : _analyzeScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: _isAnalyzing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(width: 15),
                          Text(
                            "Analyzing with Vision Transformer...",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            "Run AI Analysis",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 30),

            // --- RESULT SECTION (Tabhi dikhega jab result aa jayega) ---
            if (_resultStage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
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
                          style: TextStyle(fontSize: 16, color: Colors.grey),
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
          ],
        ),
      ),
    );
  }
}
