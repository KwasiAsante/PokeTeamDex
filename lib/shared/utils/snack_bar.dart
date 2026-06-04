import 'package:flutter/material.dart';

/// Show a floating snackbar, clearing any queued snackbars first to avoid
/// stacking. Pass [isError] to use the error colour scheme.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  final colorScheme = Theme.of(context).colorScheme;

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: isError
            ? TextStyle(color: colorScheme.onErrorContainer)
            : null,
      ),
      backgroundColor: isError ? colorScheme.errorContainer : null,
      behavior: SnackBarBehavior.floating,
      action: action,
    ),
  );
}
