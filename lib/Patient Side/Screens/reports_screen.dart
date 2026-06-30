import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/mri_report_service.dart';

const Color kPrimaryColor = Color(0xFF1565C0);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isSharing = false;

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  String _subtitle(Map<String, dynamic> data) {
    final stage = (data['stage'] ?? '').toString();
    final conf = (data['confidence'] ?? '').toString();
    final ca = data['createdAt'];
    String when = '';
    if (ca is Timestamp) {
      final d = ca.toDate();
      when = '${d.day}/${d.month}/${d.year}';
    }
    return [stage, conf, when].where((s) => s.isNotEmpty).join(' • ');
  }

  int _compareReports(QueryDocumentSnapshot<Map<String, dynamic>> a, QueryDocumentSnapshot<Map<String, dynamic>> b) {
    final ta = a.data()['createdAt'];
    final tb = b.data()['createdAt'];
    if (ta is! Timestamp) return 1;
    if (tb is! Timestamp) return -1;
    return tb.compareTo(ta);
  }

  Future<void> _showShareDialog(
    String libraryDocId,
    Map<String, dynamic> reportData,
    String reportTitle,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final appointmentSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .where('status', isEqualTo: 'Accepted')
        .get();

    final doctors = MriReportService.doctorsFromAppointments(appointmentSnap.docs);
    if (!mounted) return;

    if (doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share is available after your doctor accepts the appointment.'),
        ),
      );
      return;
    }

    final entries = doctors.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    String? selectedDoctorId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Share report with doctor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reportTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select doctor',
                  border: OutlineInputBorder(),
                ),
                initialValue: selectedDoctorId,
                items: entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text('Dr. ${e.value}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => selectedDoctorId = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedDoctorId == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedDoctorId == null || !mounted) return;

    setState(() => _isSharing = true);
    try {
      final result = await MriReportService.shareReportWithDoctor(
        libraryDocId: libraryDocId,
        reportData: reportData,
        doctorId: selectedDoctorId!,
        doctorName: doctors[selectedDoctorId!] ?? 'Doctor',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.ok ? (result.alreadyShared ? Colors.blue : Colors.green) : Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _confirmDeleteReport(String documentId, String title) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report?'),
        content: Text(
          'Remove "$title" from your Lab Reports? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final deleted = await MriReportService.deletePatientLibraryReport(
      patientUid: uid,
      documentId: documentId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Report deleted.' : 'Could not delete this report. Please try again.',
        ),
        backgroundColor: deleted ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Lab Reports history?'),
        content: const Text(
          'This permanently removes your saved MRI reports from Lab Reports. '
          'Reports already shared with doctors remain on their side.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final count = await MriReportService.clearPatientLibraryReports(uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_reports');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'Cleared $count report(s) from your history.'
              : 'No reports found to clear.',
        ),
        backgroundColor: count > 0 ? Colors.green : Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
            onPressed: _confirmClearHistory,
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to see your reports'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: MriReportService.appointmentDoctorsStream(uid),
              builder: (context, apptSnap) {
                final canShare = MriReportService
                    .doctorsFromAppointments(apptSnap.data?.docs ?? [])
                    .isNotEmpty;

                return Stack(
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: MriReportService.patientLibraryReportsStream(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = (snap.data?.docs ?? [])
                        .where((doc) => MriReportService.isPatientLibraryReport(doc.data()))
                        .toList();
                    docs.sort(_compareReports);

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No reports yet.\nAfter MRI analysis tap Download PDF — your report will appear here automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (c, i) {
                        final doc = docs[i];
                        final data = doc.data();
                        final title = (data['reportId'] ?? 'MRI report').toString();
                        final pdfUrl = (data['pdfUrl'] ?? '').toString();
                        final imageUrl = (data['imageUrl'] ?? '').toString();

                        return ListTile(
                          leading: imageUrl.isEmpty
                              ? const Icon(Icons.cloud_done_outlined, color: Colors.green)
                              : CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
                          title: Text(title),
                          subtitle: Text(_subtitle(data)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete report',
                                onPressed: _isSharing
                                    ? null
                                    : () => _confirmDeleteReport(doc.id, title),
                              ),
                              if (canShare)
                                IconButton(
                                  icon: const Icon(Icons.share_outlined, color: kPrimaryColor),
                                  tooltip: 'Share with doctor',
                                  onPressed: _isSharing
                                      ? null
                                      : () => _showShareDialog(doc.id, data, title),
                                ),
                              if (pdfUrl.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                  tooltip: 'Open PDF',
                                  onPressed: () => _openLink(pdfUrl),
                                ),
                            ],
                          ),
                          onTap: pdfUrl.isEmpty ? null : () => _openLink(pdfUrl),
                        );
                      },
                    );
                  },
                ),
                if (_isSharing)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
              },
            ),
    );
  }
}
