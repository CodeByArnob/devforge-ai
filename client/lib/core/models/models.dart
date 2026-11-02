class UserModel {
  final String id;
  final String email;
  final DateTime createdAt;

  UserModel({required this.id, required this.email, required this.createdAt});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProjectModel {
  final String id;
  final String name;
  final String sourceType;
  final int fileCount;
  final List<dynamic> languages;
  final String? ownerId;
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.fileCount,
    required this.languages,
    this.ownerId,
    required this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceType: json['source_type'] as String? ?? 'zip',
      fileCount: json['file_count'] as int? ?? 0,
      languages: json['languages'] as List<dynamic>? ?? [],
      ownerId: json['owner_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TaskModel {
  final String id;
  final String projectId;
  final String instruction;
  final String status;
  final String? selectedModel;
  final String approvalDecision;
  final String? approvalNote;
  final DateTime? approvalAt;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.instruction,
    required this.status,
    this.selectedModel,
    required this.approvalDecision,
    this.approvalNote,
    this.approvalAt,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      instruction: json['instruction'] as String,
      status: json['status'] as String,
      selectedModel: json['selected_model'] as String?,
      approvalDecision: json['approval_decision'] as String? ?? 'not_required',
      approvalNote: json['approval_note'] as String?,
      approvalAt: json['approval_at'] != null ? DateTime.parse(json['approval_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TaskEventModel {
  final int sequence;
  final String eventType;
  final String message;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  TaskEventModel({
    required this.sequence,
    required this.eventType,
    required this.message,
    required this.payload,
    required this.createdAt,
  });

  factory TaskEventModel.fromJson(Map<String, dynamic> json) {
    return TaskEventModel(
      sequence: json['sequence'] as int,
      eventType: json['event_type'] as String,
      message: json['message'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PatchProposalModel {
  final String patchId;
  final String? taskId;
  final String baseSnapshotDigest;
  final String patchDigest;
  final String? unifiedDiff;
  final List<dynamic>? changes;
  final String status;
  final String? appliedSnapshotDigest;
  final String? approvalNote;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  PatchProposalModel({
    required this.patchId,
    this.taskId,
    required this.baseSnapshotDigest,
    required this.patchDigest,
    this.unifiedDiff,
    this.changes,
    required this.status,
    this.appliedSnapshotDigest,
    this.approvalNote,
    this.createdAt,
    this.approvedAt,
  });

  factory PatchProposalModel.fromJson(Map<String, dynamic> json) {
    return PatchProposalModel(
      patchId: json['patch_id'] as String,
      taskId: json['task_id'] as String?,
      baseSnapshotDigest: json['base_snapshot_digest'] as String,
      patchDigest: json['patch_digest'] as String,
      unifiedDiff: json['unified_diff'] as String?,
      changes: json['changes'] as List<dynamic>?,
      status: json['status'] as String,
      appliedSnapshotDigest: json['applied_snapshot_digest'] as String?,
      approvalNote: json['approval_note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
    );
  }
}

class LocalGGUFModel {
  final String id;
  final String name;
  final String family;
  final String parameters;
  final String quantization;
  final String license;
  final String sha256;
  final int contextLength;
  final double fileSizeGb;
  final double minRamGb;
  final double recommendedVramGb;
  final List<String> supportedAbis;
  final String downloadUrl;

  LocalGGUFModel({
    required this.id,
    required this.name,
    required this.family,
    required this.parameters,
    required this.quantization,
    required this.license,
    required this.sha256,
    required this.contextLength,
    required this.fileSizeGb,
    required this.minRamGb,
    required this.recommendedVramGb,
    required this.supportedAbis,
    required this.downloadUrl,
  });

  factory LocalGGUFModel.fromJson(Map<String, dynamic> json) {
    return LocalGGUFModel(
      id: json['id'] as String,
      name: json['name'] as String,
      family: json['family'] as String,
      parameters: json['parameters'] as String,
      quantization: json['quantization'] as String,
      license: json['license'] as String,
      sha256: json['sha256'] as String,
      contextLength: json['context_length'] as int,
      fileSizeGb: (json['file_size_gb'] as num).toDouble(),
      minRamGb: (json['min_ram_gb'] as num).toDouble(),
      recommendedVramGb: (json['recommended_vram_gb'] as num).toDouble(),
      supportedAbis: (json['supported_abis'] as List<dynamic>).map((e) => e.toString()).toList(),
      downloadUrl: json['download_url'] as String,
    );
  }
}
