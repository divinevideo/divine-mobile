// ABOUTME: Dialog widgets for account deletion flow
// ABOUTME: Warning dialog with confirmation and completion dialog with next steps

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Show warning dialog for removing keys from device only
Future<void> showRemoveKeysWarningDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        '⚠️ Remove Keys from Device?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'This will:\n'
        '• Remove your Nostr private key (nsec) from this device\n'
        '• Sign you out immediately\n'
        '• Your content will REMAIN on Nostr relays\n\n'
        'Make sure you have your nsec backed up elsewhere or you will lose access to your account!\n\n'
        'Continue?',
        style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            context.pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Remove Keys',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Show FIRST warning dialog before deleting all content from relays
Future<void> showDeleteAllContentWarningDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        '🚨 DELETE ALL CONTENT?',
        style: TextStyle(
          color: Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'WARNING: This action is PERMANENT and CANNOT be undone!\n\n'
        'This will:\n'
        '• Request deletion of ALL your content from Nostr relays\n'
        '• Delete all your videos, profile, likes, and activity\n'
        '• Remove your keys from this device\n'
        '• Sign you out immediately\n\n'
        'Some relays may not honor deletion requests, and content may still exist in archives.\n\n'
        'This is IRREVERSIBLE. Are you ABSOLUTELY CERTAIN?',
        style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            context.pop();
            // Show second confirmation dialog
            _showDeleteAllContentFinalConfirmation(
              context: context,
              onConfirm: onConfirm,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Continue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Show SECOND confirmation dialog before deleting all content (requires typing)
Future<void> _showDeleteAllContentFinalConfirmation({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  final confirmationController = TextEditingController();
  const requiredText = 'DELETE';

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          '⚠️ Final Confirmation',
          style: TextStyle(
            color: Colors.red,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To confirm permanent deletion of ALL your content from Nostr relays, type:',
              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              requiredText,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmationController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type here',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: confirmationController.text == requiredText
                ? () {
                    context.pop();
                    onConfirm();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade800,
              disabledForegroundColor: Colors.grey,
            ),
            child: const Text(
              'DELETE ALL MY CONTENT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Show completion dialog after account deletion
Future<void> showDeleteAccountCompletionDialog({
  required BuildContext context,
  required VoidCallback onCreateNewAccount,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        '✓ Account Deleted',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'Your deletion request has been sent to Nostr relays.\n\n'
        'You\'ve been signed out and your keys have been removed from this device.',
        style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            context.pop();
            onCreateNewAccount();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Create New Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
