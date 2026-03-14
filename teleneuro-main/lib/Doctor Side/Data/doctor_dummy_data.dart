// Doctor Side Dummy Data

// 1. Dashboard Statistics
final Map<String, String> dashboardStats = {
  "patients": "1.2k",
  "experience": "12 Yrs",
  "rating": "4.9",
  "reviews": "250+",
  "pending": "5", // Pending Appointments
};

// 2. Pending Appointment Requests
final List<Map<String, String>> pendingRequests = [
  {
    "name": "Ali Khan",
    "age": "45",
    "issue": "Memory Loss Issues",
    "time": "Today, 04:00 PM",
    "image": "assets/patient1.jpg",
    "status": "New"
  },
  {
    "name": "Sara Ahmed",
    "age": "62",
    "issue": "MRI Report Review",
    "time": "Tomorrow, 11:00 AM",
    "image": "assets/patient2.jpg",
    "status": "Urgent"
  },
  {
    "name": "Kamran Ullah",
    "age": "55",
    "issue": "Dementia Stage 1",
    "time": "Wed, 02:00 PM",
    "image": "assets/patient3.jpg",
    "status": "New"
  },
];

// 3. Upcoming/Confirmed Appointments
final List<Map<String, String>> upcomingAppointments = [
  {
    "name": "Usman Ghani",
    "age": "70",
    "issue": "Alzheimer Stage 2 Checkup",
    "time": "Today, 02:30 PM",
    "date": "20 Oct, 2025",
    "type": "Video Call"
  },
  {
    "name": "Fatima Bibi",
    "age": "68",
    "issue": "Routine Checkup",
    "time": "Today, 05:00 PM",
    "date": "20 Oct, 2025",
    "type": "Clinic Visit"
  },
];

// 4. Patient History List
final List<Map<String, String>> myPatients = [
  {"name": "Ahmed Ali", "age": "45", "condition": "Mild MCI", "lastVisit": "2 days ago"},
  {"name": "Zainab Bibi", "age": "60", "condition": "Alzheimer's", "lastVisit": "1 week ago"},
  {"name": "Tahir Shah", "age": "55", "condition": "Parkinson's", "lastVisit": "3 weeks ago"},
  {"name": "Hina Khan", "age": "50", "condition": "Migraine", "lastVisit": "1 month ago"},
];