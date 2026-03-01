import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/session_models.dart';
import '../../models/support_models.dart';
import '../../services/auth_service.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({
    super.key,
    required this.auth,
    required this.session,
    required this.onUnauthorized,
    this.initialClientUserId,
  });

  final AuthService auth;
  final AppSession session;
  final Future<void> Function() onUnauthorized;
  final String? initialClientUserId;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final TextEditingController _messageController = TextEditingController();

  List<SupportMessage> _messages = const <SupportMessage>[];
  bool _loading = true;
  bool _sending = false;
  String _selectedClientId = '';
  String _mobileMode = 'list';
  Timer? _polling;

  bool get _isClient => widget.session.role == 'client';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _polling = Timer.periodic(
        const Duration(seconds: 10), (_) => _loadMessages(silent: true));
  }

  @override
  void didUpdateWidget(covariant SupportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isClient) return;
    final nextId = (widget.initialClientUserId ?? '').trim();
    final prevId = (oldWidget.initialClientUserId ?? '').trim();
    if (nextId.isEmpty || nextId == prevId) return;
    setState(() {
      _selectedClientId = nextId;
      _mobileMode = 'chat';
    });
    _markChatRead(nextId, silent: true);
  }

  @override
  void dispose() {
    _polling?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await widget.auth.fetchSupportMessages();
      if (!mounted) return;
      final sorted = [...data]..sort((a, b) =>
          DateTime.tryParse(a.createdAt)?.millisecondsSinceEpoch.compareTo(
              DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0) ??
          0);

      String nextSelected = _selectedClientId;
      if (!_isClient) {
        final chats = _buildChatList(sorted);
        final requested = (widget.initialClientUserId ?? '').trim();
        if (chats.isEmpty) {
          nextSelected = '';
          _mobileMode = 'list';
        } else if (requested.isNotEmpty &&
            chats.any((c) => c.clientUserId == requested)) {
          nextSelected = requested;
        } else if (nextSelected.isEmpty ||
            !chats.any((c) => c.clientUserId == nextSelected)) {
          nextSelected = chats.first.clientUserId;
        }
      }

      setState(() {
        _messages = sorted;
        _selectedClientId = nextSelected;
      });

      if (!_isClient && _selectedClientId.isNotEmpty) {
        await _markChatRead(_selectedClientId, silent: true);
      }
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      if (!silent && mounted) {
        _toast(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  List<_SupportChatSummary> _buildChatList(List<SupportMessage> source) {
    final map = <String, _SupportChatSummary>{};

    for (final msg in source) {
      final unread = msg.senderRole == 'client' && !msg.isReadByAdmin ? 1 : 0;
      final existing = map[msg.clientUserId];
      if (existing == null) {
        map[msg.clientUserId] = _SupportChatSummary(
          clientUserId: msg.clientUserId,
          clientFio: msg.clientFio,
          lastMessageAt: msg.createdAt,
          lastMessageText: msg.messageText,
          unreadCount: unread,
        );
      } else {
        final lastCurrent =
            DateTime.tryParse(existing.lastMessageAt)?.millisecondsSinceEpoch ??
                0;
        final lastIncoming =
            DateTime.tryParse(msg.createdAt)?.millisecondsSinceEpoch ?? 0;
        if (lastIncoming >= lastCurrent) {
          existing.lastMessageAt = msg.createdAt;
          existing.lastMessageText = msg.messageText;
        }
        existing.unreadCount += unread;
      }
    }

    final list = map.values.toList(growable: false)
      ..sort((a, b) {
        final aTs =
            DateTime.tryParse(a.lastMessageAt)?.millisecondsSinceEpoch ?? 0;
        final bTs =
            DateTime.tryParse(b.lastMessageAt)?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });
    return list;
  }

  List<SupportMessage> _visibleMessages() {
    if (_isClient) return _messages;
    if (_selectedClientId.isEmpty) return const <SupportMessage>[];
    return _messages
        .where((m) => m.clientUserId == _selectedClientId)
        .toList(growable: false);
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (!_isClient && _selectedClientId.isEmpty) return;

    setState(() => _sending = true);
    try {
      await widget.auth.sendSupportMessage(
        messageText: text,
        clientUserId: _isClient ? null : _selectedClientId,
      );
      _messageController.clear();
      await _loadMessages(silent: true);
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markChatRead(String clientUserId, {bool silent = false}) async {
    if (_isClient || clientUserId.isEmpty) return;
    try {
      await widget.auth.markSupportChatRead(clientUserId);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((msg) =>
                msg.clientUserId == clientUserId && msg.senderRole == 'client'
                    ? SupportMessage(
                        id: msg.id,
                        clientUserId: msg.clientUserId,
                        clientFio: msg.clientFio,
                        senderId: msg.senderId,
                        senderFio: msg.senderFio,
                        senderRole: msg.senderRole,
                        messageText: msg.messageText,
                        createdAt: msg.createdAt,
                        isReadByAdmin: true,
                      )
                    : msg)
            .toList(growable: false);
      });
    } catch (e) {
      if (!silent) {
        _toast(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteChat() async {
    if (_isClient || _selectedClientId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: const Text('Удалить весь диалог с клиентом?'),
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
      await widget.auth.deleteSupportChat(_selectedClientId);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .where((m) => m.clientUserId != _selectedClientId)
            .toList(growable: false);
        _selectedClientId = '';
        _mobileMode = 'list';
      });
      _toast('Чат удалён');
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _selectChat(String clientUserId, bool isMobile) {
    setState(() {
      _selectedClientId = clientUserId;
      if (isMobile) _mobileMode = 'chat';
    });
    _markChatRead(clientUserId, silent: true);
  }

  String _formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final chats =
        _isClient ? const <_SupportChatSummary>[] : _buildChatList(_messages);
    final visible = _visibleMessages();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 900;
        final showSidebar = !_isClient && (!isMobile || _mobileMode == 'list');
        final showChat = _isClient || !isMobile || _mobileMode == 'chat';
        final canSend = _messageController.text.trim().isNotEmpty &&
            !_sending &&
            (_isClient || _selectedClientId.isNotEmpty);

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSidebar)
                  SizedBox(
                    width: isMobile
                        ? ((constraints.maxWidth - 56)
                                .clamp(0.0, double.infinity))
                            .toDouble()
                        : 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Диалоги',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _loading
                                ? const Center(
                                    key: ValueKey<String>('loading-chats'),
                                    child: CircularProgressIndicator(),
                                  )
                                : chats.isEmpty
                                    ? const Center(
                                        key: ValueKey<String>('empty-chats'),
                                        child: Text('Пока нет обращений'),
                                      )
                                    : ListView.builder(
                                        key: ValueKey<String>(
                                            'chat-list-${chats.length}-${chats.first.clientUserId}'),
                                        itemCount: chats.length,
                                        itemBuilder: (context, index) {
                                          final chat = chats[index];
                                          final selected = chat.clientUserId ==
                                              _selectedClientId;
                                          return _AnimatedSupportAppear(
                                            key: ValueKey<String>(
                                                'chat-${chat.clientUserId}-${chat.lastMessageAt}-${chat.unreadCount}'),
                                            index: index,
                                            child: ListTile(
                                              selected: selected,
                                              onTap: () => _selectChat(
                                                  chat.clientUserId, isMobile),
                                              title: Text(chat.clientFio),
                                              subtitle: Text(
                                                chat.lastMessageText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              trailing: chat.unreadCount > 0
                                                  ? CircleAvatar(
                                                      radius: 11,
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                      child: Text(
                                                        chat.unreadCount
                                                            .toString(),
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (showSidebar && showChat && !isMobile)
                  const VerticalDivider(width: 1),
                if (showChat)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isClient && isMobile)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _mobileMode = 'list'),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Диалоги'),
                            ),
                          ),
                        if (!_isClient && _selectedClientId.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chats
                                      .firstWhere(
                                          (c) =>
                                              c.clientUserId ==
                                              _selectedClientId,
                                          orElse: () =>
                                              _SupportChatSummary.empty())
                                      .clientFio,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _deleteChat,
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                label: const Text('Удалить чат',
                                    style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _loading
                                ? const Center(
                                    key: ValueKey<String>('loading-messages'),
                                    child: CircularProgressIndicator(),
                                  )
                                : visible.isEmpty
                                    ? Center(
                                        key: const ValueKey<String>(
                                            'empty-messages'),
                                        child: Text(_isClient
                                            ? 'Сообщений пока нет.'
                                            : 'Выберите диалог слева'),
                                      )
                                    : ListView.builder(
                                        key: ValueKey<String>(
                                            'messages-${visible.length}-${visible.last.id}'),
                                        itemCount: visible.length,
                                        itemBuilder: (context, index) {
                                          final msg = visible[index];
                                          final own = msg.senderRole ==
                                                  widget.session.role &&
                                              msg.senderFio ==
                                                  widget.session.fio;
                                          final align = own
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start;
                                          final bubbleColor = own
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.14)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant
                                                  .withOpacity(0.5);
                                          return _AnimatedSupportAppear(
                                            key: ValueKey<String>(
                                                'msg-${msg.id}-${msg.createdAt}'),
                                            index: index,
                                            child: Column(
                                              crossAxisAlignment: align,
                                              children: [
                                                Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(vertical: 4),
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth: 700),
                                                  decoration: BoxDecoration(
                                                    color: bubbleColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 4,
                                                        children: [
                                                          Text(msg.senderFio,
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                          Text(kRoleLabels[msg
                                                                  .senderRole] ??
                                                              msg.senderRole),
                                                          Text(
                                                              _formatDateTime(msg
                                                                  .createdAt),
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(msg.messageText),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _messageController,
                          minLines: 2,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Сообщение',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canSend ? _send : null,
                            child: Text(_sending ? 'Отправка...' : 'Отправить'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSupportAppear extends StatelessWidget {
  const _AnimatedSupportAppear({
    super.key,
    required this.child,
    required this.index,
  });

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final base = 160 + (index * 24);
    final ms = base > 420 ? 420 : base;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, value, inner) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

class _SupportChatSummary {
  _SupportChatSummary({
    required this.clientUserId,
    required this.clientFio,
    required this.lastMessageAt,
    required this.lastMessageText,
    required this.unreadCount,
  });

  String clientUserId;
  String clientFio;
  String lastMessageAt;
  String lastMessageText;
  int unreadCount;

  static _SupportChatSummary empty() {
    return _SupportChatSummary(
      clientUserId: '',
      clientFio: 'Клиент',
      lastMessageAt: '',
      lastMessageText: '',
      unreadCount: 0,
    );
  }
}
