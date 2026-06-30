import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/notification_service.dart';
import '../../Widgets/profile_avatar.dart';

class ConsultDoctorPage extends StatefulWidget {
  // ✅ 1. Yahan humne parameters add kiye taake Dashboard se Data le sakein
  final String doctorId;
  final String doctorName;

  const ConsultDoctorPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<ConsultDoctorPage> createState() => _ConsultDoctorPageState();
}

class _ConsultDoctorPageState extends State<ConsultDoctorPage> {
  // Controllers
  final TextEditingController _problemController = TextEditingController();

  // Date and Time Variables
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  // Colors
  final Color kPrimaryColor = const Color(0xFF1565C0);

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  // --- DATE PICKER ---
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- TIME PICKER ---
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // --- BOOK APPOINTMENT FUNCTION (UPDATED LOGIC) ---
  Future<void> _bookAppointment() async {
    // 1. Validation
    if (_selectedDate == null ||
        _selectedTime == null ||
        _problemController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details (Date, Time, Problem)'),
        ),
      );
      return;
    }

    // ✅ Linter Fix: Context aur formatting variables ko await se pehle capture kar liya
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final String formattedTime = _selectedTime!.format(context);
    final String formattedDate =
        "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}";

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ---------------------------------------------------------
      // ✅ STEP 1: CHECK KARO KE PEHLE SE KOI ACTIVE APPOINTMENT HAI?
      // ---------------------------------------------------------
      QuerySnapshot existingAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.uid)
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      bool hasActiveSession = false;
      String statusMessage = "";

      for (var doc in existingAppointments.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';

        // Agar 'Pending' hai to Patient ko bolo Intezar kare
        if (status == 'Pending') {
          hasActiveSession = true;
          statusMessage = "Request already sent! Please wait for approval.";
          break;
        }
        // Agar 'Accepted' hai to bolo Chat mein baat kare
        else if (status == 'Accepted') {
          hasActiveSession = true;
          statusMessage =
              "You already have an active session. Please check 'Messages'.";
          break;
        }
      }

      // Agar Active Session mila, to yahi rok do
      if (hasActiveSession) {
        if (mounted) {
          setState(() => _isLoading = false); // Loading band
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(statusMessage),
            backgroundColor: Colors.orange,
          ),
        );
        return; // ❌ Code yahan ruk jayega, booking nahi hogi
      }

      // ---------------------------------------------------------
      // ✅ STEP 2: AGAR KOI MASLA NAHI, TO BOOKING KARO
      // ---------------------------------------------------------

      // Patient ka naam fetch karna
      String patientName = "Unknown Patient";
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        patientName = userDoc['name'] ?? "Patient";
      }

      // Firestore mein Save karna
      final appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add({
            'patientId': user.uid,
            'patientName': patientName,
            'doctorId': widget.doctorId,
            'doctorName': widget.doctorName,
            'problem': _problemController.text.trim(),
            'date': formattedDate,
            'time': formattedTime,
            'status': 'Pending', // Shuru mein Pending rahega
            'timestamp': FieldValue.serverTimestamp(),
          });

      await NotificationService.notifyAppointmentBooked(
        doctorId: widget.doctorId,
        patientId: user.uid,
        patientName: patientName,
        appointmentId: appointmentRef.id,
        date: formattedDate,
        time: formattedTime,
      );

      // Success Message
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Appointment Request Sent!'),
          backgroundColor: Colors.green,
        ),
      );

      nav.pop(); // Wapis Dashboard par chale jayen
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Book Dr. ${widget.doctorName}",
        ), // ✅ Doctor ka naam Header mein
        backgroundColor: kPrimaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  ProfileAvatar(
                    userId: widget.doctorId,
                    radius: 40,
                    fallbackIcon: Icons.medical_services,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dr. ${widget.doctorName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Consultation Details",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // Problem Input
            const Text(
              "Describe your problem",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _problemController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "E.g. I have a severe headache...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date Picker
            const Text(
              "Select Date",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null
                          ? "Choose Date"
                          : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                      style: TextStyle(
                        color: _selectedDate == null
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Time Picker
            const Text(
              "Select Time",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTime == null
                          ? "Choose Time"
                          : _selectedTime!.format(context),
                      style: TextStyle(
                        color: _selectedTime == null
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
                    const Icon(Icons.access_time, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Book Appointment",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
