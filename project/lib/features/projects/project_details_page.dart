import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/project_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/meta_row.dart';
import 'document_viewer_page.dart';
import 'stage_photo_gallery_page.dart';

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
  List<ProjectDocument> _documents = const [];

  bool _loading = true;
  String? _error;
  bool _financeEditorOpen = false;
  bool _uploadingProjectDoc = false;
  String? _busyStageId;

  final Map<String, TextEditingController> _stageCommentControllers =
      <String, TextEditingController>{};

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
  bool get _canUploadPhotos => !_isClient;
  bool get _canManageObjectDocs => !_isClient;
  bool get _canEditObjectCard => !_isClient;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.auth.fetchProjectById(widget.projectId);
      final documents =
          await widget.auth.fetchDocuments(projectId: widget.projectId);
      if (!mounted) return;
      _syncDetailControllers(details);
      setState(() {
        _details = details;
        _documents = documents;
      });
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
    _nextPaymentDateController.text = formatDateRu(details.nextPaymentDate);
    _lastPaymentDateController.text = formatDateRu(details.lastPaymentDate);

    for (final controller in _stageCommentControllers.values) {
      controller.dispose();
    }
    _stageCommentControllers.clear();
    for (final s in details.stages) {
      _stageCommentControllers[s.id] =
          TextEditingController(text: s.stageComment);
    }
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

  Widget _dateField(
      {required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
    );
  }

  List<ProjectDocument> _docsByType(String docType) {
    final list = _documents
        .where(
            (d) => d.type.trim().toLowerCase() == docType.trim().toLowerCase())
        .toList(growable: false);
    final sorted = [...list]
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return sorted;
  }

  ProjectDocument? _latestDocByType(String docType) {
    final list = _docsByType(docType);
    return list.isEmpty ? null : list.first;
  }

  Future<void> _reloadDocuments() async {
    final docs = await widget.auth.fetchDocuments(projectId: widget.projectId);
    if (!mounted) return;
    setState(() => _documents = docs);
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
    stages[index] = stages[index].copyWith(status: status);
    try {
      await _persistWithStages(stages);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Статус этапа обновлён')));
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
    final startCtrl =
        TextEditingController(text: formatDateRu(stage.plannedStart));
    final endCtrl = TextEditingController(text: formatDateRu(stage.plannedEnd));
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Даты: ${stage.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dateField(
                  controller: startCtrl, label: 'Плановое начало (DD.MM.YYYY)'),
              const SizedBox(height: 10),
              _dateField(
                  controller: endCtrl,
                  label: 'Плановое завершение (DD.MM.YYYY)'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (save != true) return;

    final stages = [..._details!.stages];
    stages[index] = stages[index].copyWith(
      plannedStart: normalizeDateToIso(startCtrl.text),
      plannedEnd: normalizeDateToIso(endCtrl.text),
    );
    startCtrl.dispose();
    endCtrl.dispose();
    try {
      await _persistWithStages(stages);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Даты этапа обновлены')));
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
    stages[index] = stages[index].copyWith(stageComment: draft);
    try {
      await _persistWithStages(stages);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Комментарий сохранён')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _pickAndUploadStagePhotos(int index) async {
    final details = _details;
    if (details == null || !_canUploadPhotos) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _busyStageId = details.stages[index].id);
    try {
      final updated = await widget.auth.uploadStagePhotos(
        projectId: details.id,
        stageIndex: index,
        files: result.files,
      );
      if (!mounted) return;
      _syncDetailControllers(updated);
      setState(() => _details = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Фото этапа загружены')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyStageId = null);
    }
  }

  Future<void> _deleteStagePhoto(int index, String photoUrl) async {
    final details = _details;
    if (details == null || !_canUploadPhotos) return;
    setState(() => _busyStageId = details.stages[index].id);
    try {
      final updated = await widget.auth.deleteStagePhoto(
        projectId: details.id,
        stageIndex: index,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      _syncDetailControllers(updated);
      setState(() => _details = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyStageId = null);
    }
  }

  void _openStageGallery(ProjectStage stage, int initialIndex) {
    final urls =
        stage.photoUrls.map(widget.auth.resolveFileUrl).toList(growable: false);
    if (urls.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StagePhotoGalleryPage(
          title: stage.name,
          photoUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProjectDocument() async {
    final details = _details;
    if (details == null || !_canManageObjectDocs) return;

    setState(() => _uploadingProjectDoc = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      await widget.auth.uploadProjectDocument(
        projectId: details.id,
        docType: 'Проект строения',
        file: result.files.first,
        clientUserId: details.clientUserId,
      );

      await _reloadDocuments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документ "Проект строения" загружен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _uploadingProjectDoc = false);
    }
  }

  void _openDocument(ProjectDocument doc) {
    final url = widget.auth.resolveFileUrl(doc.storagePath);
    final canPreview = doc.isPdf || doc.isDocx;
    if (!canPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Предпросмотр доступен только для PDF/DOC/DOCX')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerPage(
          title: doc.name,
          fileUrl: url,
          isDocx: doc.isDocx,
        ),
      ),
    );
  }

  Future<void> _saveFinance() async {
    if (!_canEditFinance || _details == null) return;
    try {
      await widget.auth.updateProject(
        _details!.id,
        _details!.toPatchJson(
          contractAmountOverride:
              num.tryParse(_contractAmountController.text.trim()) ?? 0,
          paidAmountOverride:
              num.tryParse(_paidAmountController.text.trim()) ?? 0,
          nextPaymentDateOverride:
              normalizeDateToIso(_nextPaymentDateController.text),
          lastPaymentDateOverride:
              normalizeDateToIso(_lastPaymentDateController.text),
        ),
      );
      if (!mounted) return;
      setState(() => _financeEditorOpen = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Финансы обновлены')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _editObjectCard() async {
    final details = _details;
    if (details == null || !_canEditObjectCard) return;

    final fioCtrl = TextEditingController(text: details.clientFio);
    final phoneCtrl = TextEditingController(text: details.clientPhone);
    final emailCtrl = TextEditingController(text: details.clientEmail);
    final addressCtrl =
        TextEditingController(text: details.constructionAddress);
    final typeCtrl = TextEditingController(text: details.projectType);
    final areaCtrl = TextEditingController(text: details.areaSqm.toString());
    final estimateCtrl =
        TextEditingController(text: details.estimatedCost.toString());
    final startCtrl =
        TextEditingController(text: formatDateRu(details.startDate));
    final plannedEndCtrl =
        TextEditingController(text: formatDateRu(details.plannedEndDate));
    final cameraCtrl = TextEditingController(text: details.cameraUrl);
    var selectedStatus =
        details.status.isEmpty ? 'in_progress' : details.status;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Редактировать карточку объекта'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: fioCtrl,
                      decoration:
                          const InputDecoration(labelText: 'ФИО клиента')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Телефон')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: addressCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Адрес объекта')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: typeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Тип проекта')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration:
                        const InputDecoration(labelText: 'Статус объекта'),
                    items: kProjectStatusLabels.entries
                        .map((e) => DropdownMenuItem<String>(
                            value: e.key, child: Text(e.value)))
                        .toList(growable: false),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => selectedStatus = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: areaCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Площадь (м²)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: estimateCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Сметная стоимость (₽)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  _dateField(
                      controller: startCtrl, label: 'Дата начала (DD.MM.YYYY)'),
                  const SizedBox(height: 8),
                  _dateField(
                      controller: plannedEndCtrl,
                      label: 'План сдачи (DD.MM.YYYY)'),
                  const SizedBox(height: 8),
                  TextField(
                      controller: cameraCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Ссылка на камеру (опционально)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Сохранить')),
          ],
        ),
      ),
    );

    final payload = <String, dynamic>{
      'clientFio': fioCtrl.text.trim(),
      'clientPhone': phoneCtrl.text.trim(),
      'clientContacts': phoneCtrl.text.trim(),
      'clientEmail': emailCtrl.text.trim(),
      'clientUserId':
          details.clientUserId.isEmpty ? null : details.clientUserId,
      'constructionAddress': addressCtrl.text.trim(),
      'projectType':
          typeCtrl.text.trim().isEmpty ? 'typical' : typeCtrl.text.trim(),
      'status': selectedStatus,
      'areaSqm': num.tryParse(areaCtrl.text.trim().replaceAll(',', '.')) ??
          details.areaSqm,
      'estimatedCost':
          num.tryParse(estimateCtrl.text.trim().replaceAll(',', '.')) ??
              details.estimatedCost,
      'startDate': normalizeDateToIso(startCtrl.text),
      'plannedEndDate': normalizeDateToIso(plannedEndCtrl.text),
      'actualEndDate': details.actualEndDate,
      'cameraUrl': cameraCtrl.text.trim(),
      'contractAmount': details.contractAmount,
      'paidAmount': details.paidAmount,
      'nextPaymentDate': details.nextPaymentDate,
      'lastPaymentDate': details.lastPaymentDate,
      'stages': details.stages.map((s) => s.toJson()).toList(growable: false),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    fioCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    typeCtrl.dispose();
    areaCtrl.dispose();
    estimateCtrl.dispose();
    startCtrl.dispose();
    plannedEndCtrl.dispose();
    cameraCtrl.dispose();

    if (save != true) return;

    try {
      await widget.auth.updateProject(details.id, payload);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Карточка объекта обновлена')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _buildProjectDocCard(ProjectDocument? document) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Проект строения',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (document == null)
            Text(
              'Проект строения пока не загружен',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            )
          else ...[
            Text(document.name),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openDocument(document),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Просмотреть'),
            ),
          ],
          if (_canManageObjectDocs) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
                  _uploadingProjectDoc ? null : _pickAndUploadProjectDocument,
              icon: _uploadingProjectDoc
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                  _uploadingProjectDoc ? 'Загрузка...' : 'Загрузить PDF/DOCX'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE0B300),
                  foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageCard(ProjectStage stage, int index) {
    final busy = _busyStageId == stage.id;
    final photoUrls =
        stage.photoUrls.map(widget.auth.resolveFileUrl).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stage.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (!_isClient)
                  TextButton(
                    onPressed: busy ? null : () => _editStageDates(index),
                    child: const Text('Даты'),
                  ),
                if (_isClient)
                  Chip(
                      label: Text(
                          kStageStatusLabels[stage.status] ?? stage.status)),
                if (!_isClient)
                  DropdownButton<String>(
                    value: stage.status,
                    items: const [
                      DropdownMenuItem(
                          value: 'not_started', child: Text('Не начат')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('В работе')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Завершён')),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) _updateStageStatus(index, v);
                          },
                  ),
              ],
            ),
            Text(
              'План: ${formatDateRu(stage.plannedStart)} — ${formatDateRu(stage.plannedEnd)}',
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
                    children: stage.comments
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
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Фото этапа',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_canUploadPhotos)
                    FilledButton.icon(
                      onPressed:
                          busy ? null : () => _pickAndUploadStagePhotos(index),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE0B300),
                        foregroundColor: Colors.white,
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_library_outlined),
                      label: Text(busy ? 'Загрузка...' : 'Добавить фото'),
                    ),
                  if (photoUrls.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Фото пока не добавлено',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(photoUrls.length, (photoIndex) {
                        final photo = photoUrls[photoIndex];
                        return SizedBox(
                          width: 120,
                          child: Stack(
                            children: [
                              InkWell(
                                onTap: () =>
                                    _openStageGallery(stage, photoIndex),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Image.network(
                                      photo,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.black12,
                                        child: const Icon(
                                            Icons.broken_image_outlined),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_canUploadPhotos)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: InkWell(
                                    onTap: busy
                                        ? null
                                        : () => _deleteStagePhoto(
                                            index, stage.photoUrls[photoIndex]),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isClient) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _stageCommentControllers[stage.id],
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Комментарий по этапу',
                  hintText: 'Введите комментарий',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: busy ? null : () => _saveStageComment(index),
                child: const Text('Сохранить комментарий'),
              ),
            ] else if (stage.stageComment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Комментарий: ${stage.stageComment}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final projectDoc = _latestDocByType('Проект строения');

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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          details.clientFio,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      if (_canEditObjectCard)
                                        TextButton(
                                          onPressed: _editObjectCard,
                                          child: const Text(
                                              'Редактировать карточку'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  MetaRow(
                                      label: 'Адрес',
                                      value: details.constructionAddress),
                                  MetaRow(
                                      label: 'Телефон',
                                      value: details.clientPhone.isEmpty
                                          ? '—'
                                          : details.clientPhone),
                                  MetaRow(
                                      label: 'Email',
                                      value: details.clientEmail.isEmpty
                                          ? '—'
                                          : details.clientEmail),
                                  MetaRow(
                                      label: 'Тип',
                                      value: details.projectType.isEmpty
                                          ? '—'
                                          : details.projectType),
                                  MetaRow(
                                      label: 'Статус',
                                      value: kProjectStatusLabels[
                                              details.status] ??
                                          details.status),
                                  MetaRow(
                                      label: 'Площадь',
                                      value: '${details.areaSqm} м²'),
                                  MetaRow(
                                      label: 'Дата начала',
                                      value: formatDateRu(details.startDate)),
                                  MetaRow(
                                      label: 'План сдачи',
                                      value:
                                          formatDateRu(details.plannedEndDate)),
                                  MetaRow(
                                      label: 'Сметная стоимость',
                                      value: '${details.estimatedCost} ₽'),
                                  const SizedBox(height: 8),
                                  MetaRow(
                                      label: 'Готовность',
                                      value: '${details.progress}%'),
                                  if (details.cameraUrl.isNotEmpty)
                                    MetaRow(
                                        label: 'Камера',
                                        value: details.cameraUrl),
                                  const SizedBox(height: 14),
                                  _buildProjectDocCard(projectDoc),
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
                                  Text('Финансы',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 8),
                                  MetaRow(
                                      label: 'Сумма договора',
                                      value: '${details.contractAmount} ₽'),
                                  MetaRow(
                                      label: 'Оплачено',
                                      value: '${details.paidAmount} ₽'),
                                  MetaRow(
                                      label: 'Задолженность',
                                      value: '${details.debt} ₽'),
                                  MetaRow(
                                      label: 'Дата следующего платежа',
                                      value: formatDateRu(
                                          details.nextPaymentDate)),
                                  MetaRow(
                                      label: 'Дата последнего платежа',
                                      value: formatDateRu(
                                          details.lastPaymentDate)),
                                  if (_canEditFinance) ...[
                                    const SizedBox(height: 10),
                                    OutlinedButton(
                                      onPressed: () => setState(() =>
                                          _financeEditorOpen =
                                              !_financeEditorOpen),
                                      child: Text(_financeEditorOpen
                                          ? 'Скрыть редактирование'
                                          : 'Редактировать финансы'),
                                    ),
                                    if (_financeEditorOpen) ...[
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _contractAmountController,
                                        decoration: const InputDecoration(
                                            labelText: 'Сумма договора (₽)'),
                                        keyboardType: TextInputType.number,
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _paidAmountController,
                                        decoration: const InputDecoration(
                                            labelText: 'Оплачено (₽)'),
                                        keyboardType: TextInputType.number,
                                      ),
                                      const SizedBox(height: 8),
                                      _dateField(
                                        controller: _nextPaymentDateController,
                                        label:
                                            'Дата следующего платежа (DD.MM.YYYY)',
                                      ),
                                      const SizedBox(height: 8),
                                      _dateField(
                                        controller: _lastPaymentDateController,
                                        label:
                                            'Дата последнего платежа (DD.MM.YYYY)',
                                      ),
                                      const SizedBox(height: 10),
                                      FilledButton(
                                        onPressed: _saveFinance,
                                        style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFE0B300)),
                                        child: const Text('Сохранить финансы'),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Этапы строительства',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          if (details.stages.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Этапы пока не добавлены'),
                              ),
                            ),
                          for (int i = 0; i < details.stages.length; i++)
                            _buildStageCard(details.stages[i], i),
                        ],
                      ),
                    ),
    );
  }
}
