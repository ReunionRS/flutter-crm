import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
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
    _startDate = TextEditingController(text: formatDateRu(existing?.startDate ?? ''));
    _plannedEndDate = TextEditingController(text: formatDateRu(existing?.plannedEndDate ?? ''));
    _nextPaymentDate = TextEditingController(text: formatDateRu(existing?.nextPaymentDate ?? ''));
    _lastPaymentDate = TextEditingController(text: formatDateRu(existing?.lastPaymentDate ?? ''));
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

  DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final ru = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (ru != null) {
      final day = int.parse(ru.group(1)!);
      final month = int.parse(ru.group(2)!);
      final year = int.parse(ru.group(3)!);
      return DateTime(year, month, day);
    }

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (iso != null) {
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      return DateTime(year, month, day);
    }

    return DateTime.tryParse(value);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = _parseDate(controller.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    controller.text = formatDateRu(picked.toIso8601String());
  }

  Widget _dateField({required TextEditingController controller, required String label}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: () => _pickDate(controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = (MediaQuery.of(context).size.width - 32).clamp(320.0, 640.0);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.existing == null ? 'Создать объект' : 'Редактировать объект'),
      content: SizedBox(
        width: dialogWidth,
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
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fio,
                  decoration: const InputDecoration(labelText: 'ФИО клиента'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите ФИО' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Телефон')),
                const SizedBox(height: 10),
                TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Адрес объекта'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите адрес' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: kProjectStatusLabels.entries
                      .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _status = v ?? 'in_progress'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _projectType,
                  decoration: const InputDecoration(labelText: 'Тип объекта'),
                  items: const [
                    DropdownMenuItem(value: 'typical', child: Text('Типовой')),
                    DropdownMenuItem(value: 'individual', child: Text('Индивидуальный')),
                  ],
                  onChanged: (v) => setState(() => _projectType = v ?? 'typical'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _areaSqm,
                  decoration: const InputDecoration(labelText: 'Площадь (м²)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _estimatedCost,
                  decoration: const InputDecoration(labelText: 'Сметная стоимость (₽)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contractAmount,
                  decoration: const InputDecoration(labelText: 'Сумма договора (₽)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _paidAmount,
                  decoration: const InputDecoration(labelText: 'Оплачено (₽)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _dateField(controller: _startDate, label: 'Дата начала (DD.MM.YYYY)'),
                const SizedBox(height: 10),
                _dateField(controller: _plannedEndDate, label: 'План сдачи (DD.MM.YYYY)'),
                const SizedBox(height: 10),
                _dateField(controller: _nextPaymentDate, label: 'Дата следующего платежа (DD.MM.YYYY)'),
                const SizedBox(height: 10),
                _dateField(controller: _lastPaymentDate, label: 'Дата последнего платежа (DD.MM.YYYY)'),
                const SizedBox(height: 10),
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
              'nextPaymentDate': normalizeDateToIso(_nextPaymentDate.text),
              'lastPaymentDate': normalizeDateToIso(_lastPaymentDate.text),
              'status': _status,
              'startDate': normalizeDateToIso(_startDate.text),
              'plannedEndDate': normalizeDateToIso(_plannedEndDate.text),
              'actualEndDate': widget.existing?.actualEndDate ?? '',
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
