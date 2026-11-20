import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/responsive.dart';

/// Shows [form] as a dialog on web and a bottom sheet on mobile, in the
/// light sage theme. Used by every add / edit form.
Future<void> showAppForm(BuildContext context, Widget form) async {
  if (Responsive.isWeb(context)) {
    await showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: Dialog(
          backgroundColor: AppColors.pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: form,
            ),
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: form,
          ),
        ),
      ),
    );
  }
}

bool _saving = false;

/// Runs a save, returning true if it worked. A slow save shows a spinner that
/// blocks the screen, and a refusal is shown in a dialog so it appears above
/// any open form, leaving what was typed in place to correct.
Future<bool> runSave(BuildContext context, Future<void> Function() save) async {
  if (_saving) return false; // A second tap while the first is still saving.
  _saving = true;

  final navigator = Navigator.of(context, rootNavigator: true);
  var spinnerShown = false;
  final spinner = Timer(const Duration(milliseconds: 300), () {
    spinnerShown = true;
    showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: AppColors.pureWhite)),
      ),
    );
  });

  String? problem;
  var sessionEnded = false;
  try {
    await save();
  } on ApiException catch (error) {
    problem = error.message;
    sessionEnded = error.code == 'SESSION_ENDED';
  } catch (error, stack) {
    debugPrint('Save failed: $error\n$stack');
    problem = 'Something went wrong. Please try again.';
  }

  spinner.cancel();
  _saving = false;
  // After a sign-in ends the app has already gone to the login screen.
  if (sessionEnded) return false;
  if (spinnerShown && navigator.mounted) navigator.pop();

  if (problem != null && navigator.mounted) {
    await showDialog<void>(
      context: navigator.context,
      builder: (context) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          key: const ValueKey('save-problem'),
          backgroundColor: AppColors.pureWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Text(problem!),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      ),
    );
  }
  return problem == null;
}

/// Floating snackbar in the brand color, narrower on web.
void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.brandDark,
      width: Responsive.isWeb(context) ? 420 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(message, style: const TextStyle(color: Colors.white)),
    ),
  );
}
