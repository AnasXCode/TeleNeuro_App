# 🧠 TeleNeuro

<p align="center">
  <b>AI-Powered Telemedicine Platform for Early Alzheimer's Detection</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Supabase-Storage-3ECF8E?logo=supabase&logoColor=white" />
  <img src="https://img.shields.io/badge/AI%20Model-ViT--B%2F16-orange" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
</p>

---

## 📖 Overview

**TeleNeuro** is a full-stack Flutter telemedicine application that connects **patients** and **neurologists**, combined with an **on-device AI diagnostic engine** for early Alzheimer's detection from brain MRI scans.

The app runs a fine-tuned **Vision Transformer (ViT-B/16)** model — converted to TFLite and bundled directly into the app — so MRI classification happens **entirely on-device**, without sending medical images to any external inference server.

Patients can upload an MRI scan, receive an instant AI-generated diagnosis report (PDF), book appointments with doctors, chat in real time, and securely share their reports — all within one app.

---

## ✨ Features

### 👤 Patient Side
- Secure sign-up / login (Gmail-restricted email validation, 18+ age gate)
- Browse & search doctors by specialization, sorted by rating
- Book appointments with date/time picker + problem description
- Real-time chat with doctors after appointment acceptance
- **AI MRI Diagnosis** — upload a scan, get instant stage classification + confidence score
- Auto-generated PDF diagnostic report, saved to personal **Lab Reports** library
- Share MRI reports selectively with doctors (only those with an accepted appointment)
- In-app notifications (bookings, messages, session updates, shared reports)
- Editable profile with photo upload (Supabase-backed)
- Secure account deletion with password re-authentication

### 🩺 Doctor Side
- Separate doctor registration flow (specialization, qualification, hospital, experience)
- Dashboard with live stats: total patients, pending requests, rating, experience
- Accept / decline appointment requests in real time
- Dedicated chat inbox per patient, with "End Session" and delete conversation controls
- View shared MRI reports & clinical summaries from linked patients
- "My Patients" directory built from appointment history
- Patient reviews & ratings section on public profile
- In-app doctor guide / FAQ

### 🔐 Shared / Core
- Dual-role authentication routing (Patient vs Doctor) via Firestore role checks
- Firestore-backed real-time notification engine (deduplicated per event)
- Appointment-scoped chat with visibility rules (auto-hides chat if either account is deleted)
- Reusable UI kit: searchable dropdowns, animated buttons, custom date pickers, badge icons

---

## 📸 Screenshots

<!-- Replace the paths below with your actual screenshot files, e.g. docs/screenshots/xyz.png -->

| Patient Dashboard | MRI Reports | Appointments |
|:---:|:---:|:---:|
| ![Patient Dashboard]<img width="720" height="1600" alt="patient_dashboard png" src="https://github.com/user-attachments/assets/e080490f-6c75-419e-91db-5a8c7b3b6280" />  |![Lab Report]<img width="720" height="1600" alt="Reports" src="https://github.com/user-attachments/assets/d52293f2-6f84-4055-96b2-4eda3eb73b47" /> |![Appointments]<img width="720" height="1600" alt="Appointments" src="https://github.com/user-attachments/assets/976fe406-76fa-4b53-bb63-7a609427aa40" />


| Doctor Dashboard | Doctor Profile | User Guide |
|:---:|:---:|:---:|
| ![Doctor Dashboard]<img width="720" height="1600" alt="doctor_dashboard png" src="https://github.com/user-attachments/assets/e186770d-218d-4e5b-bc04-e49d1aa5920b" />| ![Doctor Profile]<img width="720" height="1600" alt="doctor profile" src="https://github.com/user-attachments/assets/8404a1ed-0edf-4494-92da-3cf95df4dcba" />| ![User Guide]<img width="720" height="1600" alt="user guide" src="https://github.com/user-attachments/assets/f7b59a0b-f0b0-4b5f-9f00-ac6fbe145afa" />


---

## 🧠 AI Model

| | |
|---|---|
| **Architecture** | Vision Transformer — `ViT-B/16` (torchvision) |
| **Task** | 4-class classification: `NonDemented`, `VeryMildDemented`, `MildDemented`, `ModerateDemented` |
| **Training framework** | PyTorch (mixed-precision / AMP, early stopping) |
| **Datasets** | [Alzheimer's MRI Dataset](https://www.kaggle.com/datasets/aryanafzal/alzheimers-mri-dataset) + [OASIS Brain MRI Dataset](https://www.kaggle.com/datasets/ninadaithal/imagesoasis) |
| **Export pipeline** | PyTorch → ONNX (opset 14) → TFLite (via `ai-edge-torch`) |
| **On-device runtime** | `tflite_flutter` |
| **Input** | `224×224×3` RGB tensor, ImageNet-normalized |

**Preprocessing pipeline (must match training exactly):**
Resize(256) → CenterCrop(192) → Grayscale→RGB → Resize(224) → Normalize(ImageNet mean/std) → CHW

The full training/export notebook is documented in `final-fyp.ipynb`.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore (real-time) |
| File Storage | Supabase Storage (MRI PDFs, images, profile photos) |
| AI Inference | TensorFlow Lite (on-device) |
| PDF Generation | `pdf` package |
| State/Local Cache | `shared_preferences` |

---

## 📂 Project Structure
lib/
├── Splash/                     # Onboarding / splash screens
├── Profile Side/                # Role selection (Patient / Doctor)
├── Patient Side/
│   ├── Auth/                    # Patient login, signup, portal
│   ├── Screens/                 # Dashboard, appointments, chat, MRI upload, reports...
│   └── services/                # MRI report service
├── Doctor Side/
│   ├── Auth/                    # Doctor login, signup, portal
│   ├── Screens/                 # Dashboard, appointments, chat, patients, reports...
│   └── Widgets/                 # Doctor-specific cards
├── Widgets/                      # Shared reusable widgets (avatars, dropdowns, pickers...)
├── services/                     # Shared services (auth, notifications, validation...)
├── data/                         # Static option lists (specializations, qualifications)
├── firebase_options.dart
├── supabase_config.dart
└── main.dart
assets/
├── screen1.png ... screen4.jpg   # Onboarding illustrations
└── vit_fyp_direct.tflite         # AI model (NOT committed — see setup below)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.9.2`
- A Firebase project (Auth + Firestore enabled)
- A Supabase project (Storage bucket)

### 1. Clone the repository
```bash
git clone https://github.com/<your-username>/teleneuro.git
cd teleneuro
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
- Create a Firebase project → enable **Email/Password Auth** and **Firestore**.
- Run:
```bash
  flutterfire configure
```
  This regenerates `lib/firebase_options.dart` and `android/app/google-services.json` for your own project.

### 4. Configure Supabase
- Create a free project at [supabase.com](https://supabase.com).
- Create a **public Storage bucket** (default name used in this project: `mri-reports`).
- Run the SQL policies in [`supabase_mri_reports_storage.sql`](./supabase_mri_reports_storage.sql) inside the Supabase SQL Editor.
- Update `lib/supabase_config.dart` with your own Project URL and anon key:
```dart
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String supabaseBucket = 'mri-reports';
```

### 5. ⚠️ AI Model Setup (required — not included in this repo)

The `.tflite` model file is **too large for a normal Git push** (GitHub blocks files over 100MB), so it is hosted separately instead of being committed to this repository.

**Steps to set it up:**
1. Download the model file from:*(GitHub Release)*
2. Place the downloaded file at:
assets/vit_fyp_direct.tflite
3. Confirm it's registered in `pubspec.yaml` (already included in this repo):
```yaml
   flutter:
     assets:
       - assets/vit_fyp_direct.tflite
```
4. Run `flutter pub get` again, then rebuild the app.

> Model training and export details are documented in `final-fyp.ipynb`.

### 6. Run the app
```bash
flutter run
```

---

## 🔒 Security Notes

- Never commit real Firebase/Supabase keys to a public repository — use environment-specific config or `--dart-define` for production.
- Firestore & Storage rules should restrict read/write access appropriately before going to production (this project uses permissive `anon` policies for development — see `supabase_mri_reports_storage.sql`).

---



## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Malik Anas Ahmed**
📧 anasahmed.appdev@gmail.com
🔗 [LinkedIn](www.linkedin.com/in/malikanasahmed) 

---

<p align="center">Made with ❤️ using Flutter, Firebase, Supabase & PyTorch</p>
