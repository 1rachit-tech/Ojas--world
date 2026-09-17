import unittest
from unittest.mock import patch

import dispatcher
import render_override
import worker


class _Snapshot:
    def __init__(self, data):
        self._data = data
        self.exists = True

    def to_dict(self):
        return dict(self._data)


class _Document:
    def __init__(self, data):
        self._snapshot = _Snapshot(data)

    def get(self):
        return self._snapshot


class _Collection:
    def __init__(self, documents):
        self._documents = documents

    def document(self, document_id):
        return _Document(self._documents.get(document_id, {}))


class _Firestore:
    def __init__(self, media, reels):
        self._media = media
        self._reels = reels

    def collection(self, name):
        if name == 'creationMedia':
            return _Collection(self._media)
        if name == 'reels':
            return _Collection(self._reels)
        raise AssertionError(f'Unexpected collection: {name}')


class PublishedRenderPipelineTests(unittest.TestCase):
    def test_clip_visual_chain_applies_speed_crop_transform_and_opacity(self) -> None:
        filters = []
        label, duration_ms = render_override._clip_visual_chain(
            {
                'trimInMs': 1000,
                'trimOutMs': 5000,
                'speed': 2.0,
                'rotation': 90,
                'cropLeft': 0.10,
                'cropTop': 0.05,
                'cropRight': 0.10,
                'cropBottom': 0.05,
                'scale': 0.75,
                'x': 0.2,
                'y': -0.1,
                'opacity': 0.5,
            },
            {'durationMs': 8000, 'width': 1080, 'height': 1920},
            'v0',
            filters,
        )

        self.assertEqual(label, 'v0')
        self.assertEqual(duration_ms, 2000)
        chain = filters[0]
        self.assertIn('setpts=PTS/2.00000', chain)
        self.assertIn('crop=w=', chain)
        self.assertIn('transpose=1', chain)
        self.assertIn('colorchannelmixer=aa=0.5000', chain)
        self.assertIn('pad=720:', chain)
        self.assertIn('setsar=1', chain)

    def test_render_graph_builds_multi_clip_concat_command(self) -> None:
        captured = []
        edit_graph = {
            'timeline': [
                {'trimInMs': 0, 'trimOutMs': 2000, 'speed': 1.0, 'rotation': 0},
                {'trimInMs': 2000, 'trimOutMs': 4000, 'speed': 0.5, 'rotation': 180},
            ],
            'textLayers': [
                {'id': 't1', 'text': 'OJAS', 'startMs': 0, 'endMs': 1500, 'x': 0, 'y': 0, 'fontSize': 28},
            ],
            'effectLayers': [{'id': 'e1', 'effectId': 'vivid', 'intensity': 0.75}],
        }
        with patch.object(worker, '_run', side_effect=lambda command: captured.append(command)):
            mode = render_override.render_edit_graph(
                '/tmp/source.mp4',
                '/tmp/output.mp4',
                {'durationMs': 5000, 'width': 1080, 'height': 1920, 'hasAudio': True},
                edit_graph,
                [],
            )

        self.assertEqual(mode, 'edit-graph-v5-render')
        self.assertEqual(len(captured), 1)
        command = captured[0]
        self.assertEqual(command[0], 'ffmpeg')
        filter_complex = command[command.index('-filter_complex') + 1]
        self.assertIn('concat=n=2:v=1:a=1', filter_complex)
        self.assertIn('setpts=PTS/0.50000', filter_complex)
        self.assertIn('drawtext=', filter_complex)
        self.assertIn('eq=contrast=', filter_complex)
        self.assertIn('/tmp/output.mp4', command)


class AudioStorageSafetyTests(unittest.TestCase):
    def test_audio_path_uses_secure_creation_audio_namespace(self) -> None:
        self.assertTrue(
            dispatcher._safe_audio_path(
                'creation-audio/owner/project/layer/audio.mp3',
                'owner',
                'project',
            )
        )
        self.assertFalse(
            dispatcher._safe_audio_path(
                'creation_audio/owner/project/audio.mp3',
                'owner',
                'project',
            )
        )


class ReplacementRetentionTests(unittest.TestCase):
    def test_current_edit_graph_audio_is_retained(self) -> None:
        current = {
            'audio': [
                {'id': 'a1', 'storagePath': 'creation-audio/owner/reel/a1/audio.mp3'},
                {'id': 'a2', 'storagePath': 'creation-audio/owner/reel/a2/audio.m4a'},
            ]
        }
        retained = dispatcher._current_audio_paths(current, 'owner', 'reel')
        self.assertEqual(
            retained,
            {
                'creation-audio/owner/reel/a1/audio.mp3',
                'creation-audio/owner/reel/a2/audio.m4a',
            },
        )


class TranscodePostProcessingTests(unittest.TestCase):
    def test_ready_media_runs_server_hash_then_replacement_cleanup(self) -> None:
        db = _Firestore(
            media={
                'asset-new': {
                    'processingStatus': 'ready',
                    'processedVideoStoragePath': 'creation/owner/reel/asset-new/processed.mp4',
                },
            },
            reels={
                'reel': {
                    'mediaReplacementCleanupStatus': 'pending',
                    'mediaReplacementCleanupAssetId': 'asset-old',
                    'mediaReplacementCleanupAudioPaths': ['creation-audio/owner/reel/a1/audio.mp3'],
                    'mediaAssetId': 'asset-new',
                    'editGraph': {'audio': []},
                },
            },
        )
        calls = []
        with patch.object(worker, '_firebase', return_value=db), \
             patch.object(dispatcher, '_server_hash_job', side_effect=lambda job: calls.append(('hash', job['processedVideoStoragePath']))), \
             patch.object(dispatcher, '_replacement_cleanup_job', side_effect=lambda job: calls.append(('cleanup', job['oldAssetId']))):
            dispatcher._post_process_transcode({
                'assetId': 'asset-new',
                'projectId': 'reel',
                'ownerId': 'owner',
            })

        self.assertEqual(calls, [
            ('hash', 'creation/owner/reel/asset-new/processed.mp4'),
            ('cleanup', 'asset-old'),
        ])


if __name__ == '__main__':
    unittest.main(verbosity=2)
