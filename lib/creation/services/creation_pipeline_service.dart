import 'package:uuid/uuid.dart';

import '../models/creation_project.dart';

/// Production-safe orchestration rules for the Create -> Edit -> Post pipeline.
/// This service owns state transitions only; media processing/upload remains behind
/// dedicated services so the UI never mutates another layer's state directly.
class CreationPipelineService {
  const CreationPipelineService._();

  static const String schemaVersion = 'creation-pipeline-v2';

  static CreationProject checkpoint(
    CreationProject project, {
    CreationProjectStatus? status,
    Map<String, dynamic>? publishState,
  }) {
    final now = DateTime.now();
    return project.copyWith(
      status: status ?? project.status,
      version: project.version + 1,
      updatedAt: now,
      publishState: <String, dynamic>{
        ...project.publishState,
        ...?publishState,
        'schemaVersion': schemaVersion,
        'lastCheckpointAt': now.toIso8601String(),
      },
    );
  }

  static CreationProject markStage(
    CreationProject project,
    CreationProjectStatus status, {
    String? stageName,
    String? requestId,
  }) {
    final now = DateTime.now();
    final request = requestId ?? project.publishState['requestId'] as String?;
    return checkpoint(
      project,
      status: status,
      publishState: <String, dynamic>{
        'stage': stageName ?? status.name,
        'stageUpdatedAt': now.toIso8601String(),
        if (request != null && request.isNotEmpty) 'requestId': request,
      },
    );
  }

  static String ensureRequestId(CreationProject project) {
    final existing = project.publishState['publishRequestId'];
    if (existing is String && existing.isNotEmpty) return existing;
    return const Uuid().v4();
  }
}
