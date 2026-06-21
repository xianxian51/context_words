import 'package:flutter/material.dart';

enum AppSnackBarType { info, success, error }

void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarType type = AppSnackBarType.info,
}) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final colorScheme = Theme.of(context).colorScheme;
  final backgroundColor = switch (type) {
    AppSnackBarType.error => colorScheme.errorContainer,
    AppSnackBarType.success => colorScheme.primaryContainer,
    AppSnackBarType.info => colorScheme.inverseSurface,
  };
  final foregroundColor = switch (type) {
    AppSnackBarType.error => colorScheme.onErrorContainer,
    AppSnackBarType.success => colorScheme.onPrimaryContainer,
    AppSnackBarType.info => colorScheme.onInverseSurface,
  };
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: type == AppSnackBarType.error ? 3 : 2),
      backgroundColor: backgroundColor,
      showCloseIcon: type == AppSnackBarType.error,
      closeIconColor: foregroundColor,
    ),
  );
}
