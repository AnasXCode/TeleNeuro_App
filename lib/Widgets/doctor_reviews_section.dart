import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color _kPrimary = Color(0xFF1565C0);

/// Public reviews list for a doctor profile (from rated appointments).
class DoctorReviewsSection extends StatelessWidget {
  final String doctorId;
  final double? averageRating;
  final int totalReviews;

  const DoctorReviewsSection({
    super.key,
    required this.doctorId,
    this.averageRating,
    this.totalReviews = 0,
  });

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day}/${d.month}/${d.year}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text(
          'Patient reviews',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      totalReviews == 0
                          ? 'No reviews yet'
                          : '${averageRating?.toStringAsFixed(1) ?? '—'} average',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      totalReviews == 0
                          ? 'Be the first to book and leave feedback'
                          : '$totalReviews review${totalReviews == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('doctorId', isEqualTo: doctorId)
              .where('isRated', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final docs = (snap.data?.docs ?? []).toList()
              ..sort((a, b) {
                final ta = a.data()['completedAt'] ?? a.data()['timestamp'];
                final tb = b.data()['completedAt'] ?? b.data()['timestamp'];
                if (ta is! Timestamp) return 1;
                if (tb is! Timestamp) return -1;
                return tb.compareTo(ta);
              });

            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No written reviews yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final data = docs[i].data();
                final stars = (data['givenRating'] ?? 0).toDouble();
                final feedback = (data['reviewText'] ?? '').toString().trim();
                final patientName = (data['patientName'] ?? 'Patient').toString();
                final date = _formatDate(data['completedAt'] ?? data['timestamp']);

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Row(
                              children: [
                                Text(
                                  stars.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                              ],
                            ),
                          ],
                        ),
                        if (date.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ),
                        if (feedback.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"$feedback"',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade800,
                              height: 1.35,
                              fontSize: 13,
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'No comment provided.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
