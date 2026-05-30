import 'package:flutter/material.dart';

import 'patient_guide_screen.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientGuideScreen();
  }
}