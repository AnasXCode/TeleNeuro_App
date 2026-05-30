import 'package:flutter/material.dart';

import 'notifications_screen.dart';

/// Notifications tab body with header and Mark all read.
class TabNotificationsScreen extends StatelessWidget {
  const TabNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotificationsScreen(embeddedInTab: true);
  }
}
