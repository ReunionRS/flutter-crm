import 'package:flutter/widgets.dart';

import 'document_preview_frame_stub.dart'
    if (dart.library.html) 'document_preview_frame_web.dart' as impl;

Widget buildDocumentPreviewFrame({
  required String viewType,
  required String url,
}) {
  return impl.buildDocumentPreviewFrame(viewType: viewType, url: url);
}
