import 'package:flutter/material.dart';
import '../core/data/hesak_connection.dart';
import 'hesak_confirm_dialog.dart';

// =====================================================================
//  INTERNET REQUIRED — listening, the mic and sending text need internet.
//
//  Use it before the action:
//    if (!await hesakRequireInternet(context)) return;
//
//  Connected     -> returns true right away (no window).
//  Not connected -> shows the shared window (one button "حسنًا")
//                   and returns false (nothing happens).
// =====================================================================

/// true = connected to the internet.
Future<bool> hesakRequireInternet(BuildContext context) async {
  if (await HesakConnection.instance.checkNow()) return true;
  if (!context.mounted) return false;

  await showHesakNoticeDialog(
    context,
    title: 'لا يوجد اتصال بالإنترنت',
    message: 'شغّل الإنترنت أولًا ثم حاول مرة أخرى',
    icon: Icons.wifi_off_rounded,
  );
  return false;
}