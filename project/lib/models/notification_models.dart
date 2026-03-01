class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.type,
    required this.clientUserId,
    required this.projectId,
    required this.stageId,
  });

  final String id;
  final String title;
  final String body;
  final String createdAt;
  final bool isRead;
  final String type;
  final String clientUserId;
  final String projectId;
  final String stageId;

  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['stageName'] ?? 'Уведомление').toString(),
      body: (json['body'] ?? json['commentText'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      isRead: json['isRead'] == true,
      type: (json['type'] ?? 'stage_comment').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
      projectId: (json['projectId'] ?? '').toString(),
      stageId: (json['stageId'] ?? '').toString(),
    );
  }
}
