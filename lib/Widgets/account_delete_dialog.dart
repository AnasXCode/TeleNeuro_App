import 'package:flutter/material.dart';

import '../services/account_deletion_service.dart';
import 'auth_root_screen.dart';

/// Password-only confirmation for account deletion.
Future<String?> promptAccountDeletionPassword(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _PasswordDeleteDialog(),
  );
}

class _PasswordDeleteDialog extends StatefulWidget {
  const _PasswordDeleteDialog();

  @override
  State<_PasswordDeleteDialog> createState() => _PasswordDeleteDialogState();
}

class _PasswordDeleteDialogState extends State<_PasswordDeleteDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.trim().isEmpty) {
      setState(() => _errorText = 'Enter your password to continue.');
      return;
    }
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account?', style: TextStyle(color: Colors.red)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your password to permanently delete your account. '
              'This cannot be undone.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Password',
                errorText: _errorText,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _submit,
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void _showDeletionProgress(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting account…'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _hideDeletionProgress(BuildContext context) {
  final root = Navigator.of(context, rootNavigator: true);
  if (root.canPop()) root.pop();
}

/// Password prompt → delete → dismiss loading → redirect or show error.
///
/// When [stackRoot] is provided, the stack becomes `[stackRoot, destination]` so
/// Back from [destination] returns to the app entry screen instead of a blank route.
Future<void> performAccountDeletion({
  required BuildContext context,
  required Widget destination,
  Widget? stackRoot,
}) async {
  final password = await promptAccountDeletionPassword(context);
  if (password == null || !context.mounted) return;

  _showDeletionProgress(context);

  String? error;
  try {
    error = await AccountDeletionService.deleteCurrentAccount(password: password);
  } catch (e) {
    error = 'Could not delete account. Please try again.';
  } finally {
    if (context.mounted) _hideDeletionProgress(context);
  }

  if (!context.mounted) return;

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.orange),
    );
    return;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  if (stackRoot != null) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => stackRoot),
      (_) => false,
    );
    navigator.push(
      MaterialPageRoute(builder: (_) => destination),
    );
  } else {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthRootScreen(child: destination)),
      (_) => false,
    );
  }
}
