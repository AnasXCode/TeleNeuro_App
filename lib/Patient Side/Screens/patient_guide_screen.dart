import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class PatientGuideScreen extends StatelessWidget {
  const PatientGuideScreen({super.key});

  static const _steps = [
    _GuideStep(Icons.person_add_outlined, 'Create an account', 'Sign up as a patient with your email and password from the login screen.'),
    _GuideStep(Icons.account_circle_outlined, 'Complete your profile', 'Open My Profile or Manage Account to add your name, phone, date of birth, address, and profile photo.'),
    _GuideStep(Icons.person_search_outlined, 'Search for doctors', 'Use the search bar on the dashboard or tap Find Doctor to browse specialists and ratings.'),
    _GuideStep(Icons.calendar_month_outlined, 'Book appointments', 'Open a doctor profile, tap Book Appointment, choose date, time, and describe your concern.'),
    _GuideStep(Icons.chat_bubble_outline, 'Start consultations', 'After a doctor accepts your request, open Messages and tap a conversation to chat.'),
    _GuideStep(Icons.send_outlined, 'Send messages', 'Type in the chat box and tap send. You will receive notifications for new messages.'),
    _GuideStep(Icons.upload_file_outlined, 'Upload reports', 'Use AI Diagnosis to analyze an MRI scan, or add reports that appear under Lab Reports.'),
    _GuideStep(Icons.folder_open_outlined, 'View reports', 'Lab Reports lists your saved MRI PDFs and analysis summaries.'),
    _GuideStep(Icons.share_outlined, 'Share with doctors', 'From Lab Reports, tap Share and pick a doctor you have an appointment with.'),
    _GuideStep(Icons.memory_outlined, 'How MRI reports work', 'Upload a brain MRI, run AI analysis, download the PDF — it is saved to Lab Reports automatically.'),
    _GuideStep(Icons.notifications_outlined, 'Notifications', 'Tap the bell icon for appointment updates, messages, and shared report alerts.'),
    _GuideStep(Icons.event_note_outlined, 'Manage appointments', 'Schedule tab shows pending, accepted, and completed visits. Rate doctors after completed sessions.'),
    _GuideStep(Icons.edit_outlined, 'Update profile', 'Manage Account lets you edit details and change your profile picture anytime.'),
  ];

  static const _faqs = [
    _FaqItem('How do I book an appointment?', 'Go to Find Doctor or tap a specialist on the dashboard, open their profile, and tap Book Appointment. Fill in date, time, and your problem, then submit.'),
    _FaqItem('How do I contact a doctor?', 'After your appointment is accepted, open Messages from the bottom navigation and tap the doctor conversation to chat.'),
    _FaqItem('How do I upload reports?', 'Use AI Diagnosis from Quick Actions to upload an MRI for analysis. The PDF is saved automatically to Lab Reports.'),
    _FaqItem('How do I share reports?', 'Open Lab Reports, tap the share icon on a report, select a doctor with an active appointment, and confirm.'),
    _FaqItem('How do I delete a report?', 'In Lab Reports, tap the delete icon on a report and confirm. Use Clear history in the top bar to remove all saved reports.'),
    _FaqItem('How do I edit my profile?', 'Tap your profile photo on the home screen or use My Profile / Manage Account from Quick Actions.'),
    _FaqItem('How do notifications work?', 'You receive in-app notifications for bookings, messages, completed sessions, and shared reports. Open the bell icon to read them.'),
    _FaqItem('How do I cancel an appointment?', 'Pending requests can be discussed with your doctor via chat. Completed or declined visits appear in Schedule; use Clear History to tidy old items.'),
    _FaqItem('How do I view consultation history?', 'Open Schedule for all appointments, or Messages for past chat threads including completed sessions.'),
    _FaqItem('How do I update my profile picture?', 'Go to Manage Account, tap your photo, choose an image from your gallery, and save. Doctors can then see your photo on your profile.'),
    _FaqItem('How do I delete my account?', 'Open My Profile, scroll to Delete Account, confirm by typing DELETE, and follow the prompts. This cannot be undone.'),
    _FaqItem('Is my medical data secure?', 'Reports are stored securely. Only you and doctors you explicitly share with can access your shared records.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide & FAQ'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'How to use TeleNeuro',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Follow these steps to get the most from the app.',
            style: TextStyle(color: kTextLight),
          ),
          const SizedBox(height: 16),
          ..._steps.map(
            (step) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                  child: Icon(step.icon, color: kPrimaryColor),
                ),
                title: Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(step.body, style: const TextStyle(color: kTextLight, height: 1.35)),
                ),
                isThreeLine: true,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Frequently asked questions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark),
          ),
          const SizedBox(height: 12),
          ..._faqs.map(
            (faq) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(faq.answer, style: const TextStyle(color: kTextLight, height: 1.4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GuideStep {
  final IconData icon;
  final String title;
  final String body;
  const _GuideStep(this.icon, this.title, this.body);
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}
