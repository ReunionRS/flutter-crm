import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';

class ProjectFormResult {
  const ProjectFormResult({required this.payload});
  final Map<String, dynamic> payload;
}

class ProjectFormDialog extends StatefulWidget {
  const ProjectFormDialog({
    super.key,
    required this.clients,
    this.existing,
  });

  final ProjectDetails? existing;
  final List<ClientOption> clients;

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fio;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _areaSqm;
  late final TextEditingController _estimatedCost;
  late final TextEditingController _contractAmount;
  late final TextEditingController _paidAmount;
  late final TextEditingController _startDate;
  late final TextEditingController _plannedEndDate;
  late final TextEditingController _actualEndDate;
  late final TextEditingController _nextPaymentDate;
  late final TextEditingController _lastPaymentDate;
  late final TextEditingController _cameraUrl;

  String _status = 'in_progress';
  String _projectType = 'typical';
  String _selectedClientId = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _fio = TextEditingController(text: existing?.clientFio ?? '');
    _phone = TextEditingController(text: existing?.clientPhone ?? '');
    _email = TextEditingController(text: existing?.clientEmail ?? '');
    _address = TextEditingController(text: existing?.constructionAddress ?? '');
    _areaSqm = TextEditingController(text: existing == null ? '0' : existing.areaSqm.toString());
    _estimatedCost = TextEditingController(text: existing == null ? '0' : existing.estimatedCost.toString());
    _contractAmount = TextEditingController(text: existing == null ? '0' : existing.contractAmount.toString());
    _paidAmount = TextEditingController(text: existing == null ? '0' : existing.paidAmount.toString());
    _startDate = TextEditingController(text: existing?.startDate ?? '');
    _plannedEndDate = TextEditingController(text: existing?.plannedEndDate ?? '');
    _actualEndDate = TextEditingController(text: existing?.actualEndDate ?? '');
    _nextPaymentDate = TextEditingController(text: existing?.nextPaymentDate ?? '');
    _lastPaymentDate = TextEditingController(text: existing?.lastPaymentDate ?? '');
    _cameraUrl = TextEditingController(text: existing?.cameraUrl ?? '');
    _status = existing?.status ?? 'in_progress';
    _projectType = existing?.projectType.isNotEmpty == true ? existing!.projectType : 'typical';
    _selectedClientId = existing?.clientUserId ?? '';
  }

  @override
  void dispose() {
    _fio.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _areaSqm.dispose();
    _estimatedCost.dispose();
    _contractAmount.dispose();
    _paidAmount.dispose();
    _startDate.dispose();
    _plannedEndDate.dispose();
    _actualEndDate.dispose();
    _nextPaymentDate.dispose();
    _lastPaymentDate.dispose();
    _cameraUrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildDefaultStages() {
    return List<Map<String, dynamic>>.generate(kConstructionStages.length, (i) {
      final name = kConstructionStages[i];
      return <String, dynamic>{
        'id': 'stage-$i',
        'name': name,
        'plannedStart': '',
        'plannedEnd': '',
        'status': 'not_started',
        'comments': (kStageDescriptionItems[name] ?? const <String>[]).join('\n'),
        'stageComment': '',
        'photoUrls': <String>[],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Создать объект' : 'Редактировать объект'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedClientId.isEmpty ? null : _selectedClientId,
                  decoration: const InputDecoration(labelText: 'Клиент (пользователь)'),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('Нет привязки')),
                    ...widget.clients.map(
                      (c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text('${c.fio}${c.email.isEmpty ? '' : ' (${c.email})'}'),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    final next = v ?? '';
                    setState(() => _selectedClientId = next);
                    final selected = widget.clients.cast<ClientOption?>().firstWhere(
                          (c) => c?.id == next,
                          orElse: () => null,
                        );
                    if (selected != null) {
                      _fio.text = selected.fio;
                      _email.text = selected.email;
                    }
                  },
                ),
                TextFormField(
                  controller: _fio,
                  decoration: const InputDecoration(labelText: 'ФИО клиента'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите ФИО' : null,
                ),
                TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Телефон')),
                TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Адрес объекта'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите адрес' : null,
                ),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: kProjectStatusLabels.entries
                      .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _status = v ?? 'in_progress'),
                ),
                DropdownButtonFormField<String>(
                  value: _projectType,
                  decoration: const InputDecoration(labelText: 'Тип объекта'),
                  items: const [
                    DropdownMenuItem(value: 'typical', child: Text('Типовой')),
                    DropdownMenuItem(value: 'individual', child: Text('Индивидуальный')),
                  ],
                  onChanged: (v) => setState(() => _projectType = v ?? 'typical'),
                ),
                TextFormField(controller: _areaSqm, decoration: const InputDecoration(labelText: 'Площадь (м²)'), keyboardType: TextInputType.number),
                TextFormField(controller: _estimatedCost, decoration: const InputDecoration(labelText: 'Сметная стоимость (₽)'), keyboardType: TextInputType.number),
                TextFormField(controller: _contractAmount, decoration: const InputDecoration(labelText: 'Сумма договора (₽)'), keyboardType: TextInputType.number),
                TextFormField(controller: _paidAmount, decoration: const InputDecoration(labelText: 'Оплачено (₽)'), keyboardType: TextInputType.number),
                TextFormField(controller: _startDate, decoration: const InputDecoration(labelText: 'Дата начала (yyyy-mm-dd)')),
                TextFormField(controller: _plannedEndDate, decoration: const InputDecoration(labelText: 'План сдачи (yyyy-mm-dd)')),
                TextFormField(controller: _actualEndDate, decoration: const InputDecoration(labelText: 'Фактическая сдача (yyyy-mm-dd)')),
                TextFormField(controller: _nextPaymentDate, decoration: const InputDecoration(labelText: 'Дата следующего платежа (yyyy-mm-dd)')),
                TextFormField(controller: _lastPaymentDate, decoration: const InputDecoration(labelText: 'Дата последнего платежа (yyyy-mm-dd)')),
                TextFormField(controller: _cameraUrl, decoration: const InputDecoration(labelText: 'URL камеры')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final payload = <String, dynamic>{
              'clientFio': _fio.text.trim(),
              'clientContacts': _phone.text.trim(),
              'clientPhone': _phone.text.trim(),
              'clientEmail': _email.text.trim(),
              'clientUserId': _selectedClientId.isEmpty ? null : _selectedClientId,
              'constructionAddress': _address.text.trim(),
              'projectType': _projectType,
              'areaSqm': num.tryParse(_areaSqm.text.trim()) ?? 0,
              'estimatedCost': num.tryParse(_estimatedCost.text.trim()) ?? 0,
              'contractAmount': num.tryParse(_contractAmount.text.trim()) ?? 0,
              'paidAmount': num.tryParse(_paidAmount.text.trim()) ?? 0,
              'nextPaymentDate': _nextPaymentDate.text.trim(),
              'lastPaymentDate': _lastPaymentDate.text.trim(),
              'status': _status,
              'startDate': _startDate.text.trim(),
              'plannedEndDate': _plannedEndDate.text.trim(),
              'actualEndDate': _actualEndDate.text.trim(),
              'cameraUrl': _cameraUrl.text.trim(),
              'stages': widget.existing == null
                  ? _buildDefaultStages()
                  : widget.existing!.stages.map((s) => s.toJson()).toList(growable: false),
              'updatedAt': DateTime.now().toIso8601String(),
            };
            Navigator.pop(context, ProjectFormResult(payload: payload));
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE0B300)),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
