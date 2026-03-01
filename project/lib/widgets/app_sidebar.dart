import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/menu_models.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.role,
    required this.isDarkMode,
    required this.selectedSection,
    required this.onSelect,
    required this.onToggleTheme,
  });

  final String role;
  final bool isDarkMode;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onToggleTheme;

  bool get _isClient => role == 'client';
  bool get _canSeeUsers => role == 'admin' || role == 'director';

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MenuItemData>>{};
    for (final item in menuItems) {
      if (_isClient && !item.visibleForClient) continue;
      groups.putIfAbsent(item.group, () => <MenuItemData>[]).add(item);
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: const Icon(Icons.home_work_outlined, color: Color(0xFFE0B300), size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Март Строй', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
                        Text(
                          kRoleLabels[role] ?? role,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.68)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                children: groups.entries.expand((entry) {
                  final widgets = <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ];
                  for (final item in entry.value) {
                    final disabled = item.adminOnly && !_canSeeUsers;
                    final selected = selectedSection == item.section;
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: ListTile(
                          minVerticalPadding: 10,
                          minLeadingWidth: 30,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          selected: selected,
                          selectedTileColor: const Color(0xFFE0B300).withOpacity(0.12),
                          enabled: !disabled,
                          leading: Icon(item.icon, color: const Color(0xFFE0B300), size: 24),
                          title: Text(
                            disabled ? '${item.label} (нет доступа)' : item.label,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          onTap: disabled ? null : () => onSelect(item.section),
                        ),
                      ),
                    );
                  }
                  return widgets;
                }).toList(growable: false),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                color: isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              ),
              child: FilledButton.icon(
                onPressed: onToggleTheme,
                icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                label: Text(isDarkMode ? 'Светлая тема' : 'Тёмная тема'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFFE0B300),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
