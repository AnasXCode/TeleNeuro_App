import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'consult_doctor_screen.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

/// Patient-facing doctor profile loaded from Firestore.
class DoctorProfilePage extends StatelessWidget {
  final String doctorId;

  const DoctorProfilePage({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(doctorId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              body: const Center(child: Text('Doctor profile not found')),
            );
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final name = (d['name'] ?? 'Doctor').toString();
          final speciality =
              (d['speciality'] ?? 'General Physician').toString();
          final experience = (d['experience'] ?? '—').toString();
          final hospital = (d['hospital'] ?? '—').toString();
          final qualifications = (d['qualifications'] ?? '—').toString();
          final about = (d['about'] ?? 'No bio available.').toString();
          final availability = (d['availability'] ?? 'Contact for schedule').toString();
          final fee = (d['consultationFee'] ?? '—').toString();
          final phone = (d['phone'] ?? '—').toString();
          final email = (d['email'] ?? '—').toString();
          final reviews = (d['totalReviews'] ?? 0) as int;
          final rating = reviews == 0
              ? 'New'
              : '${d['rating'] ?? 0.0} ⭐ ($reviews reviews)';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: kPrimaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text('Dr. $name',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: _buildAvatar(d),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(speciality,
                          style: const TextStyle(
                              fontSize: 16, color: kTextLight)),
                      const SizedBox(height: 6),
                      Text(rating,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: kPrimaryColor)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              context,
                              Icons.calendar_month,
                              'Book Now',
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConsultDoctorPage(
                                    doctorId: doctorId,
                                    doctorName: name,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionBtn(
                              context,
                              Icons.chat,
                              'Message',
                              () => _openChat(context, doctorId, name),
                              outlined: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _statsRow(experience, hospital, fee),
                      const SizedBox(height: 24),
                      _section('About Doctor', about),
                      _section('Qualifications', qualifications),
                      _section('Availability', availability,
                          valueColor: Colors.green.shade700),
                      _section('Contact',
                          'Phone: $phone\nEmail: $email'),
                      const SizedBox(height: 8),
                      const Text('Patient Reviews',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: kTextDark)),
                      const SizedBox(height: 12),
                      _DoctorReviewsList(doctorId: doctorId),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> d) {
    final path = d['profileImagePath']?.toString();
    final url = d['profileImageUrl']?.toString();
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(radius: 50, backgroundImage: FileImage(File(path)));
    }
    if (url != null && url.startsWith('http')) {
      return CircleAvatar(radius: 50, backgroundImage: NetworkImage(url));
    }
    return const CircleAvatar(
      radius: 50,
      backgroundColor: kAccentColor,
      child: Icon(Icons.person, size: 50, color: kPrimaryColor),
    );
  }

  Future<void> _openChat(
      BuildContext context, String doctorId, String doctorName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'Accepted')
        .limit(1)
        .get();

    if (!context.mounted) return;

    if (snap.docs.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chat unavailable'),
          content: const Text(
              'You need an accepted appointment with this doctor before you can chat. Book an appointment first.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConsultDoctorPage(
                      doctorId: doctorId,
                      doctorName: doctorName,
                    ),
                  ),
                );
              },
              child: const Text('Book Now'),
            ),
          ],
        ),
      );
      return;
    }

    final apt = snap.docs.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: doctorId,
          receiverName: 'Dr. $doctorName',
          appointmentId: apt.id,
        ),
      ),
    );
  }

  Widget _actionBtn(BuildContext context, IconData icon, String label,
      VoidCallback onTap,
      {bool outlined = false}) {
    return Material(
      color: outlined ? Colors.white : kPrimaryColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: outlined
                ? Border.all(color: kPrimaryColor, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: outlined ? kPrimaryColor : Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: outlined ? kPrimaryColor : Colors.white,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow(String exp, String hospital, String fee) {
    return Row(
      children: [
        Expanded(child: _statCard('Experience', exp, Icons.work)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Clinic', hospital, Icons.local_hospital)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Fee', fee, Icons.payments)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: kPrimaryColor, size: 22),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: kTextDark)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: kTextLight)),
        ],
      ),
    );
  }

  Widget _section(String title, String body, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kTextDark)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(body,
                style: TextStyle(
                    height: 1.5,
                    color: valueColor ?? Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}

class _DoctorReviewsList extends StatelessWidget {
  final String doctorId;
  const _DoctorReviewsList({required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('isRated', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No patient reviews yet.',
              style: TextStyle(color: kTextLight),
            ),
          );
        }

        docs.sort((a, b) {
          final ta = (a.data() as Map)['timestamp'];
          final tb = (b.data() as Map)['timestamp'];
          if (ta is! Timestamp) return 1;
          if (tb is! Timestamp) return -1;
          return tb.compareTo(ta);
        });

        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final stars = (d['givenRating'] ?? 0).toDouble();
            final patient = (d['patientName'] ?? 'Patient').toString();
            final review = (d['reviewText'] ?? '').toString().trim();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(patient,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: kTextDark)),
                      Row(
                        children: [
                          Text('$stars',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber)),
                          const Icon(Icons.star,
                              color: Colors.amber, size: 18),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.isEmpty
                        ? 'No written feedback.'
                        : '"$review"',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
