import 'package:flutter/material.dart';
import '../services/report_share_service.dart';

const Color _primary = Color(0xFF1565C0);

Future<void> showShareReportDialog(
  BuildContext context, {
  required String reportDocId,
  required String reportTitle,
}) async {
  final doctors = await ReportShareService.getBookedDoctors();

  if (!context.mounted) return;

  if (doctors.isEmpty) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No doctors available'),
        content: const Text(
            'You need an accepted or completed appointment with a doctor before sharing reports.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Share with Doctor',
          style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final docId = doctors.keys.elementAt(index);
            final docName = doctors.values.elementAt(index);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.person, color: _primary),
                ),
                title:
                    Text(docName, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.send, color: Colors.green),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ReportShareService.shareReport(
                    context: context,
                    reportDocId: reportDocId,
                    doctorId: docId,
                    doctorName: docName,
                    reportTitle: reportTitle,
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
