import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/document_preview/document_preview_frame.dart';

class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.title,
    required this.fileUrl,
    required this.isDocx,
  });

  final String title;
  final String fileUrl;
  final bool isDocx;

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'doc-preview-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.fileUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть документ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = widget.isDocx
        ? 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(widget.fileUrl)}'
        : widget.fileUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _openExternal,
            tooltip: 'Открыть внешне',
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: kIsWeb
          ? buildDocumentPreviewFrame(
              viewType: _viewType,
              url: previewUrl,
            )
          : Center(
              child: FilledButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Открыть документ'),
              ),
            ),
    );
  }
}
