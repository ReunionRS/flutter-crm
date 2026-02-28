import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/project_models.dart';
import 'meta_row.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.clientFio,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      tooltip: 'Редактировать',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0B300)),
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: 'Удалить',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(project.constructionAddress),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  MetaRow(label: 'Статус', value: kProjectStatusLabels[project.status] ?? project.status),
                  MetaRow(label: 'Начало', value: formatDateRu(project.startDate)),
                  MetaRow(label: 'План сдачи', value: formatDateRu(project.plannedEndDate)),
                  MetaRow(label: 'Готовность', value: '${project.progress}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
