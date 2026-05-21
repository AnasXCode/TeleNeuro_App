import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Auth/doctor_login_page.dart';
import 'doctor_manage_account_screen.dart';
import '../../services/doctor_availability_service.dart';

const Color _primary = Color(0xFF1565C0);

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _load();
  }

  Future<void> _load() async {
    if (_uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _data = doc.data() ?? {};
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _v(String key, {String fallback = 'Not set'}) {
    final val = _data[key];
    if (val == null || val.toString().trim().isEmpty) return fallback;
    return val.toString();
  }

  String get _ratingDisplay {
    final reviews = (_data['totalReviews'] ?? 0) as int;
    if (reviews == 0) return 'New';
    return '${_data['rating'] ?? 0.0} / 5.0 ($reviews reviews)';
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DoctorLoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?',
            style: TextStyle(color: Colors.red)),
        content: const Text(
            'This will permanently remove your profile. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await DoctorAvailabilityService.onDoctorAccountDeleted(
                    user.uid);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .delete();
                await user.delete();
              }
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DoctorLoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final path = _data['profileImagePath']?.toString();
    final url = _data['profileImageUrl']?.toString();
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(radius: 55, backgroundImage: FileImage(File(path)));
    }
    if (url != null && url.startsWith('http')) {
      return CircleAvatar(radius: 55, backgroundImage: NetworkImage(url));
    }
    return const CircleAvatar(
      radius: 55,
      backgroundColor: Color(0xFFE3F2FD),
      child: Icon(Icons.person, size: 60, color: _primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: _primary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Manage Account',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const DoctorManageAccountScreen()),
              );
              if (updated == true) _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    _avatar(),
                    const SizedBox(height: 12),
                    Text('Dr. ${_v('name', fallback: 'Doctor')}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(_v('speciality', fallback: 'General Physician'),
                        style: const TextStyle(
                            color: Color(0xFF78909C), fontSize: 15)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(' $_ratingDisplay',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _infoCard(Icons.email, 'Email', _v('email', fallback: '—')),
              _infoCard(Icons.phone, 'Phone', _v('phone')),
              _infoCard(Icons.local_hospital, 'Hospital / Clinic', _v('hospital')),
              _infoCard(Icons.work, 'Experience', _v('experience', fallback: '0 Years')),
              _infoCard(Icons.school, 'Qualifications', _v('qualifications')),
              _infoCard(Icons.payments, 'Consultation Fee', _v('consultationFee')),
              _infoCard(Icons.schedule, 'Availability', _v('availability')),
              const SizedBox(height: 8),
              const Text('About',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF37474F))),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _v('about', fallback: 'No bio added yet. Tap edit to add your professional summary.'),
                  style: const TextStyle(height: 1.5, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DoctorManageAccountScreen()),
                    );
                    if (updated == true) _load();
                  },
                  icon: const Icon(Icons.settings, color: _primary),
                  label: const Text('Manage Account',
                      style: TextStyle(
                          color: _primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Text('Patient Reviews',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF37474F))),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('appointments')
                    .where('doctorId', isEqualTo: _uid)
                    .where('isRated', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: Text('No reviews yet.',
                              style: TextStyle(color: Colors.grey))),
                    );
                  }
                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final ta = (a.data() as Map)['timestamp'];
                      final tb = (b.data() as Map)['timestamp'];
                      if (ta is! Timestamp) return 1;
                      if (tb is! Timestamp) return -1;
                      return tb.compareTo(ta);
                    });

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final stars = (d['givenRating'] ?? 0).toDouble();
                      final review = (d['reviewText'] ??
                              d['review'] ??
                              d['comment'] ??
                              '')
                          .toString()
                          .trim();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(d['patientName'] ?? 'Patient',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      Text('$stars',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const Icon(Icons.star,
                                          color: Colors.amber, size: 18),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                review.isEmpty
                                    ? 'No written feedback.'
                                    : review,
                                style: TextStyle(
                                  fontStyle: review.isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  height: 1.45,
                                  color: review.isEmpty
                                      ? Colors.grey
                                      : Colors.black87,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _handleLogout(context),
                  style: ElevatedButton.styleFrom(backgroundColor: _primary),
                  child: const Text('Logout',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => _handleDeleteAccount(context),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red)),
                  child: const Text('Delete Account',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: _primary),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }
}
