import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  final List<Map<String, String>> faqs = const [
    {"q": "How do I book an appointment?", "a": "Navigate to the 'Find Doctor' section, select a specialist, and click 'Book Appointment'."},
    {"q": "How can I upload my MRI scan?", "a": "You can upload scans by going to the 'Lab Reports' section."},
    {"q": "Is my medical data secure?", "a": "Yes, we use end-to-end encryption to ensure your medical records remain private."},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support"), backgroundColor: kPrimaryColor),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              title: Text(faqs[index]['q']!, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
              children: [Padding(padding: const EdgeInsets.all(15), child: Text(faqs[index]['a']!, style: const TextStyle(color: kTextLight)))],
            ),
          );
        },
      ),
    );
  }
}