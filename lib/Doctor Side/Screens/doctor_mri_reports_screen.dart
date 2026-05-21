import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/report_share_service.dart';

const Color kPrimaryColor = Color(0xFF1565C0);

class DoctorMriReportsScreen extends StatelessWidget {
  const DoctorMriReportsScreen({super.key});

  String _formatTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final d = createdAt.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '—';
  }

  Future<void> _openLink(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link attached to this report')),
      );
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data, String reportDocId) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId != null) {
      ReportShareService.markReportSeen(
        reportDocId: reportDocId,
        doctorId: doctorId,
      );
    }
    final notes = (data['clinicalNotes'] ?? 'No clinical notes synced.').toString();
    final stage = (data['stage'] ?? '—').toString();
    final conf = (data['confidence'] ?? '—').toString();
    final pdfUrl = (data['pdfUrl'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report ${data['reportId'] ?? reportDocId}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl, height: 180, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              Text('Stage: $stage', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Confidence: $conf', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              const Text('Clinical notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              SelectableText(notes),
            ],
          ),
        ),
        actions: [
          if (imageUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openLink(context, imageUrl),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Open MRI'),
            ),
          if (pdfUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openLink(context, pdfUrl),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Open PDF'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text('Patient MRI reports', style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: doctorId == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // ✅ NAYI PRIVACY QUERY: Sirf wo reports fetch karo jo is doctor se share ki gayi hain
        stream: FirebaseFirestore.instance
            .collection('mri_reports')
            .where('sharedWith', arrayContains: doctorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data?.docs ?? [];

          // Reports ko latest k mutabiq sort karna (naye reports upar)
          reports.sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta is! Timestamp) return 1;
            if (tb is! Timestamp) return -1;
            return tb.compareTo(ta); // Descending order
          });

          // Agar kisi patient ne report share nahi ki
          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_shared_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No Shared Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Text(
                      'Patients have not shared any MRI reports with you yet.\nWhen they do, they will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, i) {
              final data = reports[i].data();
              final name = (data['patientName'] ?? 'Patient').toString();
              final stage = (data['stage'] ?? '—').toString();
              final conf = (data['confidence'] ?? '—').toString();
              final reportId = (data['reportId'] ?? reports[i].id).toString();
              final pdfUrl = (data['pdfUrl'] ?? '').toString();
              final imageUrl = (data['imageUrl'] ?? '').toString();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: imageUrl.isEmpty
                      ? const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.medical_information_outlined, color: kPrimaryColor),
                  )
                      : CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stage: $stage', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text('Confidence: $conf'),
                        Text('ID: $reportId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(_formatTime(data['createdAt']), style: const TextStyle(fontSize: 12, color: kPrimaryColor)),
                      ],
                    ),
                  ),
                  isThreeLine: true,
                  trailing: pdfUrl.isEmpty
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFC62828)),
                    tooltip: 'Open PDF',
                    onPressed: () => _openLink(context, pdfUrl),
                  ),
                  onTap: () => _showDetail(context, data, reportId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}