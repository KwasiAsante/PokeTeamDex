import 'package:flutter/material.dart';

/// Show a floating snackbar, clearing any queued snackbars first to avoid
/// stacking. Pass [isError] to use the error colour scheme. A "Dismiss" action
/// is shown by default unless [action] is provided.
///
/// Duration auto-selects based on content: errors and messages longer than
/// 60 characters show for 4 seconds; short info messages show for 2 seconds.
/// Override with [duration] when needed.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  SnackBarAction? action,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  final colorScheme = Theme.of(context).colorScheme;

  final resolvedAction = action ??
      SnackBarAction(
        label: 'Dismiss',
        onPressed: messenger.hideCurrentSnackBar,
      );

  final resolvedDuration = duration ??
      (isError || message.length > 60
          ? const Duration(seconds: 4)
          : const Duration(seconds: 1));

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
      duration: resolvedDuration,
      // Flutter 3.37+ changed the default so that a SnackBar with an action
      // no longer auto-dismisses (persist defaults to null → persistent when
      // action is present). persist: false restores auto-dismiss behaviour.
      persist: false,
      action: resolvedAction,
    ),
  );
}
