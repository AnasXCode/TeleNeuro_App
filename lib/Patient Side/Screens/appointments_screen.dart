import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Widgets/profile_avatar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text(
          "Remove all Completed and Declined appointments from your list?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // ✅ Linter Fix: Navigator capture
              final nav = Navigator.of(dialogContext);

              if (user == null) {
                nav.pop();
                return;
              }

              QuerySnapshot snapshot = await FirebaseFirestore.instance
                  .collection('appointments')
                  .where('patientId', isEqualTo: user!.uid)
                  .where(
                    'status',
                    whereIn: ['Completed', 'Declined', 'Cancelled'],
                  )
                  .get();

              WriteBatch batch = FirebaseFirestore.instance.batch();
              for (var doc in snapshot.docs) {
                batch.update(doc.reference, {'patientDeleted': true});
              }

              await batch.commit();

              nav.pop(); // Safe usage after await
            },
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating(
    String appointmentId,
    String doctorId,
    double newRating,
    String reviewText,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final doctorRef = firestore.collection('users').doc(doctorId);
    final appointmentRef = firestore
        .collection('appointments')
        .doc(appointmentId);

    String patientName = "Patient";
    var userDoc = await firestore.collection('users').doc(user!.uid).get();
    if (userDoc.exists) {
      patientName = userDoc.data()?['name'] ?? "Patient";
    }

    await firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(doctorRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      double oldRating = (data['rating'] ?? 4.5).toDouble();
      int totalReviews = (data['totalReviews'] ?? 0).toInt();

      double newAverage =
          ((oldRating * totalReviews) + newRating) / (totalReviews + 1);

      transaction.update(doctorRef, {
        'rating': double.parse(newAverage.toStringAsFixed(1)),
        'totalReviews': totalReviews + 1,
      });
    });

    await appointmentRef.update({
      'isRated': true,
      'givenRating': newRating,
      'reviewText': reviewText,
      'patientName': patientName,
      'promptDismissed': true,
    });
  }

  void _showRatingDialog(
    BuildContext context,
    String appointmentId,
    String doctorId,
    String doctorName,
  ) {
    // ✅ Linter Fix: Removed underscores for local variables
    double currentRating = 5.0;
    TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            "Rate Dr. $doctorName",
            style: const TextStyle(color: Color(0xFF1565C0)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("How was your experience?"),
                const SizedBox(height: 10),
                Slider(
                  value: currentRating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: Colors.amber,
                  onChanged: (val) => setDialogState(() => currentRating = val),
                ),
                Text(
                  "${currentRating.toInt()} Stars",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: reviewController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "Feedback (Optional)...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
              ),
              onPressed: () async {
                // ✅ Linter Fix: Captured variables before await
                final nav = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                await _submitRating(
                  appointmentId,
                  doctorId,
                  currentRating,
                  reviewController.text,
                );

                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text("Rating Submitted!")),
                );
              },
              child: const Text(
                "Submit",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "My Appointments",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1565C0),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Please Login to view appointments"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('patientId', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(child: Text("No appointments found."));

                var visibleDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['patientDeleted'] != true;
                }).toList();

                // ✅ MULTI-LEVEL SORTING LOGIC: Priority + Latest First
                visibleDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;

                  int getPriority(String status) {
                    if (status == 'Accepted') return 1; // Priority 1: Ongoing
                    if (status == 'Pending') return 2; // Priority 2: In Wait
                    if (status == 'Completed') return 3; // Priority 3: Done
                    return 4; // Priority 4: Declined/Cancelled
                  }

                  int pA = getPriority(dataA['status'] ?? 'Pending');
                  int pB = getPriority(dataB['status'] ?? 'Pending');

                  if (pA != pB) {
                    // Priority mukhtalif hai toh priority ke hisab se sort karo
                    return pA.compareTo(pB);
                  } else {
                    // Priority same hai toh TIME check karo (Latest pehle)
                    Timestamp? timeA =
                        dataA['completedAt'] ?? dataA['createdAt'];
                    Timestamp? timeB =
                        dataB['completedAt'] ?? dataB['createdAt'];

                    if (timeA != null && timeB != null) {
                      return timeB.compareTo(timeA); // Descending order
                    } else if (timeA != null) {
                      return -1;
                    } else if (timeB != null) {
                      return 1;
                    }
                    return 0;
                  }
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: visibleDocs.length,
                  itemBuilder: (context, index) {
                    var data =
                        visibleDocs[index].data() as Map<String, dynamic>;
                    String appointmentId = visibleDocs[index].id;
                    String status = data['status'] ?? 'Pending';
                    bool isRated = data['isRated'] ?? false;
                    bool ratingExpired = data['ratingExpired'] ?? false;

                    Color statusColor = Colors.orange;
                    if (status == 'Accepted') statusColor = Colors.green;
                    if (status == 'Completed') statusColor = Colors.blue;
                    if (status == 'Declined' || status == 'Cancelled')
                      statusColor = Colors.red;

                    // ✅ STRICT 5-MINUTE CHECK FOR THE BUTTON
                    bool showRateButton = false;
                    if (status == 'Completed' && !isRated && !ratingExpired) {
                      Timestamp? completedAt = data['completedAt'];
                      if (completedAt != null) {
                        int mins = DateTime.now()
                            .difference(completedAt.toDate())
                            .inMinutes;
                        if (mins >= 5) {
                          ratingExpired = true;
                          FirebaseFirestore.instance
                              .collection('appointments')
                              .doc(appointmentId)
                              .update({'ratingExpired': true});
                        } else {
                          showRateButton = true;
                        }
                      } else {
                        showRateButton = true;
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            leading: ProfileAvatar(
                              userId: (data['doctorId'] ?? '').toString(),
                              radius: 24,
                              fallbackIcon: Icons.medical_services,
                            ),
                            title: Text(
                              "Dr. ${data['doctorName'] ?? 'Unknown'}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${data['date']} at ${data['time']}"),
                                Text("Issue: ${data['problem'] ?? '-'}"),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                // ✅ Linter Fix: withOpacity replaced by withValues
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          if (showRateButton)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () => _showRatingDialog(
                                    context,
                                    appointmentId,
                                    data['doctorId'],
                                    data['doctorName'],
                                  ),
                                  icon: const Icon(
                                    Icons.star_outline,
                                    color: Colors.amber,
                                  ),
                                  label: const Text(
                                    "Rate Your Visit (Limited Time)",
                                    style: TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          if (status == 'Completed' && isRated)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    "Feedback Submitted",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (status == 'Completed' &&
                              !isRated &&
                              ratingExpired)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_off,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    "Rating Time Expired",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
