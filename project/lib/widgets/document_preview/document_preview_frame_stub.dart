import 'package:flutter/material.dart';

Widget buildDocumentPreviewFrame({
  required String viewType,
  required String url,
}) {
  return const Center(
    child: Text(
      'Встроенный просмотр недоступен на этой платформе.\nОткройте документ по ссылке.',
      textAlign: TextAlign.center,
    ),
  );
}
