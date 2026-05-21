import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- AUTH IMPORTS ---
import '../Auth/patient_portal.dart';

// --- SCREENS IMPORTS ---
import 'appointments_screen.dart';
import 'chat_screen.dart';
import 'doctor_profile_screen.dart';
import 'patient_profile_screen.dart';
import 'reports_screen.dart';
import 'all_doctors_screen.dart';
import 'mri_upload_screen.dart';

// --- WIDGETS ---
import '../Widgets/category_card.dart';
import '../../widgets/notification_icon_button.dart';
import '../../widgets/patient_profile_menu.dart';
import '../../widgets/appointment_status_listener.dart';

// GLOBAL COLORS
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kSecondaryColor = Color(0xFF42A5F5);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  File? _dashboardProfileImage;
  int _selectedIndex = 0;
  String _searchQuery = "";
  String _userName = "Patient";

  @override
  void initState() {
    super.initState();
    _loadDashboardImage();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            var data = userDoc.data() as Map<String, dynamic>?;
            _userName = (data?['name'] ?? "Patient").toString();
          });
        }
      } catch (e) {}
    }
  }

  Future<void> _loadDashboardImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString('imagePath');
    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() { _dashboardProfileImage = File(imagePath); });
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("End session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const PatientPortalScreen()), (route) => false);
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_selectedIndex == 0) bodyContent = _buildHomeContent();
    else if (_selectedIndex == 1) bodyContent = const CalendarPage();
    else bodyContent = const PatientChatScreen();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showLogoutDialog(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: AppointmentStatusListener(child: bodyContent),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPrimaryColor,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Messages'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, $_userName', style: const TextStyle(fontSize: 16, color: kTextLight)),
                    const Text('Find your Specialist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
                  ],
                ),
              ),
              const NotificationIconButton(iconColor: kPrimaryColor),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => showPatientProfileMenu(
                  context,
                  onUpdated: () {
                    _loadDashboardImage();
                    _fetchUserName();
                  },
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: kAccentColor,
                  backgroundImage: _dashboardProfileImage != null ? FileImage(_dashboardProfileImage!) : null,
                  child: _dashboardProfileImage == null ? const Icon(Icons.person, color: kPrimaryColor) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(hintText: 'Search doctors...', border: InputBorder.none, icon: Icon(Icons.search, color: kPrimaryColor)),
            ),
          ),
          const SizedBox(height: 20),

          _buildBanner(context),
          const SizedBox(height: 25),

          if (_searchQuery.trim().isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results (${_searchQuery.trim()})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
                ),
                GestureDetector(
                  onTap: () => setState(() => _searchQuery = ''),
                  child: const Text('Clear', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildAllDoctorsList(filterQuery: _searchQuery.trim(), maxHeight: 320),
            const SizedBox(height: 20),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Top Specialists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDoctorsScreen())), child: const Text("See All", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: _buildTopSpecialistsRow(),
            ),
          ],
          const SizedBox(height: 25),
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.1,
            children: [
              CategoryCard(title: 'My Profile', subtitle: 'View Details', icon: Icons.account_circle_rounded, color: const Color(0xFF5C6BC0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileDisplayPage()))),
              CategoryCard(title: 'Manage Account', subtitle: 'Edit Info', icon: Icons.settings_rounded, color: const Color(0xFF26C6DA), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PatientProfilePage())).then((_) => _loadDashboardImage())),
              CategoryCard(title: 'Find Doctor', subtitle: 'Specialists', icon: Icons.person_search_rounded, color: const Color(0xFFEC407A), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDoctorsScreen()))),
              CategoryCard(title: 'Lab Reports', subtitle: 'Check History', icon: Icons.insert_drive_file_rounded, color: const Color(0xFF7E57C2), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReportsPage()))),
              CategoryCard(title: 'AI Diagnosis', subtitle: 'Upload MRI', icon: Icons.document_scanner_rounded, color: const Color(0xFF00897B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MRIUploadPage()))),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  bool _matchesDoctorSearch(Map<String, dynamic> data, String query) {
    final q = query.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    final spec = (data['speciality'] ?? '').toString().toLowerCase();
    final hospital = (data['hospital'] ?? '').toString().toLowerCase();
    return name.contains(q) || spec.contains(q) || hospital.contains(q);
  }

  Widget _buildTopSpecialistsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Doctor').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No specialists registered yet.'));
        }

        var topRatedDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final totalReviews = data['totalReviews'] ?? 0;
          final rating = (data['rating'] ?? 0.0).toDouble();
          return totalReviews > 0 && rating >= 4.0;
        }).toList();

        topRatedDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          return ((dataB['rating'] ?? 0.0) as num)
              .compareTo((dataA['rating'] ?? 0.0) as num);
        });

        final displayList = topRatedDocs.take(5).toList();
        if (displayList.isEmpty) {
          return const Center(
              child: Text('More top rated doctors joining soon!',
                  style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: displayList.length,
          itemBuilder: (context, index) =>
              _doctorCard(displayList[index], horizontal: true),
        );
      },
    );
  }

  Widget _buildAllDoctorsList({required String filterQuery, double? maxHeight}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Doctor').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No doctors available.', style: TextStyle(color: Colors.grey));
        }

        final matched = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _matchesDoctorSearch(data, filterQuery);
        }).toList();

        matched.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final reviewsA = dataA['totalReviews'] ?? 0;
          final reviewsB = dataB['totalReviews'] ?? 0;
          final ratingA = reviewsA == 0 ? 0.0 : (dataA['rating'] ?? 0.0).toDouble();
          final ratingB = reviewsB == 0 ? 0.0 : (dataB['rating'] ?? 0.0).toDouble();
          return ratingB.compareTo(ratingA);
        });

        if (matched.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No doctors match "$filterQuery".',
                  style: const TextStyle(color: Colors.grey)),
            ),
          );
        }

        return SizedBox(
          height: maxHeight,
          child: ListView.builder(
            itemCount: matched.length,
            itemBuilder: (context, index) => _doctorCard(matched[index]),
          ),
        );
      },
    );
  }

  Widget _doctorCard(DocumentSnapshot doc, {bool horizontal = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    final name = (data['name'] ?? 'Unknown Doctor').toString();
    final speciality = (data['speciality'] ?? 'General Physician').toString();
    final totalReviews = data['totalReviews'] ?? 0;
    final ratingDisplay =
        totalReviews == 0 ? 'New' : (data['rating'] ?? 0.0).toString();

    if (horizontal) {
      return GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (c) => DoctorProfilePage(doctorId: docId))),
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 15, bottom: 5, top: 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 3))
              ]),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                  radius: 35,
                  backgroundColor: kAccentColor,
                  child: Icon(Icons.person, size: 35, color: kPrimaryColor)),
              const SizedBox(height: 10),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kTextDark)),
              const SizedBox(height: 4),
              Text(speciality,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kTextLight)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  Text(' $ratingDisplay',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kTextDark))
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (c) => DoctorProfilePage(doctorId: docId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
                backgroundColor: kAccentColor,
                child: Icon(Icons.person, color: kPrimaryColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: kTextDark)),
                  Text(speciality, style: const TextStyle(color: kTextLight, fontSize: 13)),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                Text(' $ratingDisplay',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: kPrimaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Need a diagnosis?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDoctorsScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kPrimaryColor),
                  child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Icon(Icons.monitor_heart_outlined, size: 40, color: Colors.white),
        ],
      ),
    );
  }
}