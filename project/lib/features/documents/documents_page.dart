import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';
import '../projects/document_viewer_page.dart';
import '../projects/stage_photo_gallery_page.dart';

const _docTypes = <String>[
  'Договор подряда',
  'Приложения к договору',
  'Смета',
  'Акты выполненных работ',
  'Чеки',
  'Гарантийные обязательства',
  'Проектная документация',
];

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    required this.auth,
    required this.role,
  });

  final AuthService auth;
  final String role;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<ClientOption> _clients = const [];
  List<ProjectDocument> _docs = const [];
  List<PlatformFile> _pickedFiles = const [];

  bool _loading = true;
  bool _uploading = false;
  String? _error;

  String _docType = _docTypes.first;
  String? _selectedClientId;

  bool get _isClient => widget.role == 'client';
  bool get _canUpload => !_isClient;
  bool get _canDelete => !_isClient;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_isClient) {
        final clients = await widget.auth.fetchClients();
        if (!mounted) return;
        _clients = clients;
        if (_selectedClientId == null && clients.isNotEmpty) {
          _selectedClientId = clients.first.id;
        }
      }
      await _loadDocs();
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = 'Сессия истекла. Войдите снова.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDocs() async {
    final docs = await widget.auth.fetchDocuments(
      clientUserId: _isClient ? null : _selectedClientId,
    );

    final filtered = docs
        .where((d) => !d.type.toLowerCase().contains('проект строения'))
        .toList(growable: false)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    if (!mounted) return;
    setState(() => _docs = filtered);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp'
      ],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFiles = result.files);
  }

  Future<void> _upload() async {
    if (!_canUpload) return;
    if (_selectedClientId == null || _selectedClientId!.isEmpty) {
      _toast('Сначала выберите клиента');
      return;
    }
    if (_pickedFiles.isEmpty) {
      _toast('Сначала выберите файлы');
      return;
    }

    setState(() => _uploading = true);
    try {
      for (final file in _pickedFiles) {
        await widget.auth.uploadProjectDocument(
          projectId: null,
          clientUserId: _selectedClientId,
          docType: _docType,
          file: file,
        );
      }
      if (!mounted) return;
      setState(() => _pickedFiles = const []);
      _toast('Документы сохранены');
      await _loadDocs();
    } on UnauthorizedException {
      _toast('Сессия истекла. Войдите снова.');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(ProjectDocument doc) async {
    if (!_canDelete) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: Text(doc.name),
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
      await widget.auth.deleteDocument(doc.id);
      if (!mounted) return;
      _toast('Документ удалён');
      await _loadDocs();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _download(ProjectDocument doc) async {
    final uri = Uri.parse(widget.auth.documentDownloadUrl(doc.id));
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _toast('Не удалось скачать документ');
    }
  }

  void _preview(ProjectDocument doc) {
    if (_isImage(doc)) {
      final images = _docs.where(_isImage).toList(growable: false);
      final urls = images
          .map((d) => widget.auth.resolveFileUrl(d.storagePath))
          .toList(growable: false);
      final initialIndex = images.indexWhere((d) => d.id == doc.id);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StagePhotoGalleryPage(
            title: 'Документы',
            photoUrls: urls,
            initialIndex: initialIndex < 0 ? 0 : initialIndex,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerPage(
          title: doc.name,
          fileUrl: widget.auth.resolveFileUrl(doc.storagePath),
          isDocx: doc.isDocx,
        ),
      ),
    );
  }

  bool _isImage(ProjectDocument doc) {
    final mime = doc.mimeType.toLowerCase();
    final name = doc.name.toLowerCase();
    return mime.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp');
  }

  bool _isPreviewable(ProjectDocument doc) =>
      _isImage(doc) || doc.isPdf || doc.isDocx;

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return bytes.toString() + ' B';
    final kb = bytes / 1024;
    if (kb < 1024) return kb.toStringAsFixed(1) + ' KB';
    final mb = kb / 1024;
    return mb.toStringAsFixed(1) + ' MB';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ClientOption? selectedClient;
    for (final client in _clients) {
      if (client.id == _selectedClientId) {
        selectedClient = client;
        break;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Документооборот',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_isClient)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: const Text('Ваши документы'),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      decoration: const InputDecoration(labelText: 'Клиент'),
                      items: _clients
                          .map((c) => DropdownMenuItem<String>(
                              value: c.id, child: Text(c.fio)))
                          .toList(growable: false),
                      onChanged: (value) async {
                        setState(() => _selectedClientId = value);
                        await _loadDocs();
                      },
                    ),
                  if (_canUpload) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _docType,
                      decoration:
                          const InputDecoration(labelText: 'Тип документа'),
                      items: _docTypes
                          .map((type) => DropdownMenuItem<String>(
                              value: type, child: Text(type)))
                          .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => _docType = value ?? _docType),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _pickedFiles.isEmpty
                                  ? 'Файлы не выбраны'
                                  : 'Выбрано файлов: ' +
                                      _pickedFiles.length.toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _uploading ? null : _pickFiles,
                            child: const Text('Выбрать файлы'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _uploading ? null : _upload,
                        child: Text(
                            _uploading ? 'Загрузка...' : 'Сохранить документы'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Text(
                        'Клиенты могут только просматривать и скачивать документы.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
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
                  Text(
                    selectedClient == null
                        ? 'Документы'
                        : 'Документы — ' + selectedClient.fio,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Text(_error!,
                        style: const TextStyle(color: Colors.redAccent))
                  else if (_docs.isEmpty)
                    const Text('Пока нет документов.')
                  else
                    ..._docs.map((doc) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.type,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(doc.name),
                            const SizedBox(height: 2),
                            Text(
                              'v' +
                                  doc.version.toString() +
                                  ' • ' +
                                  _formatSize(doc.size) +
                                  ' • ' +
                                  formatDateRu(doc.uploadedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (_isPreviewable(doc))
                                  TextButton(
                                    onPressed: () => _preview(doc),
                                    child: const Text('Просмотр'),
                                  ),
                                TextButton(
                                  onPressed: () => _download(doc),
                                  child: const Text('Скачать'),
                                ),
                                if (_canDelete)
                                  TextButton(
                                    onPressed: () => _delete(doc),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent),
                                    child: const Text('Удалить'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
