import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/project_models.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.canManage,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectSummary project;
  final bool canManage;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _statusBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0x33E0AC00) : const Color(0x1AE0AC00);
  }

  String _statusLabel() => kProjectStatusLabels[project.status] ?? project.status;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 560;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Color(0xFF9FA3AF), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.clientFio,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _statusBg(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(),
                  style: const TextStyle(
                    color: Color(0xFFE0AC00),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.location_on_outlined, color: Color(0xFF9FA3AF), size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.constructionAddress,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Готовность: ${project.progress}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: (project.progress.clamp(0, 100)) / 100,
                  backgroundColor: Theme.of(context).dividerColor.withOpacity(0.35),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE0AC00)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  Text(
                    'Начало: ${formatDateRu(project.startDate)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor),
                  ),
                  Text(
                    'План сдачи: ${formatDateRu(project.plannedEndDate)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
              if (canManage || canDelete) ...[
                const SizedBox(height: 12),
                isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canManage)
                            TextButton(
                              onPressed: onEdit,
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE0AC00), padding: EdgeInsets.zero),
                              child: const Text('РЕДАКТИРОВАТЬ', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          if (canDelete)
                            TextButton(
                              onPressed: onDelete,
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: EdgeInsets.zero),
                              child: const Text('УДАЛИТЬ', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                        ],
                      )
                    : Row(
                        children: [
                          if (canManage)
                            TextButton(
                              onPressed: onEdit,
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE0AC00), padding: EdgeInsets.zero),
                              child: const Text('РЕДАКТИРОВАТЬ', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          if (canDelete) ...[
                            const SizedBox(width: 20),
                            TextButton(
                              onPressed: onDelete,
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: EdgeInsets.zero),
                              child: const Text('УДАЛИТЬ', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
