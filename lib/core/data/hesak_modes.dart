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

  /// For a mode WITHOUT an icon: the first letter of its name, shown instead of [icon].
  /// null = show [icon].
  final String? letter;

  const HesakModeOption({required this.id, required this.label, required this.icon, this.letter});
}

/// The id of every mode, in one place.
class HesakModeIds {
  HesakModeIds._(); // Use HesakModeIds.xxx directly

  static const String general = 'general';
  static const String sleep = 'sleep';
  static const String car = 'car';
}

/// The starting modes (same as in HesakModeStore). The app now reads the
/// user's modes from HesakModeStore (lib/core/data/hesak_mode_store.dart);
/// this list is kept for anything that needs the built-in modes only.
const List<HesakModeOption> hesakDefaultModes = [
  HesakModeOption(id: HesakModeIds.general, label: 'العام', icon: Icons.person_rounded),
  HesakModeOption(id: HesakModeIds.sleep, label: 'النوم', icon: Icons.nightlight_round),
  HesakModeOption(id: HesakModeIds.car, label: 'السيارة', icon: Icons.directions_car_rounded),
];

/// Icons the user can pick for a mode (أيقونة الوضع), in grid order.
/// A mode can also have NO icon: then the first letter of its name is shown.
const List<IconData> hesakModeIconChoices = [
  Icons.person_rounded,
  Icons.nightlight_round,
  Icons.directions_car_rounded,
  Icons.mosque,
  Icons.work_outline_rounded,
  Icons.school_outlined,
  Icons.menu_book_rounded,
  Icons.groups_rounded,
  Icons.child_care_rounded,
  Icons.home_outlined,
  Icons.restaurant_rounded,
  Icons.coffee_outlined,
  Icons.shopping_cart_outlined,
  Icons.shopping_bag_outlined,
  Icons.local_hospital_outlined,
  Icons.medical_services_outlined,
  Icons.fitness_center_rounded,
  Icons.directions_walk_rounded,
  Icons.directions_bike_rounded,
  Icons.directions_bus_rounded,
  Icons.flight_rounded,
  Icons.beach_access_outlined,
  Icons.park_outlined,
  Icons.wb_sunny_outlined,
  Icons.umbrella_outlined,
  Icons.movie_outlined,
  Icons.sports_esports_outlined,
  Icons.music_note_rounded,
  Icons.palette_outlined,
  Icons.laptop_rounded,
  Icons.phone_outlined,
  Icons.celebration_outlined,
  Icons.favorite_border_rounded,
  Icons.star_border_rounded,
];
