import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

/// Uploads profile photos to Supabase and stores public URL on the user document.
class ProfileImageService {
  static Future<String?> uploadAndSaveProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final storage = Supabase.instance.client.storage.from(SupabaseConfig.supabaseBucket);
      final path = 'profiles/$userId.jpg';

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final photoUrl = storage.getPublicUrl(path);

      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'photoUrl': photoUrl, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      return photoUrl;
    } catch (e) {
      debugPrint('ProfileImageService.upload failed: $e');
      return null;
    }
  }
}
