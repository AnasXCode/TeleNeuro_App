# 🧠 TeleNeuro: AI-Powered Alzheimer's Disease Detection

![TeleNeuro Banner]([Insert_Banner_Image_Link_Here_Optional])

TeleNeuro is a comprehensive, cross-platform mobile healthcare application designed for the early detection and management of Alzheimer's Disease. Leveraging state-of-the-art **Hierarchical Vision Transformers (Swin & ConvNeXt)**, the system analyzes MRI scans to classify the disease into four stages with over 98% accuracy. 

The platform bridges the gap between high-quality AI research and clinical healthcare by providing a seamless, real-time diagnostic ecosystem for both patients and medical professionals.

---

## ✨ Key Features

### 🧑‍⚕️ For Patients
* **Smart MRI Analysis:** Upload an MRI scan directly from the mobile device and receive an instant, accurate AI diagnosis.
* **Specialist Connection:** Browse top neurologists, psychiatrists, and radiologists to book online consultations.
* **Secure Reports:** Auto-generate PDF diagnostic reports and securely share them with doctors.
* **Real-time Chat:** Communicate directly with medical professionals regarding symptoms and reports.

### 🩺 For Doctors
* **Patient History & Reports:** Access an organized dashboard to review patient histories, MRI reports, and AI confidence scores.
* **Appointment Management:** Accept, decline, and manage upcoming virtual consultations.
* **Clinical Notes:** Add consultation notes directly to the patient's record.

---

## 🛠️ Technology Stack

* **Frontend:** Flutter (Dart) for cross-platform Android/iOS application.
* **Backend & Database:** Firebase (Authentication, Cloud Firestore).
* **AI & Machine Learning:** Python, PyTorch, `timm` (PyTorch Image Models).
* **On-Device Inference:** TensorFlow Lite (`tflite_flutter`).
* **Model Architectures Evaluated:** Vision Transformer (ViT-Base), Swin Transformer (Swin-Tiny), ConvNeXt-Tiny.

---

## 📥 Installation & Setup Guide

### Prerequisites
* Flutter SDK (Version 3.10+)
* Android Studio / VS Code
* A Firebase Project (with Authentication and Firestore enabled)

### Step 1: Clone the Repository
```bash
git clone [https://github.com/your-username/TeleNeuro.git](https://github.com/your-username/TeleNeuro.git)
cd TeleNeuro

### Step 2: Configure Firebase
Create a project in the Firebase Console.

Register your Android and iOS apps.

Download the google-services.json (for Android) and GoogleService-Info.plist (for iOS) and place them in their respective directories.

Enable Email/Password Authentication and Cloud Firestore in your Firebase console.

Step 3: Download & Add the AI Model ⚠️
Due to GitHub's file size limits, the trained AI model is not included directly in the source code. Please follow these steps to integrate it:

Download the Model: Download the pre-trained model.tflite file from our releases page:
👉 [Link to GitHub Releases / Google Drive / Hugging Face]

Place the Model: Navigate to the assets/ folder in the project directory and place the downloaded .tflite file there. (Create the assets folder if it does not exist).
TeleNeuro/
├── assets/
│   ├── model.tflite  <-- Place it here
│   ├── screen1.png
│   └── ...
Update Pubspec: Ensure your pubspec.yaml has the assets properly linked:

YAML
flutter:
  assets:
    - assets/
    - assets/model.tflite
Step 4: Install Dependencies & Run
Bash
flutter pub get
flutter run

📸 ScreenshotsPatient DashboardMRI Upload & AI DiagnosisDoctor DashboardDoctor Appointment

📊 AI Model Performance
The AI engine was trained on an augmented dataset of over 40,000 MRI scans. Three architectures were evaluated:

ConvNeXt-Tiny: ~99.00% Accuracy (Fastest Inference)

Swin Transformer (Swin-Tiny): 98.52% Accuracy (Excellent global/local context)

Vision Transformer (ViT-Base): 75.00% Accuracy

The deployed mobile application utilizes the optimized Swin/ConvNeXt model quantized to TFLite for rapid, on-device inference without compromising patient data privacy.

👨‍💻 Author
Malik Anas Ahmed - Mobile Application Lead (Flutter UI/UX, Firebase Integration, System Logic, AI & Backend Lead Model Training, Preprocessing, Deployment Integration)
