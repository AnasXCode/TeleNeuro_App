import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../Auth/doctor_login_page.dart';
import '../../Widgets/profile_avatar.dart';
import '../../Widgets/account_delete_dialog.dart';
import '../../services/profile_image_service.dart';
import '../../services/user_profile_service.dart';

// --- THEME COLORS ---
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  String _name = "Loading...";
  String _email = "";
  String _experience = "0 Years";
  String _rating = "Loading..."; 
  String _hospital = "Not Set";
  String _phone = "Not Set";
  String _specialization = "—";
  String _qualifications = "—";
  String _about = "—";
  String _dob = "—";
  String? _photoUrl;
  
  bool _loading = true;

  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!mounted) return;

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _name = data['name'] ?? "Doctor";
          _email = data['email'] ?? "";
          _experience = data['experience'] ?? "0 Years";
          _hospital = data['hospital'] ?? "Not Set";
          _phone = data['phone'] ?? "Not Set";
          _specialization = data['speciality'] ?? data['specialization'] ?? "General Physician";
          _qualifications = data['qualifications'] ?? data['education'] ?? "—";
          _about = data['about'] ?? "—";
          _dob = data['dob']?.toString().trim().isNotEmpty == true ? data['dob'].toString() : "—";
          _photoUrl = (data['photoUrl'] as String?)?.trim();
          if (_photoUrl != null && _photoUrl!.isEmpty) _photoUrl = null;

          int totalReviews = data['totalReviews'] ?? 0;
          if (totalReviews == 0) {
            _rating = "New";
          } else {
            _rating = "${data['rating']?.toString() ?? "0.0"} / 5.0";
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DoctorLoginScreen()),
                  (route) => false
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(BuildContext context) {
    performAccountDeletion(
      context: context,
      destination: const DoctorLoginScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Profile"),
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
            automaticallyImplyLeading: false, // Dashboard handles back
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
                          userId: currentUserId,
                          photoUrl: _photoUrl,
                          radius: 50,
                          fallbackIcon: Icons.medical_services,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Dr. $_name",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _specialization,
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
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
                  // Professional Information Section
                  _sectionHeader(Icons.work_outline, "Professional Information"),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow(Icons.email_outlined, "Email", _email),
                    _divider(),
                    _infoRow(Icons.calendar_today_outlined, "Date of Birth", _dob),
                    _divider(),
                    _infoRow(Icons.medical_services_outlined, "Specialization", _specialization),
                    _divider(),
                    _infoRow(Icons.school_outlined, "Qualifications", _qualifications),
                    _divider(),
                    _infoRow(Icons.star_outline, "Rating", _rating),
                  ]),

                  const SizedBox(height: 24),

                  // Work Information Section
                  _sectionHeader(Icons.local_hospital_outlined, "Work Information"),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow(Icons.business_outlined, "Hospital", _hospital),
                    _divider(),
                    _infoRow(Icons.access_time_outlined, "Experience", _experience),
                    _divider(),
                    _infoRow(Icons.info_outline, "About", _about),
                  ]),

                  const SizedBox(height: 24),

                  // Contact Information Section
                  _sectionHeader(Icons.contact_phone_outlined, "Contact Information"),
                  const SizedBox(height: 12),
                  _infoCard([
                    _infoRow(Icons.phone_android_outlined, "Phone", _phone),
                  ]),

                  const SizedBox(height: 24),

                  // Patient Reviews Section
                  _sectionHeader(Icons.rate_review_outlined, "Patient Reviews"),
                  const SizedBox(height: 12),
                  _buildReviewsList(),

                  const SizedBox(height: 32),

                  // Edit Profile Button
                  _actionButton(
                    icon: Icons.edit_outlined,
                    label: "Edit Profile",
                    color: kPrimaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DoctorEditProfilePage()),
                      ).then((_) => _fetchDoctorData());
                    },
                  ),

                  const SizedBox(height: 12),

                  // Logout Button
                  _actionButton(
                    icon: Icons.logout_rounded,
                    label: "Logout",
                    color: Colors.orange.shade700,
                    onTap: () => _handleLogout(context),
                  ),

                  const SizedBox(height: 12),

                  // Delete Account Button
                  _actionButton(
                    icon: Icons.delete_forever_rounded,
                    label: "Delete Account",
                    color: Colors.red,
                    onTap: () => _handleDeleteAccount(context),
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

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: currentUserId)
          .where('isRated', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(child: Text("No reviews yet.", style: TextStyle(color: Colors.grey))),
          );
        }

        var reviews = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            var data = reviews[index].data() as Map<String, dynamic>;
            double stars = (data['givenRating'] ?? 0).toDouble();
            String feedback = data['reviewText'] ?? "No comment provided.";
            String patientName = data['patientName'] ?? "Anonymous Patient";

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Row(
                          children: [
                            Text(stars.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feedback.isEmpty ? "No comment provided." : '"$feedback"',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// 2. DOCTOR EDIT PROFILE PAGE
// ============================================================
class DoctorEditProfilePage extends StatefulWidget {
  const DoctorEditProfilePage({super.key});
  @override
  State<DoctorEditProfilePage> createState() => _DoctorEditProfilePageState();
}

class _DoctorEditProfilePageState extends State<DoctorEditProfilePage> {
  final TextEditingController phoneC = TextEditingController();
  final TextEditingController hospitalC = TextEditingController();
  final TextEditingController experienceC = TextEditingController();
  final TextEditingController aboutC = TextEditingController();

  String _email = "";
  String _specialization = "";
  String _qualifications = "";
  File? _profileImage;
  String? _photoUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _email = data['email'] ?? "";
          _specialization = data['speciality'] ?? data['specialization'] ?? "";
          _qualifications = data['qualifications'] ?? data['education'] ?? "";
          
          phoneC.text = (data['phone'] == 'Not Set' || data['phone'] == null) ? "" : data['phone'];
          hospitalC.text = (data['hospital'] == 'Not Set' || data['hospital'] == null) ? "" : data['hospital'];
          
          String expStr = data['experience'] ?? "";
          experienceC.text = expStr.replaceAll(RegExp(r'[^0-9]'), ''); // Extract just the numbers
          
          aboutC.text = (data['about'] == '—' || data['about'] == null) ? "" : data['about'];
          _photoUrl = data['photoUrl'];
        });
      }
    }
  }

  Future<void> _saveData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      String newExp = experienceC.text.trim();
      if (newExp.isNotEmpty) {
        newExp = "$newExp Years";
      }

      await UserProfileService.syncDoctorProfileToFirestore(
        uid: uid,
        fields: {
          'phone': phoneC.text.trim(),
          'hospital': hospitalC.text.trim(),
          'experience': newExp,
          'about': aboutC.text.trim(),
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                    ),
                    child: ProfileAvatar(
                      userId: FirebaseAuth.instance.currentUser?.uid,
                      photoUrl: _photoUrl,
                      localFile: _profileImage,
                      radius: 50,
                      fallbackIcon: Icons.medical_services,
                    ),
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

          // --- Editable Fields ---
          _buildEditField("Phone Number", phoneC, Icons.phone_android_outlined),
          _buildEditField("Hospital", hospitalC, Icons.local_hospital_outlined),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: experienceC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Years of Experience",
                labelStyle: const TextStyle(color: kTextLight),
                prefixIcon: const Icon(Icons.work_outline, color: kPrimaryColor, size: 20),
                suffixText: "Years",
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
          ),
          
          _buildEditField("About", aboutC, Icons.info_outline, maxLines: 3),

          const SizedBox(height: 16),

          const Text("Non-Editable Information", style: TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 12),

          // --- Read-Only Fields ---
          _buildReadOnlyField("Email Address", _email, Icons.email_outlined),
          _buildReadOnlyField("Specialization", _specialization, Icons.medical_services_outlined),
          _buildReadOnlyField("Qualifications", _qualifications, Icons.school_outlined),

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

  Widget _buildEditField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
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