class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.clientUserId,
    required this.clientFio,
    required this.senderId,
    required this.senderFio,
    required this.senderRole,
    required this.messageText,
    required this.createdAt,
    required this.isReadByAdmin,
  });

  final String id;
  final String clientUserId;
  final String clientFio;
  final String senderId;
  final String senderFio;
  final String senderRole;
  final String messageText;
  final String createdAt;
  final bool isReadByAdmin;

  static SupportMessage fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: (json['id'] ?? '').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
      clientFio: (json['clientFio'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderFio: (json['senderFio'] ?? '').toString(),
      senderRole: (json['senderRole'] ?? '').toString(),
      messageText: (json['messageText'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      isReadByAdmin: json['isReadByAdmin'] == true,
    );
  }
}
