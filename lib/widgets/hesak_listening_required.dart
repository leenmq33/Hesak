import 'package:flutter/material.dart';
import '../core/data/hesak_mode_store.dart';
import 'hesak_confirm_dialog.dart';
import 'hesak_internet_required.dart';

// =====================================================================
//  LISTENING REQUIRED — conversations work only while the big listen
//  button (الرئيسية) is on.
//
//  Use it before starting / using a conversation:
//    if (!await hesakRequireListening(context)) return;
//
//  Listening already on  -> returns true right away (no window).
//  Listening off         -> shows the shared HesakConfirmDialog:
//      "تشغيل الاستماع" -> checks the internet, then turns listening on
//                          and returns true (no internet -> window, false)
//      "إلغاء" / outside -> returns false (nothing happens)
// =====================================================================

/// true = listening is on (or the user just turned it on from the window).
Future<bool> hesakRequireListening(BuildContext context) async {
  if (HesakModeStore.instance.isListening) return true;

  final bool shouldTurnOn = await showHesakConfirmDialog(
    context,
    title: 'يجب تشغيل زر الاستماع أولًا',
    message: 'شغّل زر الاستماع في أعلى الصفحة الرئيسية لتتمكن من تحويل الكلام إلى نص',
    confirmLabel: 'تشغيل الاستماع',
    icon: Icons.mic_off_rounded,
    isDanger: false,
  );
  if (!shouldTurnOn || !context.mounted) return false;

  // Listening needs the internet.
  if (!await hesakRequireInternet(context)) return false;

  HesakModeStore.instance.setListening(true);
  return true;
}