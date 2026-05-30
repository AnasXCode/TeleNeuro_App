import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class DoctorGuideScreen extends StatelessWidget {
  const DoctorGuideScreen({super.key});

  static const _steps = [
    _GuideStep(Icons.account_circle_outlined, 'Manage your profile', 'Open Profile from the bottom navigation to update experience, view reviews, and manage your account.'),
    _GuideStep(Icons.calendar_month_outlined, 'View appointments', 'Use Schedule to see pending requests and upcoming accepted consultations.'),
    _GuideStep(Icons.check_circle_outline, 'Manage consultations', 'Accept or decline pending requests. Open Messages to chat with patients during active sessions.'),
    _GuideStep(Icons.chat_bubble_outline, 'Send messages', 'Tap a patient conversation to chat. Patients receive notifications for new messages.'),
    _GuideStep(Icons.event_busy_outlined, 'End sessions', 'When a consultation is complete, tap the check icon to mark the session completed. The patient is notified.'),
    _GuideStep(Icons.picture_as_pdf_outlined, 'Review patient reports', 'Patient MRI reports lists scans shared with you. Open PDFs and clinical summaries from the dashboard quick access.'),
    _GuideStep(Icons.delete_outline, 'Report management', 'Remove reports from your list when no longer needed. Patient copies in Lab Reports are not affected.'),
    _GuideStep(Icons.people_outline, 'View patient profiles', 'From Messages or My Patients, tap a patient to view their profile and uploaded photo.'),
    _GuideStep(Icons.notifications_outlined, 'Notifications', 'Use the bell icon on the dashboard for new bookings, messages, and shared MRI reports.'),
    _GuideStep(Icons.settings_outlined, 'Account settings', 'Update experience, log out, or delete your account from the Profile tab when needed.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Doctor guide',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quick reference for managing patients and consultations on TeleNeuro.',
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
