import unittest

from worker import (
    _atempo_chain,
    _bounded_clip,
    _effect_expression,
    _escape_drawtext_text,
    _safe_creation_path,
)


class WorkerEditGraphTests(unittest.TestCase):
    def test_bounded_clip_clamps_to_source(self):
        trim_in, trim_out, speed, rotation = _bounded_clip(
            {'trimInMs': 100, 'trimOutMs': 12_000, 'speed': 2, 'rotation': 90},
            10_000,
        )
        self.assertEqual(trim_in, 100)
        self.assertEqual(trim_out, 10_000)
        self.assertEqual(speed, 2)
        self.assertEqual(rotation, 90)

    def test_atempo_chain_handles_extreme_supported_speed(self):
        self.assertEqual(_atempo_chain(4), 'atempo=2.0,atempo=2.00000')
        self.assertEqual(_atempo_chain(0.25), 'atempo=0.5,atempo=0.50000')

    def test_effect_mapping_is_bounded(self):
        self.assertTrue(_effect_expression({'effectId': 'warm', 'intensity': 0.5}))
        self.assertTrue(_effect_expression({'effectId': 'mono', 'intensity': 9}))
        self.assertIsNone(_effect_expression({'effectId': 'unknown', 'intensity': 1}))

    def test_drawtext_escape_removes_newlines_and_escapes_filters(self):
        value = _escape_drawtext_text("hello: 'world'\nnext%line")
        self.assertNotIn('\n', value)
        self.assertIn('\\:', value)
        self.assertIn("\\'", value)
        self.assertIn('\\%', value)

    def test_storage_path_allows_processed_hierarchy_but_rejects_traversal(self):
        self.assertTrue(_safe_creation_path('creation/u1/p1/a1'))
        self.assertTrue(_safe_creation_path('creation/u1/p1/a1/hls/index.m3u8'))
        self.assertFalse(_safe_creation_path('creation/u1/p1/../private'))
        self.assertFalse(_safe_creation_path('chat/u1/p1/a1'))


if __name__ == '__main__':
    unittest.main()
