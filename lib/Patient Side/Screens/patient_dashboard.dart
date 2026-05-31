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
import '../../Widgets/profile_view_screens.dart';
import 'patient_profile_screen.dart';
import 'reports_screen.dart';
import 'all_doctors_screen.dart';
import 'mri_upload_screen.dart';

// --- WIDGETS ---
import '../Widgets/category_card.dart';
import '../../Widgets/bottom_nav_badge_icon.dart';
import '../../Widgets/tab_notifications_screen.dart';
import '../../Widgets/profile_avatar.dart';
import '../../services/notification_service.dart';
import 'patient_guide_screen.dart';

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
          if (!mounted) return;
          setState(() {
            var data = userDoc.data() as Map<String, dynamic>?;
            _userName = (data?['name'] ?? "Patient").toString();
          });
        }
      } catch (e) {
        debugPrint('Patient dashboard: fetch user name failed: $e');
      }
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
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("End session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (index == 2) {
      NotificationService.markChatNotificationsAsRead(uid);
    }
  }

  List<BottomNavigationBarItem> _buildNavItems(String uid) {
    return [
      const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
      const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule'),
      BottomNavigationBarItem(
        icon: uid.isEmpty
            ? const Icon(Icons.chat_bubble_outline_rounded)
            : BottomNavBadgeIcon(
                icon: Icons.chat_bubble_outline_rounded,
                countStream: NotificationService.unreadChatCountStream(uid),
              ),
        label: 'Messages',
      ),
      BottomNavigationBarItem(
        icon: uid.isEmpty
            ? const Icon(Icons.notifications_outlined)
            : BottomNavBadgeIcon(
                icon: Icons.notifications_outlined,
                countStream: NotificationService.unreadCountStream(uid),
              ),
        label: 'Notifications',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    Widget bodyContent;
    if (_selectedIndex == 0) {
      bodyContent = _buildHomeContent();
    } else if (_selectedIndex == 1) {
      bodyContent = const CalendarPage();
    } else if (_selectedIndex == 2) {
      bodyContent = const PatientChatScreen();
    } else {
      bodyContent = const TabNotificationsScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showLogoutDialog(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(child: bodyContent),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPrimaryColor,
          items: _buildNavItems(uid),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, $_userName', style: const TextStyle(fontSize: 16, color: kTextLight)),
                  const Text('Find your Specialist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileDisplayPage()),
                    ).then((_) {
                      _loadDashboardImage();
                      _fetchUserName();
                    });
                  }
                },
                child: ProfileAvatar(
                  userId: FirebaseAuth.instance.currentUser?.uid,
                  localFile: _dashboardProfileImage,
                  radius: 20,
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Doctor').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Center(child: Text("Unable to load"));
                if (!snapshot.hasData || snapshot.data == null) return const Center(child: Text("No data found"));

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No specialists registered yet."));

                final query = _searchQuery.trim().toLowerCase();
                final List<DocumentSnapshot> displayList;

                if (query.isNotEmpty) {
                  displayList = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return false;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final speciality = (data['speciality'] ?? data['specialization'] ?? '').toString().toLowerCase();
                    return name.contains(query) || speciality.contains(query);
                  }).toList();

                  displayList.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final ratingA = (dataA['rating'] ?? 0.0).toDouble();
                    final ratingB = (dataB['rating'] ?? 0.0).toDouble();
                    return ratingB.compareTo(ratingA);
                  });
                } else {
                  var topRatedDocs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return false;
                    double rating = (data['rating'] ?? 0.0).toDouble();
                    return rating >= 4.0;
                  }).toList();

                  topRatedDocs.sort((a, b) {
                    var dataA = a.data() as Map<String, dynamic>;
                    var dataB = b.data() as Map<String, dynamic>;
                    double ratingA = (dataA['rating'] ?? 0.0).toDouble();
                    double ratingB = (dataB['rating'] ?? 0.0).toDouble();
                    return ratingB.compareTo(ratingA);
                  });

                  displayList = topRatedDocs.take(5).toList();
                }

                if (displayList.isEmpty) {
                  return Center(
                    child: Text(
                      query.isNotEmpty ? "No doctors found." : "More top rated doctors joining soon!",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayList.length, // Ab displayList use ho rahi hai
                  itemBuilder: (context, index) {
                    final doc = displayList[index];
                    final data = doc.data() as Map<String, dynamic>?;
                    final docId = doc.id;

                    String name = (data?['name'] ?? 'Unknown Doctor').toString();
                    String speciality = (data?['speciality'] ?? 'General Physician').toString();

                    // ✅ RATING DISPLAY LOGIC
                    int totalReviews = data?['totalReviews'] ?? 0;
                    String ratingDisplay = totalReviews == 0 ? "New" : (data?['rating'] ?? 0.0).toString();

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => DoctorProfileViewScreen(
                            doctorId: docId,
                            showPatientActions: true,
                            doctorDisplayName: name,
                          ),
                        ),
                      ),
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 15, bottom: 5, top: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, 3))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ProfileAvatar(
                              userId: docId,
                              radius: 35,
                              fallbackIcon: Icons.medical_services,
                            ),
                            const SizedBox(height: 10),
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
                            const SizedBox(height: 4),
                            Text(speciality, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kTextLight)),
                            const SizedBox(height: 8),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  Text(" $ratingDisplay", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextDark))
                                ]
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
              CategoryCard(title: 'User Guide', subtitle: 'How to use app', icon: Icons.menu_book_rounded, color: const Color(0xFF455A64), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PatientGuideScreen()))),
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