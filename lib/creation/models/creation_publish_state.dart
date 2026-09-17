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
    this.uploadStoragePath,
    this.uploadSourceFingerprint,
    this.uploadBytes = 0,
    this.uploadTotalBytes = 0,
    this.uploadBlockSize = 0,
  });

  final String projectId;
  final CreationPublishStage stage;
  final String? requestId;
  final int bytesUploaded;
  final int totalBytes;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? updatedAt;

  /// Durable local upload checkpoint metadata. No SAS token is stored here.
  final String? uploadStoragePath;
  final String? uploadSourceFingerprint;
  final int uploadBytes;
  final int uploadTotalBytes;
  final int uploadBlockSize;

  double get progress {
    if (totalBytes <= 0) return 0;
    final value = bytesUploaded / totalBytes;
    return value.clamp(0.0, 1.0);
  }

  double get uploadProgress {
    if (uploadTotalBytes <= 0) return 0;
    final value = uploadBytes / uploadTotalBytes;
    return value.clamp(0.0, 1.0);
  }

  bool get hasUploadCheckpoint =>
      uploadStoragePath != null &&
      uploadStoragePath!.isNotEmpty &&
      uploadSourceFingerprint != null &&
      uploadSourceFingerprint!.isNotEmpty &&
      uploadBytes > 0 &&
      uploadTotalBytes > 0 &&
      uploadBlockSize > 0 &&
      uploadBytes <= uploadTotalBytes;

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
    String? uploadStoragePath,
    String? uploadSourceFingerprint,
    int? uploadBytes,
    int? uploadTotalBytes,
    int? uploadBlockSize,
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
      uploadStoragePath: uploadStoragePath ?? this.uploadStoragePath,
      uploadSourceFingerprint: uploadSourceFingerprint ?? this.uploadSourceFingerprint,
      uploadBytes: uploadBytes ?? this.uploadBytes,
      uploadTotalBytes: uploadTotalBytes ?? this.uploadTotalBytes,
      uploadBlockSize: uploadBlockSize ?? this.uploadBlockSize,
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
        'uploadStoragePath': uploadStoragePath,
        'uploadSourceFingerprint': uploadSourceFingerprint,
        'uploadBytes': uploadBytes,
        'uploadTotalBytes': uploadTotalBytes,
        'uploadBlockSize': uploadBlockSize,
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
      uploadStoragePath: map['uploadStoragePath'] as String?,
      uploadSourceFingerprint: map['uploadSourceFingerprint'] as String?,
      uploadBytes: (map['uploadBytes'] as num?)?.toInt() ?? 0,
      uploadTotalBytes: (map['uploadTotalBytes'] as num?)?.toInt() ?? 0,
      uploadBlockSize: (map['uploadBlockSize'] as num?)?.toInt() ?? 0,
    );
  }
}
