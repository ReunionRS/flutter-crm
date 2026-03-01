import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/notification_models.dart';
import '../../services/auth_service.dart';
import '../../services/local_push_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.auth,
    required this.onOpenSupportChat,
    required this.onOpenProject,
  });

  final AuthService auth;
  final ValueChanged<String?> onOpenSupportChat;
  final ValueChanged<String> onOpenProject;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;
  Timer? _polling;
  bool _requestInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
    _polling = Timer.periodic(const Duration(seconds: 1), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _polling?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await widget.auth.fetchNotifications();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _requestInFlight = false;
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _enablePush() async {
    await LocalPushService.instance.requestPermissions();
    await LocalPushService.instance.show(
      title: 'Март Строй',
      body: 'Push-уведомления включены',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Push включены. Для боевых уведомлений нужен серверный канал отправки.')),
    );
  }

  Future<void> _markAllRead() async {
    await widget.auth.markAllNotificationsRead();
    await _load();
  }

  Future<void> _clearAll() async {
    final snapshot = List<AppNotification>.from(_items);
    setState(() => _items = const <AppNotification>[]);
    try {
      await widget.auth.clearNotifications();
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = snapshot;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openNotification(AppNotification item) {
    if (item.type == 'support_reply' || item.type == 'support_incoming') {
      widget.onOpenSupportChat(
          item.clientUserId.isEmpty ? null : item.clientUserId);
      return;
    }
    if (item.projectId.isNotEmpty) {
      widget.onOpenProject(item.projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyKey = _loading
        ? const ValueKey<String>('loading')
        : _error != null
            ? const ValueKey<String>('error')
            : _items.isEmpty
                ? const ValueKey<String>('empty')
                : ValueKey<String>(
                    'list-${_items.length}-${_items.first.id}-${_items.first.isRead}');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _enablePush,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0AC00)),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Включить push'),
              ),
              OutlinedButton(
                onPressed: _markAllRead,
                child: const Text('Отметить прочитанными'),
              ),
              OutlinedButton(
                onPressed: _clearAll,
                child: const Text('Очистить всё'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildAnimatedBody(bodyKey),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBody(Key key) {
    if (_loading) {
      return const Padding(
        key: ValueKey<String>('loading'),
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        key: const ValueKey<String>('error'),
        padding: const EdgeInsets.all(12),
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    if (_items.isEmpty) {
      return const Padding(
        key: ValueKey<String>('empty'),
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Уведомлений пока нет')),
      );
    }

    return Column(
      key: key,
      children: [
        for (var i = 0; i < _items.length; i++)
          _AnimatedNotificationTile(
            item: _items[i],
            index: i,
            onTap: () => _openNotification(_items[i]),
          ),
      ],
    );
  }
}

class _AnimatedNotificationTile extends StatelessWidget {
  const _AnimatedNotificationTile({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final AppNotification item;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = 180 + (index * 35);
    final ms = base > 420 ? 420 : base;

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('n-${item.id}-${item.isRead}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            item.isRead ? Icons.notifications_none : Icons.notifications_active,
            color: item.isRead ? null : const Color(0xFFE0AC00),
          ),
          title: Text(item.title),
          subtitle: Text('${item.body}\n${formatDateRu(item.createdAt)}'),
          isThreeLine: true,
        ),
      ),
    );
  }
}
