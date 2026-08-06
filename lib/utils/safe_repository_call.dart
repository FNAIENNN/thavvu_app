import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Runs a repository operation with consistent success/error snackbars.
///
/// Replaces the fire-and-forget + empty-catch pattern that hid every
/// backend failure. Returns the operation result or null on error.
Future<T?> safeRepositoryCall<T>({
  required Future<T> Function() operation,
  required BuildContext context,
  required String successMessage,
  String? errorPrefix,
}) async {
  try {
    final result = await operation();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return result;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${errorPrefix ?? 'Error'}: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
    }
    return null;
  }
}

/// Non-UI variant of [safeRepositoryCall] for services (no snackbar).
Future<T?> safeCall<T>({
  required Future<T> Function() operation,
  void Function(Object error)? onError,
}) async {
  try {
    return await operation();
  } catch (e) {
    onError?.call(e);
    return null;
  }
}
