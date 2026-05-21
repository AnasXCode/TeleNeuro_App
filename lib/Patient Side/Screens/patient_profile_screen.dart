import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class ProfileDisplayPage extends StatefulWidget {
  const ProfileDisplayPage({super.key});
  @override
  State<ProfileDisplayPage> createState() => _ProfileDisplayPageState();
}

class _ProfileDisplayPageState extends State<ProfileDisplayPage> {
  Map<String, dynamic> _data = {};
  File? profileImage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    String? path = prefs.getString('imagePath');
    if (path != null && File(path).existsSync()) {
      profileImage = File(path);
    }

    if (uid != null) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) _data = doc.data() ?? {};
    }

    if (_data.isEmpty) {
      _data = {
        'name': prefs.getString('name') ?? 'Patient',
        'email': prefs.getString('email') ?? '',
        'phone': prefs.getString('phone') ?? '',
        'dob': prefs.getString('dob') ?? '',
        'gender': prefs.getString('gender') ?? '',
        'address': prefs.getString('address') ?? '',
        'bloodGroup': prefs.getString('bloodGroup') ?? '',
        'emergency': prefs.getString('emergency') ?? '',
        'conditions': prefs.getString('conditions') ?? '',
      };
    }

    if (mounted) setState(() => _loading = false);
  }

  String _v(String k) => (_data[k] ?? '—').toString();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientProfilePage()),
              );
              _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundImage:
                    profileImage != null ? FileImage(profileImage!) : null,
                backgroundColor: kAccentColor,
                child: profileImage == null
                    ? const Icon(Icons.person, size: 60, color: kPrimaryColor)
                    : null,
              ),
              const SizedBox(height: 15),
              Text(_v('name'),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTextDark)),
              Text(_v('email'), style: const TextStyle(color: kTextLight)),
              const SizedBox(height: 30),
              _infoTile(Icons.calendar_today, 'Date of Birth', _v('dob')),
              _infoTile(Icons.person_outline, 'Gender', _v('gender')),
              _infoTile(Icons.water_drop, 'Blood Group', _v('bloodGroup')),
              _infoTile(Icons.phone_android, 'Phone', _v('phone')),
              _infoTile(Icons.phone_in_talk, 'Emergency Contact', _v('emergency')),
              _infoTile(Icons.location_on, 'Address', _v('address')),
              _infoTile(
                  Icons.medical_services, 'Medical Conditions', _v('conditions')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PatientProfilePage()),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.settings, color: kPrimaryColor),
                  label: const Text('Manage Account',
                      style: TextStyle(
                          color: kPrimaryColor, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 12, color: kTextLight)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kTextDark)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});
  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final nameC = TextEditingController();
  final dobC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final addressC = TextEditingController();
  final emergencyC = TextEditingController();
  final condC = TextEditingController();
  final currentPassC = TextEditingController();
  final newPassC = TextEditingController();
  final confirmPassC = TextEditingController();

  String bloodGroup = 'B+';
  String gender = 'Male';
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Map<String, dynamic> data = {};

    if (uid != null) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) data = doc.data() ?? {};
    }

    nameC.text = data['name'] ?? prefs.getString('name') ?? '';
    dobC.text = data['dob'] ?? prefs.getString('dob') ?? '';
    phoneC.text = data['phone'] ?? prefs.getString('phone') ?? '';
    emailC.text = data['email'] ??
        prefs.getString('email') ??
        FirebaseAuth.instance.currentUser?.email ??
        '';
    addressC.text = data['address'] ?? prefs.getString('address') ?? '';
    emergencyC.text = data['emergency'] ?? prefs.getString('emergency') ?? '';
    condC.text =
        data['conditions'] ?? prefs.getString('conditions') ?? '';
    gender = data['gender'] ?? prefs.getString('gender') ?? 'Male';
    bloodGroup =
        data['bloodGroup'] ?? prefs.getString('bloodGroup') ?? 'B+';
    final path = prefs.getString('imagePath');
    if (path != null && File(path).existsSync()) {
      _profileImage = File(path);
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveData() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid;

      await prefs.setString('name', nameC.text);
      await prefs.setString('dob', dobC.text);
      await prefs.setString('phone', phoneC.text);
      await prefs.setString('email', emailC.text);
      await prefs.setString('address', addressC.text);
      await prefs.setString('emergency', emergencyC.text);
      await prefs.setString('conditions', condC.text);
      await prefs.setString('gender', gender);
      await prefs.setString('bloodGroup', bloodGroup);
      if (_profileImage != null) {
        await prefs.setString('imagePath', _profileImage!.path);
      }

      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': nameC.text.trim(),
          'email': emailC.text.trim(),
          'phone': phoneC.text.trim(),
          'dob': dobC.text.trim(),
          'address': addressC.text.trim(),
          'emergency': emergencyC.text.trim(),
          'conditions': condC.text.trim(),
          'gender': gender,
          'bloodGroup': bloodGroup,
          if (_profileImage != null) 'profileImagePath': _profileImage!.path,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await FirebaseAuth.instance.currentUser
            ?.updateDisplayName(nameC.text.trim());
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Account updated successfully'),
            backgroundColor: Colors.green),
      );
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
    if (newPassC.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (newPassC.text != confirmPassC.text) {
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
        password: currentPassC.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassC.text);
      currentPassC.clear();
      newPassC.clear();
      confirmPassC.clear();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Account'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final i = await _picker.pickImage(source: ImageSource.gallery);
                if (i != null) setState(() => _profileImage = File(i.path));
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    backgroundColor: Colors.grey[300],
                    child: _profileImage == null
                        ? const Icon(Icons.camera_alt, color: Colors.grey)
                        : null,
                  ),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: kPrimaryColor,
                      child: Icon(Icons.edit, size: 14, color: Colors.white),
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
          const Text('Personal Details',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
          const SizedBox(height: 12),
          _buildEditField('Full Name', nameC),
          _buildEditField('Email Address', emailC),
          _buildEditField('Phone Number', phoneC),
          _buildEditField('Date of Birth', dobC),
          _buildEditField('Address', addressC),
          _buildEditField('Emergency Contact', emergencyC),
          const SizedBox(height: 8),
          const Text('Medical Information',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
          const SizedBox(height: 12),
          _buildEditField('Medical Conditions', condC),
          const SizedBox(height: 16),
          const Text('Change Password',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
          const SizedBox(height: 12),
          _buildEditField('Current Password', currentPassC, obscure: true),
          _buildEditField('New Password', newPassC, obscure: true),
          _buildEditField('Confirm Password', confirmPassC, obscure: true),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _changePassword,
            child: const Text('Update Password'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveData,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextLight),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kPrimaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameC.dispose();
    dobC.dispose();
    phoneC.dispose();
    emailC.dispose();
    addressC.dispose();
    emergencyC.dispose();
    condC.dispose();
    currentPassC.dispose();
    newPassC.dispose();
    confirmPassC.dispose();
    super.dispose();
  }
}
