import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/project_models.dart';
import '../../services/auth_service.dart';
import '../projects/document_viewer_page.dart';

class ContractsPage extends StatefulWidget {
  const ContractsPage({
    super.key,
    required this.auth,
  });

  final AuthService auth;

  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  final _searchController = TextEditingController();
  List<ProjectDocument> _contracts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await widget.auth.fetchDocuments();
      if (!mounted) return;
      final contracts = docs.where((d) => d.type.toLowerCase().contains('договор')).toList(growable: false)
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      setState(() => _contracts = contracts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(ProjectDocument doc) {
    final url = widget.auth.resolveFileUrl(doc.storagePath);
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

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _contracts.where((d) {
      if (query.isEmpty) return true;
      return d.name.toLowerCase().contains(query) || d.projectId.toLowerCase().contains(query);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Поиск договора',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          if (!_loading && _error == null && filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Договоры не найдены')),
            ),
          for (final doc in filtered)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.description_outlined, color: Color(0xFFE0AC00)),
                title: Text(doc.name),
                subtitle: Text('Загружен: ${formatDateRu(doc.uploadedAt)} · v${doc.version}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(doc),
              ),
            ),
        ],
      ),
    );
  }
}
