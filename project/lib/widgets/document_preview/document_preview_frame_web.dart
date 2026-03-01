// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

Widget buildDocumentPreviewFrame({
  required String viewType,
  required String url,
}) {
  ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final frame = html.IFrameElement()
      ..src = url
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true;
    return frame;
  });

  return HtmlElementView(viewType: viewType);
}
