import 'package:flutter/material.dart';

import '../../models/menu_models.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/project_card.dart';
import '../calendar/calendar_page.dart';
import '../documents/documents_page.dart';
import '../notifications/notifications_page.dart';
import '../support/support_page.dart';
import '../users/users_page.dart';
import '../projects/project_details_page.dart';
import '../projects/project_form_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.session,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  final AuthService auth;
  final AppSession session;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<ProjectSummary> _projects = const [];
  List<ClientOption> _clients = const [];
  String? _supportInitialClientId;
  bool _loading = true;
  String? _error;
  AppSection _section = AppSection.projects;

  bool get _canSeeUsers =>
      widget.session.role == 'admin' || widget.session.role == 'director';
  bool get _canManageProjects =>
      widget.session.role == 'admin' ||
      widget.session.role == 'director' ||
      widget.session.role == 'manager' ||
      widget.session.role == 'foreman';
  bool get _canDeleteProjects =>
      widget.session.role == 'admin' ||
      widget.session.role == 'director' ||
      widget.session.role == 'manager';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait<void>([
      _loadProjects(),
      _loadClients(),
    ]);
  }

  Future<void> _loadClients() async {
    try {
      final clients = await widget.auth.fetchClients();
      if (!mounted) return;
      setState(() => _clients = clients);
    } on UnauthorizedException {
      await widget.onLogout();
    } catch (_) {}
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final projects = await widget.auth.fetchProjects();
      if (!mounted) return;
      setState(() => _projects = projects);
    } on UnauthorizedException {
      await widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openProject(ProjectSummary project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(
          auth: widget.auth,
          projectId: project.id,
          role: widget.session.role,
        ),
      ),
    );
    if (mounted) {
      await _loadProjects();
    }
  }

  Future<void> _openProjectFromNotification(String projectId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(
          auth: widget.auth,
          projectId: projectId,
          role: widget.session.role,
        ),
      ),
    );
    if (mounted) {
      await _loadProjects();
    }
  }

  void _openSupportFromNotification(String? clientUserId) {
    setState(() {
      _supportInitialClientId = clientUserId;
      _section = AppSection.support;
    });
  }

  Future<void> _deleteProject(ProjectSummary project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить объект?'),
        content: Text('${project.clientFio}\n${project.constructionAddress}'),
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
      await widget.auth.deleteProject(project.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Объект удалён')));
      await _loadProjects();
    } on UnauthorizedException {
      await widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openProjectForm({ProjectSummary? existing}) async {
    ProjectDetails? detailsForEdit;
    if (existing != null) {
      try {
        detailsForEdit = await widget.auth.fetchProjectById(existing.id);
      } catch (_) {}
    }
    if (!mounted) return;

    final result = await showDialog<ProjectFormResult>(
      context: context,
      builder: (ctx) => ProjectFormDialog(
        existing: detailsForEdit,
        clients: _clients,
      ),
    );
    if (result == null) return;

    try {
      if (existing == null) {
        await widget.auth.createProject(result.payload);
      } else {
        await widget.auth.updateProject(existing.id, result.payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(existing == null ? 'Объект создан' : 'Объект обновлён')),
      );
      await _loadProjects();
    } on UnauthorizedException {
      await widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _selectSection(AppSection section, bool isDesktop) {
    if (section == AppSection.users && !_canSeeUsers) return;
    setState(() => _section = section);

    // On mobile close drawer after selection.
    if (!isDesktop && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String get _title {
    return switch (_section) {
      AppSection.projects => 'Объекты',
      AppSection.documents => 'Документы',
      AppSection.support => 'Поддержка',
      AppSection.notifications => 'Уведомления',
      AppSection.calendar => 'Календарь',
      AppSection.users => 'Пользователи',
    };
  }

  Widget _buildProjectsContent() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _projects.where((p) {
      if (query.isEmpty) return true;
      return p.clientFio.toLowerCase().contains(query) ||
          p.constructionAddress.toLowerCase().contains(query);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Поиск по ФИО или адресу',
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
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          if (!_loading && _error == null && filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Объекты не найдены')),
            ),
          for (final project in filtered)
            ProjectCard(
              project: project,
              canManage: _canManageProjects,
              canDelete: _canDeleteProjects,
              onOpen: () => _openProject(project),
              onEdit: () => _openProjectForm(existing: project),
              onDelete: () => _deleteProject(project),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_section) {
      AppSection.projects => _buildProjectsContent(),
      AppSection.documents =>
        DocumentsPage(auth: widget.auth, role: widget.session.role),
      AppSection.support => SupportPage(
          auth: widget.auth,
          session: widget.session,
          onUnauthorized: widget.onLogout,
          initialClientUserId: _supportInitialClientId),
      AppSection.notifications => NotificationsPage(
          auth: widget.auth,
          onOpenSupportChat: _openSupportFromNotification,
          onOpenProject: _openProjectFromNotification),
      AppSection.calendar => CalendarPage(
          auth: widget.auth,
          role: widget.session.role,
          onUnauthorized: widget.onLogout),
      AppSection.users => UsersPage(
          auth: widget.auth,
          role: widget.session.role,
          onUnauthorized: widget.onLogout),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    final sidebar = AppSidebar(
      role: widget.session.role,
      isDarkMode: widget.isDarkMode,
      selectedSection: _section,
      onSelect: (section) => _selectSection(section, isDesktop),
      onToggleTheme: widget.onToggleTheme,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          TextButton(
            onPressed: () => widget.onLogout(),
            child: const Text('Выйти'),
          ),
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              width: 320,
              child: sidebar,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1520),
          child: isDesktop
              ? Row(
                  children: [
                    SizedBox(width: 320, child: sidebar),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildBody()),
                  ],
                )
              : _buildBody(),
        ),
      ),
      floatingActionButton:
          _section == AppSection.projects && _canManageProjects
              ? FloatingActionButton.extended(
                  onPressed: () => _openProjectForm(),
                  backgroundColor: const Color(0xFFE0B300),
                  label: const Text('Добавить объект'),
                  icon: const Icon(Icons.add),
                )
              : null,
    );
  }
}
