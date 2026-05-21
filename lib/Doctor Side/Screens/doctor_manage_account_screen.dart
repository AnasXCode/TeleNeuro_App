import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

const Color _primary = Color(0xFF1565C0);

class DoctorManageAccountScreen extends StatefulWidget {
  const DoctorManageAccountScreen({super.key});

  @override
  State<DoctorManageAccountScreen> createState() =>
      _DoctorManageAccountScreenState();
}

class _DoctorManageAccountScreenState extends State<DoctorManageAccountScreen> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _hospitalC = TextEditingController();
  final _specialityC = TextEditingController();
  final _qualificationsC = TextEditingController();
  final _aboutC = TextEditingController();
  final _feeC = TextEditingController();
  final _scheduleC = TextEditingController();
  final _experienceC = TextEditingController();
  final _currentPassC = TextEditingController();
  final _newPassC = TextEditingController();
  final _confirmPassC = TextEditingController();

  File? _profileImage;
  String? _existingImageUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      final d = doc.data()!;
      _nameC.text = (d['name'] ?? '').toString();
      _phoneC.text = (d['phone'] ?? '').toString();
      _hospitalC.text = (d['hospital'] ?? '').toString();
      _specialityC.text = (d['speciality'] ?? 'General Physician').toString();
      _qualificationsC.text = (d['qualifications'] ?? '').toString();
      _aboutC.text = (d['about'] ?? '').toString();
      _feeC.text = (d['consultationFee'] ?? '').toString();
      _scheduleC.text = (d['availability'] ?? '').toString();
      _experienceC.text =
          (d['experience'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
      _existingImageUrl = d['profileImageUrl']?.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _profileImage = File(x.path));
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);

    try {
      final exp = _experienceC.text.trim();
      final data = <String, dynamic>{
        'name': _nameC.text.trim(),
        'phone': _phoneC.text.trim(),
        'hospital': _hospitalC.text.trim(),
        'speciality': _specialityC.text.trim(),
        'qualifications': _qualificationsC.text.trim(),
        'about': _aboutC.text.trim(),
        'consultationFee': _feeC.text.trim(),
        'availability': _scheduleC.text.trim(),
        'experience': exp.isEmpty ? '0 Years' : '$exp Years',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_profileImage != null) {
        data['profileImagePath'] = _profileImage!.path;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update(data);
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(_nameC.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassC.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New password must be at least 6 characters'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_newPassC.text != _confirmPassC.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassC.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPassC.text);
      _currentPassC.clear();
      _newPassC.clear();
      _confirmPassC.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password changed successfully'),
              backgroundColor: Colors.green),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message ?? 'Could not change password'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _hospitalC.dispose();
    _specialityC.dispose();
    _qualificationsC.dispose();
    _aboutC.dispose();
    _feeC.dispose();
    _scheduleC.dispose();
    _experienceC.dispose();
    _currentPassC.dispose();
    _newPassC.dispose();
    _confirmPassC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text('Manage Account'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: const Color(0xFFE3F2FD),
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_existingImageUrl != null &&
                                _existingImageUrl!.startsWith('http'))
                            ? NetworkImage(_existingImageUrl!)
                            : null,
                    child: _profileImage == null &&
                            (_existingImageUrl == null ||
                                !_existingImageUrl!.startsWith('http'))
                        ? const Icon(Icons.person, size: 60, color: _primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: _primary,
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
              child: Text('Tap to change photo',
                  style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 24),
          _section('Professional Details'),
          _field('Full Name', _nameC),
          _field('Specialization', _specialityC),
          _field('Experience (years)', _experienceC,
              keyboard: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          _field('Qualifications', _qualificationsC, maxLines: 2),
          _field('Hospital / Clinic', _hospitalC),
          _field('Consultation Fee', _feeC,
              hint: 'e.g. \$50 or PKR 2000'),
          _field('Availability Schedule', _scheduleC,
              hint: 'e.g. Mon–Fri 9AM–5PM', maxLines: 2),
          _field('About / Bio', _aboutC, maxLines: 4),
          const SizedBox(height: 16),
          _section('Contact'),
          _field('Phone Number', _phoneC, keyboard: TextInputType.phone),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Profile',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
          _section('Change Password'),
          _field('Current Password', _currentPassC, obscure: true),
          _field('New Password', _newPassC, obscure: true),
          _field('Confirm New Password', _confirmPassC, obscure: true),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _changePassword,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Update Password',
                  style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
    );
  }

  Widget _field(String label, TextEditingController c,
      {bool obscure = false,
      int maxLines = 1,
      String? hint,
      TextInputType? keyboard,
      List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        obscureText: obscure,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _primary, width: 2),
          ),
        ),
      ),
    );
  }
}
