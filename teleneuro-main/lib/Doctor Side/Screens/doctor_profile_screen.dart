import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added for Database
import '../Auth/doctor_login_page.dart';
import '../Data/doctor_dummy_data.dart';

class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  // --- LOGOUT FUNCTION ---
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;
              Navigator.pop(context);

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const DoctorLoginScreen()),
                    (route) => false,
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- DELETE ACCOUNT FUNCTION (New) ---
  void _handleDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.red)),
        content: const Text(
            "Are you sure? This will permanently remove your profile from TeleNeuro. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Dialog band kiya

              // Loading Dikhaya
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (c) => const Center(child: CircularProgressIndicator()),
              );

              try {
                User? user = FirebaseAuth.instance.currentUser;

                if (user != null) {
                  // 1. Database se uraya
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .delete();

                  // 2. Authentication se uraya
                  await user.delete();

                  if (!context.mounted) return;
                  Navigator.pop(context); // Loading hataya

                  // 3. Login Screen par bhej diya
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DoctorLoginScreen()),
                        (route) => false,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Account Deleted Successfully")),
                  );
                }
              } catch (e) {
                Navigator.pop(context); // Loading hataya
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e. Please Login again.")),
                );
              }
            },
            child: const Text("Delete Forever", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.person, size: 60, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 15),

            // Name
            const Text(
              "Dr. Anas Ahmed",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Neurologist • MBBS, FCPS",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Info Tiles
            _buildProfileTile(Icons.email, "Email", "doctor@telenuro.com"),
            _buildProfileTile(Icons.phone, "Phone", "+92 300 1234567"),
            _buildProfileTile(Icons.local_hospital, "Hospital", "Shifa International"),
            // Null check lagaya hai taake error na aye agar data na ho
            _buildProfileTile(Icons.star, "Rating",
                "${dashboardStats['rating'] ?? '4.8'} (${dashboardStats['reviews'] ?? '120'})"),

            const SizedBox(height: 30),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  _handleLogout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0), // Blue for Logout
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Logout",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 15),

            // ✅ DELETE ACCOUNT BUTTON (New)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  _handleDeleteAccount(context);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Delete Account",
                    style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
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
        title: Text(title,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black)),
      ),
    );
  }
}