// Matches android/app/google-services.json — use `flutterfire configure` to regenerate.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is only configured for Android in this project.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBL8LmdqlfNh04hFfvxTtxM1C2BTFGJTs8',
    appId: '1:94262807656:android:3d765a185d6bfae7e33fdd',
    messagingSenderId: '94262807656',
    projectId: 'telenuro',
    storageBucket: 'telenuro.firebasestorage.app',
  );
}
