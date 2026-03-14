import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Auth/doctor_login_page.dart';

// --- DATA & WIDGET IMPORTS ---
import '../Data/doctor_dummy_data.dart';
import '../Widgets/stat_card.dart';
import '../Widgets/request_card.dart';

// --- SCREENS IMPORTS ---
import 'doctor_appointments_screen.dart';
import 'my_patients_screen.dart';
import 'doctor_chat_screen.dart';
import 'doctor_profile_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DoctorHomeTab(),
    const DoctorAppointmentsScreen(),
    const DoctorChatScreen(),
    const DoctorProfileScreen(),
  ];

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DoctorLoginScreen()),
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showLogoutDialog();
      },
      child: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "Dashboard"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: "Schedule"),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: "Chat"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({super.key});

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> {
  String _doctorName = "Doctor";
  final String _currentDoctorId = FirebaseAuth.instance.currentUser!.uid; // Store ID for filtering

  @override
  void initState() {
    super.initState();
    _fetchDoctorName();
  }

  Future<void> _fetchDoctorName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            _doctorName = doc['name'];
          });
        }
      } catch (e) {
        print("Error fetching name: $e");
      }
    }
  }

  Future<void> _handleRequest(String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
        'status': status,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'Accepted' ? "Request Accepted" : "Request Declined"),
        backgroundColor: status == 'Accepted' ? Colors.green : Colors.red,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome Back,", style: TextStyle(fontSize: 14, color: Colors.white70)),
            Text("Dr. $_doctorName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications)),
        ],
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

            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                StatCard(
                  label: "Total Patients",
                  value: dashboardStats['patients']!,
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                StatCard(
                  label: "Pending Requests",
                  value: "New",
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                ),
                StatCard(
                  label: "Rating",
                  value: dashboardStats['rating']!,
                  icon: Icons.star,
                  color: Colors.amber,
                ),
                StatCard(
                  label: "Experience",
                  value: dashboardStats['experience']!,
                  icon: Icons.work,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Recent Requests Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Requests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
                ),
                TextButton(
                    onPressed: () {},
                    child: const Text("See All")
                ),
              ],
            ),

            // REAL-TIME REQUESTS LIST (FILTERED)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('status', isEqualTo: 'Pending')
                  .where('doctorId', isEqualTo: _currentDoctorId) // ✅ ADDED FILTER
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ));
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
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String docId = docs[index].id;

                    // Data convert with safety
                    Map<String, String> requestData = {
                      'name': (data['patientName'] ?? 'Unknown').toString(),
                      'issue': (data['problem'] ?? 'Consultation').toString(), // 'type' ko 'problem' se replace kiya kyunke humne database mein 'problem' save kiya tha
                      'date': (data['date'] ?? '').toString(),
                      'time': (data['time'] ?? '').toString(),
                      'image': 'assets/images/patient_placeholder.png', // Placeholder image use kar rahe hain crash se bachne ke liye
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

            // Quick Actions
            const Text(
              "Quick Access",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ]
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.people_outline, color: Color(0xFF1565C0)),
                ),
                title: const Text("View All Patients", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Check patient history & reports"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const MyPatientsScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}