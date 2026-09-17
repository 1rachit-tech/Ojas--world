import '../models/creation_project.dart';
import '../models/creation_publish_state.dart';
import 'creation_checkpoint_store.dart';
import 'creation_project_store.dart';
import 'creation_publish_service.dart';
import 'creation_publish_state_store.dart';

class CreationPublishRecoveryItem {
  const CreationPublishRecoveryItem({
    required this.project,
    required this.state,
  });

  final CreationProject project;
  final CreationPublishState state;

  bool get resumable => state.hasUploadCheckpoint;
  bool get needsRetry =>
      state.stage == CreationPublishStage.failed ||
      state.stage == CreationPublishStage.uploading ||
      state.stage == CreationPublishStage.processing ||
      state.stage == CreationPublishStage.publishing;

  double get progress => state.uploadProgress > 0 ? state.uploadProgress : state.progress;
}

/// Connects crash/interruption recovery to the Create hub without introducing
/// another backend. All recovery metadata remains on-device.
class CreationPublishRecoveryService {
  const CreationPublishRecoveryService();

  Future<List<CreationPublishRecoveryItem>> list({
    required String ownerId,
  }) async {
    if (ownerId.isEmpty) return const <CreationPublishRecoveryItem>[];

    final primary = await CreationProjectStore.instance.list(ownerId: ownerId);
    final checkpoints = await CreationCheckpointStore.instance.listLatest(ownerId: ownerId);
    final byProjectId = <String, CreationProject>{
      for (final project in primary) project.projectId: project,
    };

    for (final checkpoint in checkpoints) {
      final current = byProjectId[checkpoint.projectId];
      if (current == null || checkpoint.updatedAt.isAfter(current.updatedAt)) {
        byProjectId[checkpoint.projectId] = checkpoint;
      }
    }

    final items = <CreationPublishRecoveryItem>[];
    for (final project in byProjectId.values) {
      final state = await CreationPublishStateStore.instance.load(project.projectId);
      if (state == null || !state.needsAttention()) continue;
      items.add(CreationPublishRecoveryItem(project: project, state: state));
    }

    items.sort((a, b) {
      final aTime = a.state.updatedAt ?? a.project.updatedAt;
      final bTime = b.state.updatedAt ?? b.project.updatedAt;
      return bTime.compareTo(aTime);
    });
    return List<CreationPublishRecoveryItem>.unmodifiable(items);
  }

  Future<CreationPublishResult> resume(CreationPublishRecoveryItem item) async {
    final result = await CreationPublishService().publish(item.project);
    if (!result.isProcessing) {
      await CreationPublishStateStore.instance.clear(item.project.projectId);
    }
    return result;
  }
}

extension on CreationPublishState {
  bool needsAttention() =>
      hasUploadCheckpoint ||
      stage == CreationPublishStage.failed ||
      stage == CreationPublishStage.uploading ||
      stage == CreationPublishStage.processing ||
      stage == CreationPublishStage.publishing;
}
