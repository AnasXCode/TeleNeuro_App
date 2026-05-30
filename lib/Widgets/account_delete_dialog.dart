import 'package:flutter/material.dart';

/// Shows a confirmation dialog requiring the user to type DELETE.
Future<bool> confirmAccountDeletion(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete account?', style: TextStyle(color: Colors.red)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently removes your profile and signs you out. '
            'Appointment and medical records may remain per clinic policy.\n\n'
            'Type DELETE to confirm:',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'DELETE',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            if (controller.text.trim().toUpperCase() == 'DELETE') {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Delete account', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  controller.dispose();
  return result == true;
}
