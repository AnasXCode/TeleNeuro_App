import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../Auth/doctor_login_page.dart';
import '../../Widgets/profile_avatar.dart';
import '../../Widgets/account_delete_dialog.dart';
import '../../services/profile_image_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  String _name = "Loading...";
  String _email = "";
  String _experience = "0 Years";
  String _rating = "Loading..."; // Default
  String _hospital = "Not Set";
  String _phone = "Not Set";
  String _specialization = "—";
  String _qualifications = "—";
  String _about = "—";
  String? _photoUrl;
  File? _pendingPhoto;
  final ImagePicker _picker = ImagePicker();

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  // --- FETCH DATA FROM FIRESTORE ---
  Future<void> _fetchDoctorData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
          _photoUrl = (data['photoUrl'] as String?)?.trim();
          if (_photoUrl != null && _photoUrl!.isEmpty) _photoUrl = null;

          // ✅ NEW RATING LOGIC
          int totalReviews = data['totalReviews'] ?? 0;
          if (totalReviews == 0) {
            _rating = "New";
          } else {
            _rating = "${data['rating']?.toString() ?? "0.0"} / 5.0";
          }
        });
      }
    }
  }

  // --- UPDATE EXPERIENCE DIALOG ---
  void _showEditExperienceDialog() {
    String currentExp = _experience.replaceAll(RegExp(r'[^0-9]'), '');
    TextEditingController expController = TextEditingController(text: currentExp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Experience"),
        content: TextField(
          controller: expController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 2,
          decoration: const InputDecoration(
            hintText: "e.g., 5",
            labelText: "Years of Experience",
            suffixText: "Years",
            counterText: "",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (expController.text.isEmpty) return;

              String newExp = "${expController.text} Years";

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .update({'experience': newExp});

              setState(() => _experience = newExp);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Experience Updated Successfully")));
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- LOGOUT & DELETE ACCOUNT ---
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DoctorLoginScreen()), (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _pendingPhoto = File(picked.path));

    final url = await ProfileImageService.uploadAndSaveProfilePhoto(
      userId: currentUserId,
      imageFile: _pendingPhoto!,
    );
    if (!mounted) return;
    if (url != null) {
      setState(() {
        _photoUrl = url;
        _pendingPhoto = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photo'), backgroundColor: Colors.orange),
      );
    }
  }

  void _handleDeleteAccount(BuildContext context) {
    performAccountDeletion(
      context: context,
      destination: const DoctorLoginScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(title: const Text("My Profile", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1565C0), centerTitle: true, automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Left align ke liye
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: ProfileAvatar(
                      userId: currentUserId,
                      photoUrl: _photoUrl,
                      localFile: _pendingPhoto,
                      radius: 50,
                      fallbackIcon: Icons.medical_services,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap photo to change', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 15),
                  Text("Dr. $_name", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_specialization, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildProfileTile(Icons.email, "Email", _email),
            _buildProfileTile(Icons.phone, "Phone", _phone),
            _buildProfileTile(Icons.medical_services, "Specialization", _specialization),
            _buildProfileTile(Icons.school, "Qualifications", _qualifications),
            _buildProfileTile(Icons.local_hospital, "Hospital", _hospital),
            _buildProfileTile(Icons.star, "Rating", _rating),

            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: ListTile(
                leading: const Icon(Icons.work, color: Color(0xFF1565C0)),
                title: const Text("Experience", style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(_experience, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onPressed: _showEditExperienceDialog,
                ),
              ),
            ),

            if (_about != "—") ...[
              const SizedBox(height: 8),
              _buildProfileTile(Icons.info_outline, "About", _about),
            ],

            // PATIENT REVIEWS SECTION
            const Divider(thickness: 1.5),
            const SizedBox(height: 10),
            const Text(
              "Patient Reviews",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
            ),
            const SizedBox(height: 15),

            // Real-time StreamBuilder for Reviews
            StreamBuilder<QuerySnapshot>(
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
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No reviews yet.", style: TextStyle(color: Colors.grey))),
                  );
                }

                var reviews = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
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
                            const SizedBox(height: 5),
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
            ),

            const SizedBox(height: 30),

            // Buttons
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => _handleLogout(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)), child: const Text("Logout", style: TextStyle(color: Colors.white)))),
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, height: 50, child: OutlinedButton(onPressed: () => _handleDeleteAccount(context), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)), child: const Text("Delete Account", style: TextStyle(color: Colors.red)))),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1565C0)),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }
}