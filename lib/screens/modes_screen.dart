 import 'package:flutter/material.dart';
import '../services/modes_service.dart';

/// Full "Modes" list screen — reachable from the Grid tab and from the
/// "+" button inside the bottom bar's radial menu.
class ModesScreen extends StatelessWidget {
  final ModesService modesService;

  const ModesScreen({super.key, required this.modesService});

  static const Color _primary = Color(0xFF6B4E8E); // TODO: use AppColors

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأوضاع'), centerTitle: true),
      body: AnimatedBuilder(
        animation: modesService,
        builder: (context, _) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: modesService.modes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final mode = modesService.modes[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _primary.withOpacity(0.1),
                  child: Icon(mode.icon, color: _primary),
                ),
                title: Text(mode.name),
                trailing: mode.isDefault
                    ? _defaultBadge()
                    : IconButton(
                        icon: Icon(
                          mode.isFavorite ? Icons.star : Icons.star_border,
                          color: mode.isFavorite ? _primary : Colors.grey,
                        ),
                        onPressed: () {
                          final ok = modesService.toggleFavorite(mode.id);
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('أقصى شي وضعين مفضلين بالقائمة السريعة')),
                            );
                          }
                        },
                      ),
                onTap: () => modesService.setCurrentMode(mode.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _defaultBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: const Text('افتراضي', style: TextStyle(fontSize: 11)),
    );
  }
}


