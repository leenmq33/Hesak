import 'package:flutter/material.dart';
import '../models/app_mode.dart';

/// ModesService manages the list of modes, the currently active mode,
/// and which modes are marked as favorites (shown in the quick radial menu).
///
/// This is a plain ChangeNotifier (built into Flutter, no external package),
/// so any widget listening to it rebuilds automatically when the state changes.
///
/// Usage: create one instance high up in the widget tree (e.g. in main.dart)
/// and pass it down to BottomNavBar and any screen that needs it.
class ModesService extends ChangeNotifier {
  static const int maxFavorites = 2;

  final List<AppMode> modes = [
    AppMode(id: 'general', name: 'عام', icon: Icons.person, isDefault: true),
    AppMode(id: 'sleep', name: 'النوم', icon: Icons.bed, isFavorite: true),
    AppMode(id: 'prayer', name: 'الصلاة', icon: Icons.mosque, isFavorite: true),
    AppMode(id: 'driving', name: 'القيادة', icon: Icons.directions_car),
    AppMode(id: 'important_sounds', name: 'الأصوات المهمة', icon: Icons.notifications_active),
  ];

  String currentModeId = 'general';

  AppMode get currentMode => modes.firstWhere((m) => m.id == currentModeId);

  List<AppMode> get favoriteModes => modes.where((m) => m.isFavorite).toList();

  // Called when the user picks a mode from the radial menu or the modes list.
  void setCurrentMode(String id) {
    currentModeId = id;
    notifyListeners();
  }

  // Toggles favorite status for a mode. Returns false if the max (2) is
  // already reached and the user is trying to add one more.
  bool toggleFavorite(String id) {
    final mode = modes.firstWhere((m) => m.id == id);
    if (mode.isDefault) return false; // "General" is never a toggleable favorite

    if (!mode.isFavorite && favoriteModes.length >= maxFavorites) {
      return false;
    }
    mode.isFavorite = !mode.isFavorite;
    notifyListeners();
    return true;
  }
}

