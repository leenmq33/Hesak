import 'package:flutter/material.dart';

/// Everything about the listening modes (العام، النوم، السيارة ...) lives here,
/// so every page uses the same ids, names and icons.
///
/// Rules for the team:
/// - Use `HesakModeIds.xxx` instead of typing 'sleep' by hand.
/// - A new mode = add its id here + add it to `hesakDefaultModes`.

/// One mode (e.g. النوم).
/// [id] must be unique (it's also used in widget Keys, e.g. navbar_mode_sleep_button).
class HesakModeOption {
  final String id; // e.g. HesakModeIds.sleep
  final String label; // e.g. 'النوم'
  final IconData icon; // e.g. Icons.nightlight_round

  const HesakModeOption({required this.id, required this.label, required this.icon});
}

/// The id of every mode, in one place.
class HesakModeIds {
  HesakModeIds._(); // Use HesakModeIds.xxx directly

  static const String general = 'general';
  static const String sleep = 'sleep';
  static const String car = 'car';
}

/// The modes shown on the wheel of the middle button, in wheel order:
/// the first two show next to "إضافة", spinning the wheel reveals the rest.
/// TODO: later, load the user's own list from the "الأوضاع" page.
const List<HesakModeOption> hesakDefaultModes = [
  HesakModeOption(id: HesakModeIds.general, label: 'العام', icon: Icons.person_rounded),
  HesakModeOption(id: HesakModeIds.sleep, label: 'النوم', icon: Icons.nightlight_round),
  HesakModeOption(id: HesakModeIds.car, label: 'السيارة', icon: Icons.directions_car_rounded),
];
