import 'package:flutter/material.dart';

import '../models/app_release.dart';
import '../providers/app_controller.dart';
import 'app_snack_bar.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppController app,
  AppRelease release,
) async {
  final notes = release.body.trim();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('发现新版本'),
      content: SingleChildScrollView(
        child: Text(
          notes.isEmpty
              ? '${release.name}\n${release.tagName}'
              : notes.length > 800
              ? '${notes.substring(0, 800)}…'
              : notes,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              await app.openRelease(release);
            } catch (error) {
              if (context.mounted) {
                showAppSnackBar(
                  context,
                  error.toString(),
                  type: AppSnackBarType.error,
                );
              }
            }
          },
          child: const Text('前往下载'),
        ),
      ],
    ),
  );
}
