import 'dart:io';

import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';
import '../Patient Side/Screens/consult_doctor_screen.dart';
import '../Widgets/profile_avatar.dart';
import '../Widgets/doctor_reviews_section.dart';

const Color _kPrimary = Color(0xFF1565C0);
const Color _kTextDark = Color(0xFF37474F);
const Color _kTextLight = Color(0xFF78909C);

/// Read-only patient profile (for doctors or self).
class PatientProfileViewScreen extends StatefulWidget {
  final String patientId;
  final String? title;

  const PatientProfileViewScreen({
    super.key,
    required this.patientId,
    this.title,
  });

  @override
  State<PatientProfileViewScreen> createState() => _PatientProfileViewScreenState();
}

class _PatientProfileViewScreenState extends State<PatientProfileViewScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await UserProfileService.loadPatientProfile(widget.patientId);
    if (mounted) {
      setState(() {
      _data = data;
      _loading = false;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Patient Profile'),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ProfileAvatar(
                    userId: widget.patientId,
                    photoUrl: _data?['photoUrl'] as String?,
                    localFile: _data?['profileImage'] as File?,
                    radius: 52,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _data?['name']?.toString() ?? 'Patient',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kTextDark),
                  ),
                  Text(
                    _data?['email']?.toString() ?? '',
                    style: const TextStyle(color: _kTextLight),
                  ),
                  const SizedBox(height: 24),
                  _tile(Icons.person_outline, 'Full Name', _data?['name']),
                  _tile(Icons.email_outlined, 'Email', _data?['email']),
                  _tile(Icons.phone_android, 'Phone', _data?['phone']),
                  _tile(Icons.wc_outlined, 'Gender', _data?['gender']),
                  _tile(Icons.calendar_today, 'Date of Birth', _data?['dob']),
                  _tile(Icons.location_on_outlined, 'Address', _data?['address']),
                  _tile(Icons.water_drop_outlined, 'Blood Group', _data?['bloodGroup']),
                  _tile(Icons.phone_in_talk, 'Emergency Contact', _data?['emergency']),
                  _tile(Icons.medical_services_outlined, 'Medical Conditions', _data?['medicalConditions']),
                ],
              ),
            ),
    );
  }
}

/// Read-only doctor profile (for patients).
class DoctorProfileViewScreen extends StatefulWidget {
  final String doctorId;
  final String? title;
  final bool showPatientActions;
  final String? doctorDisplayName;

  const DoctorProfileViewScreen({
    super.key,
    required this.doctorId,
    this.title,
    this.showPatientActions = false,
    this.doctorDisplayName,
  });

  @override
  State<DoctorProfileViewScreen> createState() => _DoctorProfileViewScreenState();
}

class _DoctorProfileViewScreenState extends State<DoctorProfileViewScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await UserProfileService.loadDoctorProfile(widget.doctorId);
    if (mounted) {
      setState(() {
      _data = data;
      _loading = false;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _data?['name']?.toString() ?? 'Doctor';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Dr. $name'),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ProfileAvatar(
                    userId: widget.doctorId,
                    photoUrl: _data?['photoUrl'] as String?,
                    radius: 52,
                    fallbackIcon: Icons.medical_services,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dr. $name',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kTextDark),
                  ),
                  Text(
                    _data?['specialization']?.toString() ?? '',
                    style: const TextStyle(color: _kTextLight, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        _data?['ratingDisplay']?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if ((_data?['totalReviews'] as int? ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${_data!['totalReviews']} reviews)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _tile(Icons.email_outlined, 'Email', _data?['email']),
                  _tile(Icons.phone, 'Phone', _data?['phone']),
                  _tile(Icons.local_hospital_outlined, 'Hospital', _data?['hospital']),
                  _tile(Icons.school_outlined, 'Qualifications', _data?['qualifications']),
                  _tile(Icons.work_outline, 'Experience', _data?['experience']),
                  _tile(Icons.schedule, 'Availability', _data?['availability']),
                  if ((_data?['about']?.toString() ?? '—') != '—') ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kTextDark)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _data!['about'].toString(),
                      style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                  if (widget.showPatientActions) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConsultDoctorPage(
                                    doctorId: widget.doctorId,
                                    doctorName: widget.doctorDisplayName ?? name,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Book Appointment'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  DoctorReviewsSection(
                    doctorId: widget.doctorId,
                    averageRating: _data?['averageRating'] as double?,
                    totalReviews: _data?['totalReviews'] as int? ?? 0,
                  ),
                ],
              ),
            ),
    );
  }
}

Widget _tile(IconData icon, String label, dynamic value) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _kPrimary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: _kTextLight)),
              const SizedBox(height: 4),
              Text(
                value?.toString() ?? '—',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kTextDark),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
