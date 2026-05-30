import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color kPrimaryColor = Color(0xFF1565C0);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
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
    final doctorName = (data['doctorName'] ?? '').toString();
    final ca = data['createdAt'];
    String when = '';
    if (ca is Timestamp) {
      final d = ca.toDate();
      when = '${d.day}/${d.month}/${d.year}';
    }
    final parts = [
      if (doctorName.isNotEmpty) 'Dr. $doctorName',
      stage,
      conf,
      when,
    ].where((s) => s.isNotEmpty);
    return parts.join(' • ');
  }

  int _compareReports(QueryDocumentSnapshot<Map<String, dynamic>> a, QueryDocumentSnapshot<Map<String, dynamic>> b) {
    final ta = a.data()['createdAt'];
    final tb = b.data()['createdAt'];
    if (ta is! Timestamp) return 1;
    if (tb is! Timestamp) return -1;
    return tb.compareTo(ta);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to see your reports'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('mri_reports').where('patientUid', isEqualTo: uid).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs.toList() ?? [];
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
                    final data = docs[i].data();
                    final title = (data['reportId'] ?? 'MRI report').toString();
                    final pdfUrl = (data['pdfUrl'] ?? '').toString();
                    final imageUrl = (data['imageUrl'] ?? '').toString();
                    return ListTile(
                      leading: imageUrl.isEmpty
                          ? const Icon(Icons.cloud_done_outlined, color: Colors.green)
                          : CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
                      title: Text(title),
                      subtitle: Text(_subtitle(data)),
                      trailing: pdfUrl.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                              tooltip: 'Open PDF',
                              onPressed: () => _openLink(pdfUrl),
                            ),
                      onTap: pdfUrl.isEmpty ? null : () => _openLink(pdfUrl),
                    );
                  },
                );
              },
            ),
    );
  }
}
