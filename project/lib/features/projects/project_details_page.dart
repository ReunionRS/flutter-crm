import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/project_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/meta_row.dart';

class ProjectDetailsPage extends StatefulWidget {
  const ProjectDetailsPage({
    super.key,
    required this.auth,
    required this.projectId,
    required this.role,
  });

  final AuthService auth;
  final String projectId;
  final String role;

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  ProjectDetails? _details;
  bool _loading = true;
  String? _error;
  bool _financeEditorOpen = false;
  final Map<String, TextEditingController> _stageCommentControllers = <String, TextEditingController>{};

  late final TextEditingController _contractAmountController;
  late final TextEditingController _paidAmountController;
  late final TextEditingController _nextPaymentDateController;
  late final TextEditingController _lastPaymentDateController;

  @override
  void initState() {
    super.initState();
    _contractAmountController = TextEditingController();
    _paidAmountController = TextEditingController();
    _nextPaymentDateController = TextEditingController();
    _lastPaymentDateController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _contractAmountController.dispose();
    _paidAmountController.dispose();
    _nextPaymentDateController.dispose();
    _lastPaymentDateController.dispose();
    for (final c in _stageCommentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isClient => widget.role == 'client';
  bool get _canEditFinance =>
      widget.role == 'admin' ||
      widget.role == 'director' ||
      widget.role == 'accountant' ||
      widget.role == 'manager';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.auth.fetchProjectById(widget.projectId);
      if (!mounted) return;
      _syncDetailControllers(details);
      setState(() => _details = details);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncDetailControllers(ProjectDetails details) {
    _contractAmountController.text = details.contractAmount.toString();
    _paidAmountController.text = details.paidAmount.toString();
    _nextPaymentDateController.text = details.nextPaymentDate;
    _lastPaymentDateController.text = details.lastPaymentDate;

    for (final controller in _stageCommentControllers.values) {
      controller.dispose();
    }
    _stageCommentControllers.clear();
    for (final s in details.stages) {
      _stageCommentControllers[s.id] = TextEditingController(text: s.stageComment);
    }
  }

  Future<void> _persistWithStages(List<ProjectStage> stages) async {
    final details = _details;
    if (details == null) return;
    final payload = details.toPatchJson(stagesOverride: stages);
    await widget.auth.updateProject(details.id, payload);
    await _load();
  }

  Future<void> _updateStageStatus(int index, String status) async {
    if (_isClient || _details == null) return;
    final stages = [..._details!.stages];
    final current = stages[index];
    stages[index] = ProjectStage(
      id: current.id,
      name: current.name,
      status: status,
      plannedStart: current.plannedStart,
      plannedEnd: current.plannedEnd,
      stageComment: current.stageComment,
      comments: current.comments,
      photoUrls: current.photoUrls,
    );
    try {
      await _persistWithStages(stages);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Статус этапа обновлён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _editStageDates(int index) async {
    if (_isClient || _details == null) return;
    final stage = _details!.stages[index];
    final startCtrl = TextEditingController(text: stage.plannedStart);
    final endCtrl = TextEditingController(text: stage.plannedEnd);
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Даты: ${stage.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(labelText: 'Плановое начало (yyyy-mm-dd)'),
              ),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(labelText: 'Плановое завершение (yyyy-mm-dd)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (save != true) return;

    final stages = [..._details!.stages];
    final current = stages[index];
    stages[index] = ProjectStage(
      id: current.id,
      name: current.name,
      status: current.status,
      plannedStart: startCtrl.text.trim(),
      plannedEnd: endCtrl.text.trim(),
      stageComment: current.stageComment,
      comments: current.comments,
      photoUrls: current.photoUrls,
    );
    startCtrl.dispose();
    endCtrl.dispose();
    try {
      await _persistWithStages(stages);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Даты этапа обновлены')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveStageComment(int index) async {
    if (_isClient || _details == null) return;
    final stage = _details!.stages[index];
    final draft = _stageCommentControllers[stage.id]?.text.trim() ?? '';
    final stages = [..._details!.stages];
    final current = stages[index];
    stages[index] = ProjectStage(
      id: current.id,
      name: current.name,
      status: current.status,
      plannedStart: current.plannedStart,
      plannedEnd: current.plannedEnd,
      stageComment: draft,
      comments: current.comments,
      photoUrls: current.photoUrls,
    );
    try {
      await _persistWithStages(stages);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Комментарий сохранён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveFinance() async {
    if (!_canEditFinance || _details == null) return;
    try {
      await widget.auth.updateProject(
        _details!.id,
        _details!.toPatchJson(
          contractAmountOverride: num.tryParse(_contractAmountController.text.trim()) ?? 0,
          paidAmountOverride: num.tryParse(_paidAmountController.text.trim()) ?? 0,
          nextPaymentDateOverride: _nextPaymentDateController.text.trim(),
          lastPaymentDateOverride: _lastPaymentDateController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _financeEditorOpen = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Финансы обновлены')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return Scaffold(
      appBar: AppBar(title: const Text('Карточка объекта')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : details == null
                  ? const Center(child: Text('Объект не найден'))
                  : RefreshIndicator(
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
                                  Text(
                                    details.clientFio,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  MetaRow(label: 'Адрес', value: details.constructionAddress),
                                  MetaRow(label: 'Телефон', value: details.clientPhone.isEmpty ? '—' : details.clientPhone),
                                  MetaRow(label: 'Email', value: details.clientEmail.isEmpty ? '—' : details.clientEmail),
                                  MetaRow(label: 'Тип', value: details.projectType.isEmpty ? '—' : details.projectType),
                                  MetaRow(label: 'Статус', value: kProjectStatusLabels[details.status] ?? details.status),
                                  MetaRow(label: 'Площадь', value: '${details.areaSqm} м²'),
                                  MetaRow(label: 'Дата начала', value: formatDateRu(details.startDate)),
                                  MetaRow(label: 'План сдачи', value: formatDateRu(details.plannedEndDate)),
                                  MetaRow(label: 'Факт. сдача', value: formatDateRu(details.actualEndDate)),
                                  MetaRow(label: 'Сметная стоимость', value: '${details.estimatedCost} ₽'),
                                  const SizedBox(height: 8),
                                  MetaRow(label: 'Готовность', value: '${details.progress}%'),
                                  if (details.cameraUrl.isNotEmpty) MetaRow(label: 'Камера', value: details.cameraUrl),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Финансы', style: Theme.of(context).textTheme.titleLarge),
                                  const SizedBox(height: 8),
                                  MetaRow(label: 'Сумма договора', value: '${details.contractAmount} ₽'),
                                  MetaRow(label: 'Оплачено', value: '${details.paidAmount} ₽'),
                                  MetaRow(label: 'Задолженность', value: '${details.debt} ₽'),
                                  MetaRow(label: 'Дата следующего платежа', value: formatDateRu(details.nextPaymentDate)),
                                  MetaRow(label: 'Дата последнего платежа', value: formatDateRu(details.lastPaymentDate)),
                                  if (_canEditFinance) ...[
                                    const SizedBox(height: 10),
                                    OutlinedButton(
                                      onPressed: () => setState(() => _financeEditorOpen = !_financeEditorOpen),
                                      child: Text(
                                        _financeEditorOpen ? 'Скрыть редактирование' : 'Редактировать финансы',
                                      ),
                                    ),
                                    if (_financeEditorOpen) ...[
                                      TextField(
                                        controller: _contractAmountController,
                                        decoration: const InputDecoration(labelText: 'Сумма договора (₽)'),
                                        keyboardType: TextInputType.number,
                                      ),
                                      TextField(
                                        controller: _paidAmountController,
                                        decoration: const InputDecoration(labelText: 'Оплачено (₽)'),
                                        keyboardType: TextInputType.number,
                                      ),
                                      TextField(
                                        controller: _nextPaymentDateController,
                                        decoration: const InputDecoration(
                                          labelText: 'Дата следующего платежа (yyyy-mm-dd)',
                                        ),
                                      ),
                                      TextField(
                                        controller: _lastPaymentDateController,
                                        decoration: const InputDecoration(
                                          labelText: 'Дата последнего платежа (yyyy-mm-dd)',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton(
                                        onPressed: _saveFinance,
                                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE0B300)),
                                        child: const Text('Сохранить финансы'),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Этапы строительства', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          if (details.stages.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Этапы пока не добавлены'),
                              ),
                            ),
                          for (int i = 0; i < details.stages.length; i++)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            details.stages[i].name,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        if (!_isClient)
                                          TextButton(
                                            onPressed: () => _editStageDates(i),
                                            child: const Text('Даты'),
                                          ),
                                        if (_isClient)
                                          Chip(
                                            label: Text(
                                              kStageStatusLabels[details.stages[i].status] ?? details.stages[i].status,
                                            ),
                                          ),
                                        if (!_isClient)
                                          DropdownButton<String>(
                                            value: details.stages[i].status,
                                            items: const [
                                              DropdownMenuItem(value: 'not_started', child: Text('Не начат')),
                                              DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                                              DropdownMenuItem(value: 'completed', child: Text('Завершён')),
                                            ],
                                            onChanged: (v) {
                                              if (v != null) _updateStageStatus(i, v);
                                            },
                                          ),
                                      ],
                                    ),
                                    Text(
                                      'План: ${formatDateRu(details.stages[i].plannedStart)} — ${formatDateRu(details.stages[i].plannedEnd)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    ExpansionTile(
                                      title: const Text('Описание'),
                                      tilePadding: EdgeInsets.zero,
                                      childrenPadding: EdgeInsets.zero,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: details.stages[i]
                                                .comments
                                                .split('\n')
                                                .map((line) => line.trim())
                                                .where((line) => line.isNotEmpty)
                                                .map(
                                                  (line) => Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Text('• $line'),
                                                  ),
                                                )
                                                .toList(growable: false),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!_isClient) ...[
                                      TextField(
                                        controller: _stageCommentControllers[details.stages[i].id],
                                        maxLines: null,
                                        decoration: const InputDecoration(
                                          labelText: 'Комментарий по этапу',
                                          hintText: 'Введите комментарий',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton(
                                        onPressed: () => _saveStageComment(i),
                                        child: const Text('Сохранить комментарий'),
                                      ),
                                    ] else if (details.stages[i].stageComment.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Комментарий: ${details.stages[i].stageComment}',
                                        style: const TextStyle(color: Colors.redAccent),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
