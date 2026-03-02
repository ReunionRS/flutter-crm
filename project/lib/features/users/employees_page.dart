import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/session_models.dart';
import '../../models/user_models.dart';
import '../../services/auth_service.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({
    super.key,
    required this.auth,
    required this.role,
    required this.onUnauthorized,
  });

  final AuthService auth;
  final String role;
  final Future<void> Function() onUnauthorized;

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  List<AppUser> _users = const <AppUser>[];
  bool _loading = true;
  EmployeeTab _tab = EmployeeTab.active;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await widget.auth.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users.where((u) => u.role != 'client').toList(growable: false);
      });
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppUser> get _filtered {
    return _users.where((u) {
      if (_tab == EmployeeTab.archive) return u.isArchived;
      if (_tab == EmployeeTab.inactive) return !u.isArchived && !u.isActive;
      return !u.isArchived && u.isActive;
    }).toList(growable: false);
  }

  Future<void> _setStateUser(
    AppUser user, {
    bool? isActive,
    bool? isArchived,
  }) async {
    try {
      await widget.auth.updateUserState(
        user.id,
        isActive: isActive,
        isArchived: isArchived,
      );
      if (!mounted) return;
      _toast('Состояние сотрудника обновлено');
      await _loadUsers();
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<EmployeeTab>(
            segments: const <ButtonSegment<EmployeeTab>>[
              ButtonSegment(value: EmployeeTab.active, label: Text('Активные')),
              ButtonSegment(
                  value: EmployeeTab.inactive, label: Text('Неактивные')),
              ButtonSegment(value: EmployeeTab.archive, label: Text('Архив')),
            ],
            selected: <EmployeeTab>{_tab},
            onSelectionChanged: (next) => setState(() => _tab = next.first),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Сотрудники не найдены')),
            )
          else
            ..._filtered.map(
              (user) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fio.isEmpty ? 'Без имени' : user.fio,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(user.email.isEmpty ? '—' : user.email),
                    const SizedBox(height: 2),
                    Text(kRoleLabels[user.role] ?? user.role),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!user.isArchived && user.isActive)
                          OutlinedButton(
                            onPressed: () =>
                                _setStateUser(user, isActive: false),
                            child: const Text('Отключить'),
                          ),
                        if (!user.isArchived && !user.isActive)
                          OutlinedButton(
                            onPressed: () => _setStateUser(user,
                                isActive: true, isArchived: false),
                            child: const Text('Включить'),
                          ),
                        if (!user.isArchived)
                          OutlinedButton(
                            onPressed: () =>
                                _setStateUser(user, isArchived: true),
                            child: const Text('В архив'),
                          ),
                        if (user.isArchived)
                          FilledButton.tonal(
                            onPressed: () => _setStateUser(user,
                                isArchived: false, isActive: true),
                            child: const Text('Вернуть'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum EmployeeTab {
  active,
  inactive,
  archive,
}
