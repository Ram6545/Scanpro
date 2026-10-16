import 'package:flutter/material.dart';
import 'package:scanpro/core/errors/app_exception.dart';

/// Centralized utility for converting exceptions into user-friendly messages
/// and presenting consistent Material 3 feedback without leaking document data.
class ErrorHandler {
  ErrorHandler._();

  /// Maps any [error] into a user-friendly string.
  static String toUserMessage(Object error) {
    if (error is AppException) {
      return error.userMessage;
    }
    return 'An unexpected error occurred. Please try again.';
  }

  /// Displays a floating Material 3 error SnackBar on the active [BuildContext].
  static void showErrorSnackBar(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    final theme = Theme.of(context);
    final message = toUserMessage(error);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.errorContainer,
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: theme.colorScheme.onErrorContainer,
                  onPressed: onRetry,
                )
              : null,
        ),
      );
  }

  /// Displays a floating Material 3 success SnackBar on the active [BuildContext].
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.secondaryContainer,
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

