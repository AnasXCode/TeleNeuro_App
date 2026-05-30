import 'package:flutter/material.dart';

/// Bottom navigation icon with a numeric badge driven by [countStream].
class BottomNavBadgeIcon extends StatelessWidget {
  final IconData icon;
  final Stream<int> countStream;

  const BottomNavBadgeIcon({
    super.key,
    required this.icon,
    required this.countStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
          child: Icon(icon),
        );
      },
    );
  }
}
