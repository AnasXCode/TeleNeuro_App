import 'package:flutter/material.dart';

/// Prevents back navigation past this screen (e.g. after account deletion).
class AuthRootScreen extends StatelessWidget {
  final Widget child;

  const AuthRootScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: child,
    );
  }
}

/// Clears the entire navigation stack and sets [destination] as the only route.
void navigateToAuthRoot(BuildContext context, Widget destination) {
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => AuthRootScreen(child: destination)),
    (_) => false,
  );
}
