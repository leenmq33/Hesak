import 'package:flutter/material.dart';

/// Represents a single app mode (General, Sleep, Prayer, Driving...)
class AppMode {
  final String id;
  final String name;
  final IconData icon;

  // "General" is always present and cannot be removed or favorited/unfavorited
  final bool isDefault;

  // Favorite modes show up in the bottom bar's quick radial menu.
  // Max 2 favorites allowed (enforced in ModesService).
  bool isFavorite;

  AppMode({
    required this.id,
    required this.name,
    required this.icon,
    this.isDefault = false,
    this.isFavorite = false,
  });
}
