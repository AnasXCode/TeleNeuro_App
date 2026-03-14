import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// --- THEME COLORS ---
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

// 1. VIEW PROFILE PAGE
class ProfileDisplayPage extends StatefulWidget {
  const ProfileDisplayPage({super.key});
  @override State<ProfileDisplayPage> createState() => _ProfileDisplayPageState();
}

class _ProfileDisplayPageState extends State<ProfileDisplayPage> {
  String name="Loading...", email="", phone="", gender="", address="", bloodGroup="", dob="", emergency="", medicalConditions="";
  File? profileImage;

  @override void initState() { super.initState(); _loadDisplayData(); }

  Future<void> _loadDisplayData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? "Anas Ahmed";
      email = prefs.getString('email') ?? "anas.ahmed@example.com";
      phone = prefs.getString('phone') ?? "+92 300 1234567";
      gender = prefs.getString('gender') ?? "Male";
      address = prefs.getString('address') ?? "Taxila, Pakistan";
      bloodGroup = prefs.getString('bloodGroup') ?? "B+";
      dob = prefs.getString('dob') ?? "01/01/1980";
      emergency = prefs.getString('emergency') ?? "+92 321 7654321";
      medicalConditions = prefs.getString('conditions') ?? "None";
      String? path = prefs.getString('imagePath');
      if (path != null) profileImage = File(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PatientProfilePage())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                  radius: 55,
                  backgroundImage: profileImage != null ? FileImage(profileImage!) : null,
                  backgroundColor: kAccentColor,
                  child: profileImage == null ? const Icon(Icons.person, size: 60, color: kPrimaryColor) : null
              ),
            ),
            const SizedBox(height: 15),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
            Text(email, style: const TextStyle(color: kTextLight)),
            const SizedBox(height: 30),
            _infoTile(Icons.calendar_today, "Date of Birth", dob),
            _infoTile(Icons.person_outline, "Gender", gender),
            _infoTile(Icons.water_drop, "Blood Group", bloodGroup),
            _infoTile(Icons.phone_android, "Phone", phone),
            _infoTile(Icons.phone_in_talk, "Emergency Contact", emergency),
            _infoTile(Icons.location_on, "Address", address),
            _infoTile(Icons.medical_services, "Medical Conditions", medicalConditions),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: kTextLight)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextDark)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// 2. EDIT PROFILE PAGE
class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});
  @override State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final TextEditingController nameC = TextEditingController();
  final TextEditingController dobC = TextEditingController();
  final TextEditingController phoneC = TextEditingController();
  final TextEditingController emailC = TextEditingController();
  final TextEditingController addressC = TextEditingController();
  final TextEditingController emergencyC = TextEditingController();
  final TextEditingController condC = TextEditingController();
  String bloodGroup = "B+", gender = "Male";
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    nameC.text = prefs.getString('name') ?? "Anas Ahmed";
    dobC.text = prefs.getString('dob') ?? "01/01/1980";
    phoneC.text = prefs.getString('phone') ?? "+92 300 1234567";
    emailC.text = prefs.getString('email') ?? "anas.ahmed@example.com";
    addressC.text = prefs.getString('address') ?? "Taxila, Pakistan";
    emergencyC.text = prefs.getString('emergency') ?? "+92 321 7654321";
    condC.text = prefs.getString('conditions') ?? "None";
    setState(() {
      gender = prefs.getString('gender') ?? "Male";
      bloodGroup = prefs.getString('bloodGroup') ?? "B+";
      String? path = prefs.getString('imagePath');
      if (path != null) _profileImage = File(path);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', nameC.text);
    await prefs.setString('dob', dobC.text);
    await prefs.setString('phone', phoneC.text);
    await prefs.setString('email', emailC.text);
    await prefs.setString('address', addressC.text);
    await prefs.setString('emergency', emergencyC.text);
    await prefs.setString('conditions', condC.text);
    await prefs.setString('gender', gender);
    await prefs.setString('bloodGroup', bloodGroup);
    if (_profileImage != null) await prefs.setString('imagePath', _profileImage!.path);

    if (!mounted) return;
    Navigator.pop(context); // Go back to Display Page or Dashboard
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Updated"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Account"), backgroundColor: kPrimaryColor),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final XFile? i = await _picker.pickImage(source: ImageSource.gallery);
                if (i != null) setState(() => _profileImage = File(i.path));
              },
              child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  backgroundColor: Colors.grey[300],
                  child: _profileImage == null ? const Icon(Icons.camera_alt, color: Colors.grey) : null
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(child: Text("Tap to change photo", style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 25),

          _buildEditField("Full Name", nameC),
          _buildEditField("Email Address", emailC),
          _buildEditField("Phone Number", phoneC),
          _buildEditField("Date of Birth", dobC),
          _buildEditField("Address", addressC),
          _buildEditField("Emergency Contact", emergencyC),
          _buildEditField("Medical Conditions", condC),

          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saveData,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextLight),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kPrimaryColor, width: 2)),
        ),
      ),
    );
  }
}