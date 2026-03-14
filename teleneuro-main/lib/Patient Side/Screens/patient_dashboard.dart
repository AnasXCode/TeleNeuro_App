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
import 'consult_doctor_screen.dart';
import 'patient_profile_screen.dart';
import 'reports_screen.dart';
import 'all_doctors_screen.dart';
import 'mri_upload_screen.dart'; // ✅ NEW IMPORT

// ✅ NEW IMPORT (Chat wala)
// Agar file path alag ho to Ctrl + . daba kar fix kar lena


// --- WIDGETS ---
import '../Widgets/category_card.dart';

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

  // Name Fetching
  Future<void> _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            var data = userDoc.data() as Map<String, dynamic>?;
            _userName = (data?['name'] ?? "Patient").toString();
          });
        }
      } catch (e) {
        print("Error: $e");
      }
    }
  }

  Future<void> _loadDashboardImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString('imagePath');
    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _dashboardProfileImage = File(imagePath);
      });
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("End session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const PatientPortalScreen()),
                      (route) => false,
                );
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
    if (_selectedIndex == 0) {
      bodyContent = _buildHomeContent();
    } else if (_selectedIndex == 1) {
      bodyContent = const CalendarPage();
    } else {
      // ✅ CHANGED: Ab yahan Chat Screen chalegi
      bodyContent = const PatientChatScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showLogoutDialog(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(child: bodyContent),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, $_userName', style: const TextStyle(fontSize: 16, color: kTextLight)),
                  const Text('Find your Specialist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
                ],
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: kAccentColor,
                backgroundImage: _dashboardProfileImage != null ? FileImage(_dashboardProfileImage!) : null,
                child: _dashboardProfileImage == null ? const Icon(Icons.person, color: kPrimaryColor) : null,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search doctors...',
                border: InputBorder.none,
                icon: Icon(Icons.search, color: kPrimaryColor),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Banner
          _buildBanner(context),
          const SizedBox(height: 25),

          // Top Specialists Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Top Specialists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDoctorsScreen()));
                },
                child: const Text("See All", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // --- HORIZONTAL LIST (CRASH-PROOF VERSION) ---
          SizedBox(
            height: 180, // Height increased slightly for safety
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'Doctor')
                  .snapshots(),
              builder: (context, snapshot) {
                // 1. Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Error Check (Safe Mode)
                if (snapshot.hasError) {
                  return const Center(child: Text("Unable to load"));
                }

                // 3. No Data Check
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text("No data found"));
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Text("No specialists registered yet.")
                  );
                }

                // Filter
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("No matching doctor"));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>?;
                    final docId = doc.id;

                    // Data Extraction (With Default Values)
                    String name = (data?['name'] ?? 'Unknown Doctor').toString();
                    String speciality = (data?['speciality'] ?? 'General Physician').toString();

                    // --- DIRECT CARD DESIGN (Replacing DoctorCard Widget) ---
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => ConsultDoctorPage(
                              doctorId: docId,
                              doctorName: name,
                            ),
                          ),
                        );
                      },
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
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Doctor Image
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: kAccentColor,
                              backgroundImage: const AssetImage('assets/images/doctor1.png'),
                              child: const Icon(Icons.person, size: 35, color: kPrimaryColor),
                            ),
                            const SizedBox(height: 10),
                            // Doctor Name
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: kTextDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Speciality
                            Text(
                              speciality,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kTextLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Rating
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.star, color: Colors.amber, size: 14),
                                Text(
                                  " 4.8",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kTextDark,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 25),

          // Quick Actions
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
              CategoryCard(
                title: 'My Profile',
                subtitle: 'View Details',
                icon: Icons.account_circle_rounded,
                color: const Color(0xFF5C6BC0),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileDisplayPage())),
              ),
              CategoryCard(
                title: 'Manage Account',
                subtitle: 'Edit Info',
                icon: Icons.settings_rounded,
                color: const Color(0xFF26C6DA),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PatientProfilePage())).then((_) => _loadDashboardImage()),
              ),
              CategoryCard(
                title: 'Find Doctor',
                subtitle: 'Specialists',
                icon: Icons.person_search_rounded,
                color: const Color(0xFFEC407A),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDoctorsScreen()));
                },
              ),
              CategoryCard(
                title: 'Lab Reports',
                subtitle: 'Check History',
                icon: Icons.insert_drive_file_rounded,
                color: const Color(0xFF7E57C2),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ReportsPage())),
              ),
              // ✅ NEW CARD ADDED HERE
              CategoryCard(
                title: 'AI Diagnosis',
                subtitle: 'Upload MRI',
                icon: Icons.document_scanner_rounded,
                color: const Color(0xFF00897B), // Teal color
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MRIUploadPage())),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Need a diagnosis?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const AllDoctorsScreen()));
                  },
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