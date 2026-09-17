import unittest

from worker import _is_identity_edit_graph


class DeviceFirstMediaTest(unittest.TestCase):
    def test_identity_edit_graph_allows_device_passthrough(self):
        graph = {
            'version': 2,
            'timeline': [
                {
                    'trimInMs': 0,
                    'trimOutMs': 10000,
                    'speed': 1.0,
                    'rotation': 0,
                    'opacity': 1.0,
                    'flipX': False,
                    'flipY': False,
                }
            ],
            'audio': [],
            'textLayers': [],
            'stickerLayers': [],
            'effectLayers': [],
            'operations': [],
        }
        self.assertTrue(_is_identity_edit_graph(graph, 10000))

    def test_trimmed_graph_requires_server_render(self):
        graph = {
            'timeline': [
                {'trimInMs': 1000, 'trimOutMs': 10000, 'speed': 1.0, 'rotation': 0}
            ],
            'audio': [],
            'textLayers': [],
            'stickerLayers': [],
            'effectLayers': [],
            'operations': [],
        }
        self.assertFalse(_is_identity_edit_graph(graph, 10000))

    def test_overlay_or_audio_requires_server_render(self):
        graph = {
            'timeline': [
                {'trimInMs': 0, 'trimOutMs': 10000, 'speed': 1.0, 'rotation': 0}
            ],
            'audio': [{'id': 'music-1'}],
            'textLayers': [],
            'stickerLayers': [],
            'effectLayers': [],
            'operations': [],
        }
        self.assertFalse(_is_identity_edit_graph(graph, 10000))


if __name__ == '__main__':
    unittest.main()
