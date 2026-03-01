import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/user_models.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({
    super.key,
    required this.auth,
    required this.role,
    required this.onUnauthorized,
  });

  final AuthService auth;
  final String role;
  final Future<void> Function() onUnauthorized;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _fioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  List<AppUser> _users = const <AppUser>[];
  bool _loading = true;
  bool _creating = false;
  String _newRole = 'manager';

  bool get _canManage => widget.role == 'admin' || widget.role == 'director';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _fioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await widget.auth.fetchUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUser() async {
    final fio = _fioController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fio.isEmpty || email.isEmpty || password.isEmpty) {
      _toast('Заполните все поля');
      return;
    }

    final sendWelcomeEmail = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отправка данных'),
        content: const Text(
          'Продублировать данные пользователя на почту?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да'),
          ),
        ],
      ),
    );

    if (sendWelcomeEmail == null) return;

    setState(() => _creating = true);
    try {
      await widget.auth.createUser(
        fio: fio,
        email: email,
        password: password,
        role: _newRole,
        sendWelcomeEmail: sendWelcomeEmail,
      );
      if (!mounted) return;
      _fioController.clear();
      _emailController.clear();
      _passwordController.clear();
      _newRole = 'manager';
      _toast('Пользователь создан');
      await _loadUsers();
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('${user.fio}\n${user.email}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.auth.deleteUser(user.id);
      if (!mounted) return;
      _toast('Пользователь удалён');
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
          if (_canManage)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Создать пользователя',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fioController,
                      decoration: const InputDecoration(labelText: 'ФИО'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _newRole,
                      decoration: const InputDecoration(labelText: 'Роль'),
                      items: kRoleLabels.entries
                          .map((entry) => DropdownMenuItem<String>(
                              value: entry.key, child: Text(entry.value)))
                          .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => _newRole = value ?? _newRole),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _creating ? null : _createUser,
                        child: Text(
                            _creating ? 'Создание...' : 'Создать пользователя'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_canManage) const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Пользователи',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_users.isEmpty)
                    const Text('Нет пользователей в системе')
                  else
                    ..._users.map(
                      (user) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fio.isEmpty ? 'Без имени' : user.fio,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(user.email.isEmpty ? '—' : user.email),
                            const SizedBox(height: 2),
                            Text(kRoleLabels[user.role] ?? user.role),
                            if (_canManage) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _deleteUser(user),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ],
                        ),
                      ),
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
