import 'package:flutter/material.dart';

enum AppSection {
  projects,
  documents,
  support,
  notifications,
  calendar,
  users,
}

class MenuItemData {
  const MenuItemData({
    required this.section,
    required this.group,
    required this.label,
    required this.icon,
    this.visibleForClient = true,
    this.adminOnly = false,
  });

  final AppSection section;
  final String group;
  final String label;
  final IconData icon;
  final bool visibleForClient;
  final bool adminOnly;
}

const menuItems = <MenuItemData>[
  MenuItemData(
      section: AppSection.projects,
      group: 'Объекты строительства',
      label: 'Объекты',
      icon: Icons.home_outlined),
  MenuItemData(
      section: AppSection.documents,
      group: 'Документооборот',
      label: 'Документы',
      icon: Icons.folder_open_outlined),
  MenuItemData(
      section: AppSection.support,
      group: 'Поддержка',
      label: 'Чат поддержки',
      icon: Icons.chat_bubble_outline),
  MenuItemData(
      section: AppSection.notifications,
      group: 'Уведомления',
      label: 'Уведомления',
      icon: Icons.notifications_none),
  MenuItemData(
    section: AppSection.calendar,
    group: 'Планирование',
    label: 'Календарь',
    icon: Icons.calendar_month_outlined,
    visibleForClient: false,
  ),
  MenuItemData(
    section: AppSection.users,
    group: 'Управление',
    label: 'Пользователи',
    icon: Icons.group_outlined,
    visibleForClient: false,
    adminOnly: true,
  ),
];
