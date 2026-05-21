import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color _primary = Color(0xFF1565C0);
const Color _textDark = Color(0xFF37474F);
const Color _textLight = Color(0xFF78909C);

/// Doctor-facing read-only view of a patient's profile.
class PatientProfileViewPage extends StatelessWidget {
  final String patientId;
  final String? fallbackName;

  const PatientProfileViewPage({
    super.key,
    required this.patientId,
    this.fallbackName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Patient Profile'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  fallbackName ?? 'Patient',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final name = (d['name'] ?? fallbackName ?? 'Patient').toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _avatar(d),
                const SizedBox(height: 16),
                Text(name,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _textDark)),
                Text((d['email'] ?? '—').toString(),
                    style: const TextStyle(color: _textLight)),
                const SizedBox(height: 24),
                _infoCard(Icons.calendar_today, 'Date of Birth', d['dob']),
                _infoCard(Icons.person_outline, 'Gender', d['gender']),
                _infoCard(Icons.water_drop, 'Blood Group', d['bloodGroup']),
                _infoCard(Icons.phone_android, 'Phone', d['phone']),
                _infoCard(
                    Icons.phone_in_talk, 'Emergency Contact', d['emergency']),
                _infoCard(Icons.location_on, 'Address', d['address']),
                _infoCard(Icons.medical_services, 'Medical Conditions',
                    d['conditions']),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> d) {
    final path = d['profileImagePath']?.toString();
    final url = d['profileImageUrl']?.toString();
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

  Widget _infoCard(IconData icon, String label, dynamic value) {
    final v = (value ?? '—').toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: _textLight)),
                const SizedBox(height: 4),
                Text(v,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
