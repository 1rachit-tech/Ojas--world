enum CreationPublishStage {
  draft,
  validating,
  preparing,
  uploading,
  processing,
  publishing,
  published,
  failed,
}

class CreationPublishState {
  const CreationPublishState({
    required this.projectId,
    required this.stage,
    this.requestId,
    this.bytesUploaded = 0,
    this.totalBytes = 0,
    this.errorCode,
    this.errorMessage,
    this.updatedAt,
  });

  final String projectId;
  final CreationPublishStage stage;
  final String? requestId;
  final int bytesUploaded;
  final int totalBytes;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? updatedAt;

  double get progress {
    if (totalBytes <= 0) return 0;
    final value = bytesUploaded / totalBytes;
    return value.clamp(0.0, 1.0);
  }

  bool get isTerminal =>
      stage == CreationPublishStage.published ||
      stage == CreationPublishStage.failed;

  CreationPublishState copyWith({
    CreationPublishStage? stage,
    String? requestId,
    int? bytesUploaded,
    int? totalBytes,
    String? errorCode,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return CreationPublishState(
      projectId: projectId,
      stage: stage ?? this.stage,
      requestId: requestId ?? this.requestId,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      totalBytes: totalBytes ?? this.totalBytes,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'projectId': projectId,
        'stage': stage.name,
        'requestId': requestId,
        'bytesUploaded': bytesUploaded,
        'totalBytes': totalBytes,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory CreationPublishState.fromMap(Map<String, dynamic> map) {
    final stageName = map['stage'] as String?;
    final stage = CreationPublishStage.values.firstWhere(
      (value) => value.name == stageName,
      orElse: () => CreationPublishStage.draft,
    );
    return CreationPublishState(
      projectId: map['projectId'] as String? ?? '',
      stage: stage,
      requestId: map['requestId'] as String?,
      bytesUploaded: (map['bytesUploaded'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
    );
  }
}
