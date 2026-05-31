import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color _kPrimary = Color(0xFF1565C0);

/// Profile photo from Firestore [userId], direct [photoUrl], and/or local [localFile].
class ProfileAvatar extends StatelessWidget {
  final String? userId;
  final String? photoUrl;
  final File? localFile;
  final double radius;
  final IconData fallbackIcon;

  const ProfileAvatar({
    super.key,
    this.userId,
    this.photoUrl,
    this.localFile,
    this.radius = 52,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    // Local variable banaya taake Dart safely type promotion kar sake
    final uid = userId;

    if (uid != null && uid.trim().isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          final fromDb = snap.data?.data()?['photoUrl'] as String?;
          return _buildAvatar(
            photoUrl: fromDb ?? photoUrl,
            localFile: localFile,
          );
        },
      );
    }
    return _buildAvatar(photoUrl: photoUrl, localFile: localFile);
  }

  Widget _buildAvatar({String? photoUrl, File? localFile}) {
    final url = photoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE3F2FD),
        child: ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            // Linter fix: Underscores ki jagah proper parameters pass kiye
            errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: radius, color: _kPrimary),
          ),
        ),
      );
    }

    // Linter fix: localFile check hone ke baad '!' lagane ki zaroorat nahi
    if (localFile != null && localFile.existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE3F2FD),
        backgroundImage: FileImage(localFile),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE3F2FD),
      child: Icon(fallbackIcon, size: radius, color: _kPrimary),
    );
  }
}