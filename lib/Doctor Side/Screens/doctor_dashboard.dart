import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Widgets/stat_card.dart';
import '../Widgets/request_card.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_mri_reports_screen.dart';
import 'doctor_guide_screen.dart';
import 'my_patients_screen.dart';
import 'doctor_chat_screen.dart';
import 'doctor_profile_screen.dart';
import '../../Widgets/bottom_nav_badge_icon.dart';
import '../../Widgets/tab_notifications_screen.dart';
import '../../services/notification_service.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;

  // ✅ Dashboard (Home) par wapis aane ki logic
  void _goToHome() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  // Navigation Logic for "See All"
  void _jumpToSchedule() {
    setState(() {
      _selectedIndex = 1; // Schedule Tab index
    });
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
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
      const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule'),
      BottomNavigationBarItem(
        icon: uid.isEmpty
            ? const Icon(Icons.chat_bubble_outline_rounded)
            : BottomNavBadgeIcon(
          icon: Icons.chat_bubble_outline_rounded,
          countStream: NotificationService.unreadChatCountStream(uid),
        ),
        label: 'Chat',
      ),
      BottomNavigationBarItem(
        icon: uid.isEmpty
            ? const Icon(Icons.notifications_outlined)
            : BottomNavBadgeIcon(
          icon: Icons.notifications_outlined,
          countStream: NotificationService.unreadCountStream(uid),
        ),
        label: 'Alerts',
      ),
      const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List<Widget> screens = [
      DoctorHomeTab(onSeeAll: _jumpToSchedule),
      DoctorAppointmentsScreen(onBack: _goToHome),
      const DoctorChatScreen(),
      const TabNotificationsScreen(),
      const DoctorProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          _goToHome();
        }
      },
      child: Scaffold(
        body: screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: _buildNavItems(uid),
        ),
      ),
    );
  }
}

class DoctorHomeTab extends StatefulWidget {
  final VoidCallback onSeeAll; // Callback to change tab
  const DoctorHomeTab({super.key, required this.onSeeAll});

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  String _doctorName = "Doctor";
  String _doctorRating = "4.9";
  String _doctorExperience = "0 Years";
  final String _currentDoctorId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
          if (!mounted) return;
          setState(() {
            _doctorName = data?['name'] ?? 'Doctor';
            if (data != null && data.containsKey('rating')) _doctorRating = data['rating'].toString();
            if (data != null && data.containsKey('experience')) _doctorExperience = data['experience'].toString();
          });
        }
      } catch (e) {
        debugPrint("Error fetching doctor data: $e");
      }
    }
  }

  Future<void> _handleRequest(String docId, String status) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final apptSnap = await FirebaseFirestore.instance.collection('appointments').doc(docId).get();
      final apptData = apptSnap.data();

      await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
        'status': status,
      });

      if (status == 'Accepted' && apptData != null) {
        await NotificationService.notifyAppointmentAccepted(
          patientId: (apptData['patientId'] ?? '').toString(),
          doctorId: _currentDoctorId,
          doctorName: _doctorName,
          appointmentId: docId,
          date: (apptData['date'] ?? '').toString(),
          time: (apptData['time'] ?? '').toString(),
        );
      }

      messenger.showSnackBar(SnackBar(
        content: Text(status == 'Accepted' ? "Request Accepted" : "Request Declined"),
        backgroundColor: status == 'Accepted' ? Colors.green : Colors.red,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Error: $e"))); // ✅ Captured messenger use kiya
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome Back,", style: TextStyle(fontSize: 14, color: Colors.white70)),
            Text("Dr. $_doctorName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Overview",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
            ),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('doctorId', isEqualTo: _currentDoctorId)
                  .snapshots(),
              builder: (ctx, snapshot) {
                int pendingCount = 0;
                Set<String> uniquePatients = {};

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    String status = data['status'] ?? '';
                    String patientId = data['patientId'] ?? '';

                    if (status == 'Pending') {
                      pendingCount++;
                    } else if (status == 'Accepted' || status == 'Completed') {
                      if (patientId.isNotEmpty) uniquePatients.add(patientId);
                    }
                  }
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.3,
                  children: [
                    StatCard(label: "Total Patients", value: uniquePatients.length.toString(), icon: Icons.people, color: Colors.blue),
                    StatCard(label: "Pending Requests", value: pendingCount.toString(), icon: Icons.pending_actions, color: Colors.orange),
                    StatCard(label: "Rating", value: _doctorRating, icon: Icons.star, color: Colors.amber),
                    StatCard(label: "Experience", value: _doctorExperience, icon: Icons.work, color: Colors.purple),
                  ],
                );
              },
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recent Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
                TextButton(
                    onPressed: widget.onSeeAll,
                    child: const Text("See All")
                ),
              ],
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('status', isEqualTo: 'Pending')
                  .where('doctorId', isEqualTo: _currentDoctorId)
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(30.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("No Pending Requests", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (ctx, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String docId = docs[index].id;

                    Map<String, String> requestData = {
                      'patientId': (data['patientId'] ?? '').toString(),
                      'name': (data['patientName'] ?? 'Unknown').toString(),
                      'age': 'N/A',
                      'issue': (data['problem'] ?? 'Consultation').toString(),
                      'date': (data['date'] ?? '').toString(),
                      'time': (data['time'] ?? '').toString(),
                      'image': 'assets/images/patient_placeholder.png',
                    };

                    return RequestCard(
                      request: requestData,
                      onAccept: () => _handleRequest(docId, 'Accepted'),
                      onDecline: () => _handleRequest(docId, 'Declined'),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            const Text("Quick Access", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
              child: ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.people_outline, color: Color(0xFF1565C0))),
                title: const Text("View All Patients", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Check patient history & reports"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const MyPatientsScreen()));
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
              child: ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), shape: BoxShape.circle), child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFC62828))),
                title: const Text("Patient MRI reports", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Live summaries from Firebase (PDF stays on patient device)"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const DoctorMriReportsScreen()));
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.menu_book_outlined, color: Colors.teal),
                ),
                title: const Text('User Guide', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('How to use TeleNeuro as a doctor'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const DoctorGuideScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}