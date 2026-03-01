import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.auth,
    required this.role,
    required this.onUnauthorized,
  });

  final AuthService auth;
  final String role;
  final Future<void> Function() onUnauthorized;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const Map<String, String> _statusLabels = <String, String>{
    'not_started': 'Не начат',
    'in_progress': 'В работе',
    'completed': 'Завершён',
    'overdue': 'Просрочен',
  };

  static const List<String> _editableStatuses = <String>[
    'not_started',
    'in_progress',
    'completed',
  ];

  List<ProjectDetails> _projects = const <ProjectDetails>[];
  List<_CalendarEvent> _events = const <_CalendarEvent>[];

  bool _loading = true;
  String? _error;

  ProjectDetails? _selectedProject;
  _CalendarEvent? _editingEvent;
  String _editStart = '';
  String _editEnd = '';
  String _editStatus = 'not_started';
  bool _saving = false;

  bool get _isClient => widget.role == 'client';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.auth.fetchProjects();
      final details = <ProjectDetails>[];
      for (final item in list) {
        try {
          final full = await widget.auth.fetchProjectById(item.id);
          details.add(full);
        } catch (_) {
          // skip broken project
        }
      }

      final events = _buildEvents(details);

      if (!mounted) return;
      setState(() {
        _projects = details;
        _events = events;
      });
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_CalendarEvent> _buildEvents(List<ProjectDetails> source) {
    final out = <_CalendarEvent>[];

    for (final project in source) {
      for (var i = 0; i < project.stages.length; i++) {
        final stage = project.stages[i];

        if (stage.plannedStart.isNotEmpty) {
          out.add(
            _CalendarEvent(
              projectId: project.id,
              projectAddress: project.constructionAddress,
              clientFio: project.clientFio,
              stageName: stage.name,
              stageIndex: i,
              date: stage.plannedStart,
              type: 'start',
              status: stage.status,
              plannedStart: stage.plannedStart,
              plannedEnd: stage.plannedEnd,
            ),
          );
        }

        if (stage.plannedEnd.isNotEmpty) {
          out.add(
            _CalendarEvent(
              projectId: project.id,
              projectAddress: project.constructionAddress,
              clientFio: project.clientFio,
              stageName: stage.name,
              stageIndex: i,
              date: stage.plannedEnd,
              type: 'end',
              status: stage.status,
              plannedStart: stage.plannedStart,
              plannedEnd: stage.plannedEnd,
            ),
          );
        }
      }
    }

    out.sort((a, b) {
      final da = normalizeDateToIso(a.date);
      final db = normalizeDateToIso(b.date);
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return a.stageName.compareTo(b.stageName);
    });

    return out;
  }

  List<_GroupedDayEvents> _grouped() {
    final map = <String, List<_CalendarEvent>>{};
    for (final e in _events) {
      final key = normalizeDateToIso(e.date);
      map.putIfAbsent(key, () => <_CalendarEvent>[]).add(e);
    }
    final entries = map.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => _GroupedDayEvents(date: e.key, events: e.value))
        .toList(growable: false);
  }

  List<ProjectDetails> _adminProjectList() {
    final list = [..._projects];
    list.sort((a, b) {
      final fio =
          a.clientFio.toLowerCase().compareTo(b.clientFio.toLowerCase());
      if (fio != 0) return fio;
      return a.constructionAddress
          .toLowerCase()
          .compareTo(b.constructionAddress.toLowerCase());
    });
    return list;
  }

  Future<void> _pickDate(bool isStart) async {
    final raw = isStart ? _editStart : _editEnd;
    final initialRaw = normalizeDateToIso(raw);
    final now = DateTime.now();
    final initial = DateTime.tryParse(
            initialRaw.isEmpty ? now.toIso8601String() : initialRaw) ??
        now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;

    final formatted = formatDateRu(picked.toIso8601String());
    setState(() {
      if (isStart) {
        _editStart = formatted;
      } else {
        _editEnd = formatted;
      }
    });
  }

  void _openEditor(_CalendarEvent event) {
    if (_isClient) return;
    setState(() {
      _editingEvent = event;
      _editStart = formatDateRu(event.plannedStart);
      _editEnd = formatDateRu(event.plannedEnd);
      _editStatus = event.status.isEmpty ? 'not_started' : event.status;
    });
  }

  void _closeEditor() {
    setState(() {
      _editingEvent = null;
      _editStart = '';
      _editEnd = '';
      _editStatus = 'not_started';
      _saving = false;
    });
  }

  Future<void> _saveStage() async {
    final event = _editingEvent;
    if (event == null) return;

    ProjectDetails? source;
    for (final p in _projects) {
      if (p.id == event.projectId) {
        source = p;
        break;
      }
    }

    if (source == null) {
      _toast('Объект не найден');
      return;
    }

    final stages = [...source.stages];
    if (event.stageIndex < 0 || event.stageIndex >= stages.length) {
      _toast('Этап не найден');
      return;
    }

    stages[event.stageIndex] = stages[event.stageIndex].copyWith(
      plannedStart: normalizeDateToIso(_editStart),
      plannedEnd: normalizeDateToIso(_editEnd),
      status: _editStatus,
    );

    setState(() => _saving = true);
    try {
      await widget.auth
          .updateProject(source.id, source.toPatchJson(stagesOverride: stages));
      if (!mounted) return;
      _toast('Этап обновлён');
      _closeEditor();
      await _load();
    } on UnauthorizedException {
      await widget.onUnauthorized();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final projectList = _adminProjectList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Календарь этапов',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: Colors.redAccent))
                      else if (_isClient)
                        grouped.isEmpty
                            ? const Text(
                                'Пока нет дат по этапам. Заполните плановые даты в карточках объектов.')
                            : Column(
                                children: grouped
                                    .map(
                                      (group) => Column(
                                        children: [
                                          ListTile(
                                            tileColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceVariant
                                                .withOpacity(0.4),
                                            title: Text(
                                                formatDateRu(group.date),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                          ...group.events.map(
                                            (e) => ListTile(
                                              title: Text(e.stageName),
                                              subtitle: Text(
                                                (e.projectAddress.isEmpty
                                                        ? 'Без адреса'
                                                        : e.projectAddress) +
                                                    '\nСтатус: ' +
                                                    (_statusLabels[e.status] ??
                                                        e.status),
                                              ),
                                              isThreeLine: true,
                                              trailing: Chip(
                                                label: Text(e.type == 'start'
                                                    ? 'Старт'
                                                    : 'Сдача'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(growable: false),
                              )
                      else
                        projectList.isEmpty
                            ? const Text('Пока нет объектов.')
                            : Column(
                                children: projectList
                                    .map(
                                      (p) => ListTile(
                                        onTap: () => setState(
                                            () => _selectedProject = p),
                                        title: Text(p.clientFio.isEmpty
                                            ? 'Клиент'
                                            : p.clientFio),
                                        subtitle: Text(
                                          (p.constructionAddress.isEmpty
                                                  ? 'Без адреса'
                                                  : p.constructionAddress) +
                                              '\nЭтапов: ' +
                                              p.stages.length.toString(),
                                        ),
                                        isThreeLine: true,
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_selectedProject != null)
          _ProjectStagesModal(
            project: _selectedProject!,
            statusLabels: _statusLabels,
            onClose: () => setState(() => _selectedProject = null),
            onEditStage: (stageIndex) {
              final project = _selectedProject!;
              final stage = project.stages[stageIndex];
              _openEditor(
                _CalendarEvent(
                  projectId: project.id,
                  projectAddress: project.constructionAddress,
                  clientFio: project.clientFio,
                  stageName: stage.name,
                  stageIndex: stageIndex,
                  date: stage.plannedStart.isEmpty
                      ? stage.plannedEnd
                      : stage.plannedStart,
                  type: 'start',
                  status: stage.status,
                  plannedStart: stage.plannedStart,
                  plannedEnd: stage.plannedEnd,
                ),
              );
              setState(() => _selectedProject = null);
            },
          ),
        if (_editingEvent != null)
          _StageEditorModal(
            event: _editingEvent!,
            editStart: _editStart,
            editEnd: _editEnd,
            editStatus: _editStatus,
            saving: _saving,
            statusLabels: _statusLabels,
            editableStatuses: _editableStatuses,
            onClose: _closeEditor,
            onPickStart: () => _pickDate(true),
            onPickEnd: () => _pickDate(false),
            onStatusChanged: (value) => setState(() => _editStatus = value),
            onSave: _saveStage,
          ),
      ],
    );
  }
}

class _CalendarEvent {
  const _CalendarEvent({
    required this.projectId,
    required this.projectAddress,
    required this.clientFio,
    required this.stageName,
    required this.stageIndex,
    required this.date,
    required this.type,
    required this.status,
    required this.plannedStart,
    required this.plannedEnd,
  });

  final String projectId;
  final String projectAddress;
  final String clientFio;
  final String stageName;
  final int stageIndex;
  final String date;
  final String type;
  final String status;
  final String plannedStart;
  final String plannedEnd;
}

class _GroupedDayEvents {
  const _GroupedDayEvents({required this.date, required this.events});

  final String date;
  final List<_CalendarEvent> events;
}

class _ProjectStagesModal extends StatelessWidget {
  const _ProjectStagesModal({
    required this.project,
    required this.statusLabels,
    required this.onClose,
    required this.onEditStage,
  });

  final ProjectDetails project;
  final Map<String, String> statusLabels;
  final VoidCallback onClose;
  final ValueChanged<int> onEditStage;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    title: Text(project.clientFio.isEmpty
                        ? 'Объект'
                        : project.clientFio),
                    subtitle: Text(project.constructionAddress.isEmpty
                        ? 'Без адреса'
                        : project.constructionAddress),
                    trailing: IconButton(
                        onPressed: onClose, icon: const Icon(Icons.close)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: project.stages.length,
                      itemBuilder: (context, index) {
                        final stage = project.stages[index];
                        return ListTile(
                          onTap: () => onEditStage(index),
                          title: Text(stage.name),
                          subtitle: Text(
                            'План: ' +
                                (formatDateRu(stage.plannedStart)) +
                                ' — ' +
                                (formatDateRu(stage.plannedEnd)) +
                                '\nСтатус: ' +
                                (statusLabels[stage.status] ?? stage.status),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageEditorModal extends StatelessWidget {
  const _StageEditorModal({
    required this.event,
    required this.editStart,
    required this.editEnd,
    required this.editStatus,
    required this.saving,
    required this.statusLabels,
    required this.editableStatuses,
    required this.onClose,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onStatusChanged,
    required this.onSave,
  });

  final _CalendarEvent event;
  final String editStart;
  final String editEnd;
  final String editStatus;
  final bool saving;
  final Map<String, String> statusLabels;
  final List<String> editableStatuses;
  final VoidCallback onClose;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Редактировать этап'),
                    subtitle: Text(event.stageName +
                        '\n' +
                        (event.projectAddress.isEmpty
                            ? 'Без адреса'
                            : event.projectAddress)),
                    isThreeLine: true,
                    trailing: IconButton(
                        onPressed: onClose, icon: const Icon(Icons.close)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onPickStart,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Дата начала: ' +
                        (editStart.isEmpty ? '—' : editStart)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onPickEnd,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                        'Дата окончания: ' + (editEnd.isEmpty ? '—' : editEnd)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: editableStatuses.contains(editStatus)
                        ? editStatus
                        : 'not_started',
                    decoration: const InputDecoration(labelText: 'Статус'),
                    items: editableStatuses
                        .map((status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(statusLabels[status] ?? status),
                            ))
                        .toList(growable: false),
                    onChanged: (value) => onStatusChanged(value ?? editStatus),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: editableStatuses
                        .map(
                          (status) => ChoiceChip(
                            label: Text(statusLabels[status] ?? status),
                            selected: editStatus == status,
                            onSelected: (_) => onStatusChanged(status),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: saving ? null : onSave,
                    child:
                        Text(saving ? 'Сохранение...' : 'Сохранить изменения'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
