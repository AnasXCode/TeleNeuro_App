import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/user_profile_service.dart';
import '../../services/profile_image_service.dart';
import '../../Widgets/profile_avatar.dart';
import '../../Widgets/account_delete_dialog.dart';
import '../Auth/patient_portal.dart';

// --- THEME COLORS ---
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

// ============================================================
// 1. PROFILE DISPLAY PAGE (Merged View + Logout + Delete)
// ============================================================
class ProfileDisplayPage extends StatefulWidget {
  const ProfileDisplayPage({super.key});
  @override
  State<ProfileDisplayPage> createState() => _ProfileDisplayPageState();
}

class _ProfileDisplayPageState extends State<ProfileDisplayPage> {
  String name = "Loading...", email = "", phone = "", gender = "", address = "",
      bloodGroup = "", dob = "", emergency = "", medicalConditions = "";
  String? photoUrl;
  File? profileImage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDisplayData();
  }

  Future<void> _loadDisplayData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final data = await UserProfileService.loadPatientProfile(uid);
    if (!mounted) return;
    setState(() {
      name = data['name']?.toString() ?? 'Patient';
      email = data['email']?.toString() ?? '—';
      phone = data['phone']?.toString() ?? '—';
      gender = data['gender']?.toString() ?? '—';
      address = data['address']?.toString() ?? '—';
      bloodGroup = data['bloodGroup']?.toString() ?? '—';
      dob = data['dob']?.toString() ?? '—';
      emergency = data['emergency']?.toString() ?? '—';
      medicalConditions = data['medicalConditions']?.toString() ?? '—';
      photoUrl = data['photoUrl'] as String?;
      profileImage = data['profileImage'] as File?;
      _loading = false;
    });
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Text("Logout"),
          ],
        ),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              nav.pop();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (c) => const PatientPortalScreen()),
                (route) => false,
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    await performAccountDeletion(
      context: context,
      destination: const PatientPortalScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Profile"),
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // --- HEADER ---
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      // Profile Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ProfileAvatar(
                          userId: FirebaseAuth.instance.currentUser?.uid,
                          photoUrl: photoUrl,
                          localFile: profileImage,
                          radius: 50,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            email,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- BODY ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information Section
                  _sectionHeader(Icons.person_outline, "Personal Information"),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow(Icons.person_outline, "Full Name", name),
                    _divider(),
                    _infoRow(Icons.email_outlined, "Email", email),
                    _divider(),
                    _infoRow(Icons.calendar_today_outlined, "Date of Birth", dob),
                    _divider(),
                    _infoRow(Icons.wc_outlined, "Gender", gender),
                  ]),

                  const SizedBox(height: 24),

                  // Medical Information Section
                  _sectionHeader(Icons.medical_services_outlined, "Medical Information"),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow(Icons.water_drop_outlined, "Blood Group", bloodGroup),
                    _divider(),
                    _infoRow(Icons.medical_information_outlined, "Medical Conditions", medicalConditions),
                  ]),

                  const SizedBox(height: 24),

                  // Contact Information Section
                  _sectionHeader(Icons.contact_phone_outlined, "Contact Information"),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow(Icons.phone_android_outlined, "Phone", phone),
                    _divider(),
                    _infoRow(Icons.phone_in_talk_outlined, "Emergency Contact", emergency),
                    _divider(),
                    _infoRow(Icons.location_on_outlined, "Address", address),
                  ]),

                  const SizedBox(height: 32),

                  // Edit Profile Button
                  _actionButton(
                    icon: Icons.edit_outlined,
                    label: "Edit Profile",
                    color: kPrimaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PatientProfilePage()),
                      ).then((_) => _loadDisplayData());
                    },
                  ),

                  const SizedBox(height: 12),

                  // Logout Button
                  _actionButton(
                    icon: Icons.logout_rounded,
                    label: "Logout",
                    color: Colors.orange.shade700,
                    onTap: _showLogoutDialog,
                  ),

                  const SizedBox(height: 12),

                  // Delete Account Button
                  _actionButton(
                    icon: Icons.delete_forever_rounded,
                    label: "Delete Account",
                    color: Colors.red,
                    onTap: _handleDeleteAccount,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: kPrimaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
      ],
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: kTextLight),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, indent: 50, color: Colors.grey.shade200);
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: color.withValues(alpha: 0.04),
        ),
      ),
    );
  }
}

// ============================================================
// 2. EDIT PROFILE PAGE (Email Read-Only)
// ============================================================
class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});
  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final TextEditingController nameC = TextEditingController();
  final TextEditingController phoneC = TextEditingController();
  final TextEditingController addressC = TextEditingController();
  final TextEditingController emergencyC = TextEditingController();
  final TextEditingController condC = TextEditingController();
  String bloodGroup = "";
  String gender = "";
  String _dob = "";
  String _email = "";
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    nameC.text = prefs.getString('name') ?? "";
    phoneC.text = prefs.getString('phone') ?? "";
    addressC.text = prefs.getString('address') ?? "";
    emergencyC.text = prefs.getString('emergency') ?? "";
    condC.text = prefs.getString('conditions') ?? "";
    setState(() {
      _dob = prefs.getString('dob') ?? "";
      _email = prefs.getString('email') ?? FirebaseAuth.instance.currentUser?.email ?? "";
      gender = prefs.getString('gender') ?? "";
      bloodGroup = prefs.getString('bloodGroup') ?? "";
      String? path = prefs.getString('imagePath');
      if (path != null) _profileImage = File(path);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', nameC.text);
    await prefs.setString('phone', phoneC.text);
    await prefs.setString('address', addressC.text);
    await prefs.setString('emergency', emergencyC.text);
    await prefs.setString('conditions', condC.text);
    if (_profileImage != null) await prefs.setString('imagePath', _profileImage!.path);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await UserProfileService.syncPatientProfileToFirestore(
        uid: uid,
        fields: {
          'name': nameC.text,
          'phone': phoneC.text,
          'address': addressC.text,
          'emergency': emergencyC.text,
          'medicalConditions': condC.text,
        },
      );
      if (_profileImage != null) {
        await ProfileImageService.uploadAndSaveProfilePhoto(
          userId: uid,
          imageFile: _profileImage!,
        );
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile Updated Successfully"), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Photo
          Center(
            child: GestureDetector(
              onTap: () async {
                final XFile? i = await _picker.pickImage(source: ImageSource.gallery);
                if (i != null) setState(() => _profileImage = File(i.path));
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    backgroundColor: Colors.grey[300],
                    child: _profileImage == null
                        ? const Icon(Icons.camera_alt, color: Colors.grey, size: 30)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text("Tap to change photo", style: TextStyle(color: kTextLight, fontSize: 12)),
          ),
          const SizedBox(height: 28),

          // --- Email (Read-Only) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: kTextLight, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Email Address (cannot be changed)",
                        style: TextStyle(fontSize: 11, color: kTextLight),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _email.isNotEmpty ? _email : "—",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.lock, color: kTextLight, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Editable Fields ---
          _buildEditField("Full Name", nameC, Icons.person_outline),
          _buildEditField("Phone Number", phoneC, Icons.phone_android_outlined),
          _buildEditField("Address", addressC, Icons.location_on_outlined),
          _buildEditField("Emergency Contact", emergencyC, Icons.phone_in_talk_outlined),
          _buildEditField("Medical Conditions", condC, Icons.medical_services_outlined),

          const SizedBox(height: 16),

          const Text("Non-Editable Information", style: TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 12),

          _buildReadOnlyField("Date of Birth", _dob, Icons.calendar_today_outlined),
          _buildReadOnlyField("Gender", gender, Icons.wc_outlined),
          _buildReadOnlyField("Blood Group", bloodGroup, Icons.water_drop_outlined),

          const SizedBox(height: 28),

          // Save Button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saveData,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                "Save Changes",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextLight),
          prefixIcon: Icon(icon, color: kPrimaryColor, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: kTextLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$label (cannot be changed)",
                  style: const TextStyle(fontSize: 11, color: kTextLight),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isNotEmpty ? value : "—",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock, color: kTextLight, size: 18),
        ],
      ),
    );
  }
}