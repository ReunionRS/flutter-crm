class ProjectSummary {
  ProjectSummary({
    required this.id,
    required this.clientFio,
    required this.constructionAddress,
    required this.status,
    required this.startDate,
    required this.plannedEndDate,
    required this.progress,
  });

  final String id;
  final String clientFio;
  final String constructionAddress;
  final String status;
  final String startDate;
  final String plannedEndDate;
  final int progress;

  static ProjectSummary fromJson(Map<String, dynamic> json) {
    final stages = (json['stages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final total = stages.length;
    final done = stages.where((s) => (s['status'] ?? '').toString().toLowerCase() == 'completed').length;

    return ProjectSummary(
      id: (json['id'] ?? '').toString(),
      clientFio: (json['clientFio'] ?? '—').toString(),
      constructionAddress: (json['constructionAddress'] ?? '—').toString(),
      status: (json['status'] ?? '—').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      plannedEndDate: (json['plannedEndDate'] ?? '').toString(),
      progress: total == 0 ? 0 : ((done / total) * 100).round(),
    );
  }
}

class ProjectStage {
  ProjectStage({
    required this.id,
    required this.name,
    required this.status,
    required this.plannedStart,
    required this.plannedEnd,
    required this.stageComment,
    required this.comments,
    required this.photoUrls,
  });

  final String id;
  final String name;
  final String status;
  final String plannedStart;
  final String plannedEnd;
  final String stageComment;
  final String comments;
  final List<String> photoUrls;

  static ProjectStage fromJson(Map<String, dynamic> json, int index) {
    final rawPhotos = (json['photoUrls'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return ProjectStage(
      id: (json['id'] ?? 'stage-$index').toString(),
      name: (json['name'] ?? 'Этап ${index + 1}').toString(),
      status: (json['status'] ?? 'not_started').toString(),
      plannedStart: (json['plannedStart'] ?? '').toString(),
      plannedEnd: (json['plannedEnd'] ?? '').toString(),
      stageComment: (json['stageComment'] ?? '').toString(),
      comments: (json['comments'] ?? '').toString(),
      photoUrls: rawPhotos,
    );
  }

  ProjectStage copyWith({
    String? id,
    String? name,
    String? status,
    String? plannedStart,
    String? plannedEnd,
    String? stageComment,
    String? comments,
    List<String>? photoUrls,
  }) {
    return ProjectStage(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      plannedStart: plannedStart ?? this.plannedStart,
      plannedEnd: plannedEnd ?? this.plannedEnd,
      stageComment: stageComment ?? this.stageComment,
      comments: comments ?? this.comments,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'status': status,
      'plannedStart': plannedStart,
      'plannedEnd': plannedEnd,
      'stageComment': stageComment,
      'comments': comments,
      'photoUrls': photoUrls,
    };
  }
}

class ProjectDetails {
  ProjectDetails({
    required this.id,
    required this.clientFio,
    required this.clientPhone,
    required this.clientEmail,
    required this.constructionAddress,
    required this.projectType,
    required this.status,
    required this.areaSqm,
    required this.startDate,
    required this.plannedEndDate,
    required this.actualEndDate,
    required this.estimatedCost,
    required this.contractAmount,
    required this.paidAmount,
    required this.nextPaymentDate,
    required this.lastPaymentDate,
    required this.cameraUrl,
    required this.clientUserId,
    required this.stages,
  });

  final String id;
  final String clientFio;
  final String clientPhone;
  final String clientEmail;
  final String constructionAddress;
  final String projectType;
  final String status;
  final num areaSqm;
  final String startDate;
  final String plannedEndDate;
  final String actualEndDate;
  final num estimatedCost;
  final num contractAmount;
  final num paidAmount;
  final String nextPaymentDate;
  final String lastPaymentDate;
  final String cameraUrl;
  final String clientUserId;
  final List<ProjectStage> stages;

  static ProjectDetails fromJson(Map<String, dynamic> json) {
    final rawStages = (json['stages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return ProjectDetails(
      id: (json['id'] ?? '').toString(),
      clientFio: (json['clientFio'] ?? '').toString(),
      clientPhone: (json['clientPhone'] ?? '').toString(),
      clientEmail: (json['clientEmail'] ?? '').toString(),
      constructionAddress: (json['constructionAddress'] ?? '').toString(),
      projectType: (json['projectType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      areaSqm: (json['areaSqm'] as num?) ?? 0,
      startDate: (json['startDate'] ?? '').toString(),
      plannedEndDate: (json['plannedEndDate'] ?? '').toString(),
      actualEndDate: (json['actualEndDate'] ?? '').toString(),
      estimatedCost: (json['estimatedCost'] as num?) ?? 0,
      contractAmount: (json['contractAmount'] as num?) ?? 0,
      paidAmount: (json['paidAmount'] as num?) ?? 0,
      nextPaymentDate: (json['nextPaymentDate'] ?? '').toString(),
      lastPaymentDate: (json['lastPaymentDate'] ?? '').toString(),
      cameraUrl: (json['cameraUrl'] ?? '').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
      stages: List.generate(rawStages.length, (i) => ProjectStage.fromJson(rawStages[i], i)),
    );
  }

  num get debt => (contractAmount - paidAmount) > 0 ? (contractAmount - paidAmount) : 0;

  int get progress {
    if (stages.isEmpty) return 0;
    final completed = stages.where((s) => s.status == 'completed').length;
    return ((completed / stages.length) * 100).round();
  }

  Map<String, dynamic> toPatchJson({
    List<ProjectStage>? stagesOverride,
    num? contractAmountOverride,
    num? paidAmountOverride,
    String? nextPaymentDateOverride,
    String? lastPaymentDateOverride,
  }) {
    return <String, dynamic>{
      'clientFio': clientFio,
      'clientPhone': clientPhone,
      'clientContacts': clientPhone,
      'clientEmail': clientEmail,
      'clientUserId': clientUserId.isEmpty ? null : clientUserId,
      'constructionAddress': constructionAddress,
      'projectType': projectType.isEmpty ? 'typical' : projectType,
      'areaSqm': areaSqm,
      'estimatedCost': estimatedCost,
      'status': status.isEmpty ? 'in_progress' : status,
      'startDate': startDate,
      'plannedEndDate': plannedEndDate,
      'actualEndDate': actualEndDate,
      'cameraUrl': cameraUrl,
      'contractAmount': contractAmountOverride ?? contractAmount,
      'paidAmount': paidAmountOverride ?? paidAmount,
      'nextPaymentDate': nextPaymentDateOverride ?? nextPaymentDate,
      'lastPaymentDate': lastPaymentDateOverride ?? lastPaymentDate,
      'stages': (stagesOverride ?? stages).map((s) => s.toJson()).toList(growable: false),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}

class ProjectDocument {
  const ProjectDocument({
    required this.id,
    required this.projectId,
    required this.clientUserId,
    required this.name,
    required this.type,
    required this.mimeType,
    required this.size,
    required this.version,
    required this.storagePath,
    required this.uploadedAt,
  });

  final String id;
  final String projectId;
  final String clientUserId;
  final String name;
  final String type;
  final String mimeType;
  final int size;
  final int version;
  final String storagePath;
  final String uploadedAt;

  static ProjectDocument fromJson(Map<String, dynamic> json) {
    return ProjectDocument(
      id: (json['id'] ?? '').toString(),
      projectId: (json['projectId'] ?? '').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
      storagePath: (json['storagePath'] ?? '').toString(),
      uploadedAt: (json['uploadedAt'] ?? '').toString(),
    );
  }

  bool get isPdf => mimeType.toLowerCase().contains('pdf') || name.toLowerCase().endsWith('.pdf');
  bool get isDocx =>
      mimeType.toLowerCase().contains('word') ||
      mimeType.toLowerCase().contains('officedocument') ||
      name.toLowerCase().endsWith('.docx') ||
      name.toLowerCase().endsWith('.doc');
}
