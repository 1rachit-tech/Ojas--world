import unittest

from dispatcher import _safe_audio_path, _safe_audio_prefix, _safe_cleanup_prefix


class DispatcherPathTests(unittest.TestCase):
    def test_safe_audio_path_is_owner_and_project_scoped(self):
        self.assertTrue(_safe_audio_path('creation-audio/u1/p1/l1/song.mp3', 'u1', 'p1'))
        self.assertFalse(_safe_audio_path('creation-audio/u2/p1/l1/song.mp3', 'u1', 'p1'))
        self.assertFalse(_safe_audio_path('creation-audio/u1/p1/../song.mp3', 'u1', 'p1'))
        self.assertFalse(_safe_audio_path('creation/u1/p1/l1/song.mp3', 'u1', 'p1'))

    def test_cleanup_prefixes_are_exact(self):
        self.assertTrue(_safe_cleanup_prefix('creation/u1/p1/', 'u1', 'p1'))
        self.assertTrue(_safe_audio_prefix('creation-audio/u1/p1/', 'u1', 'p1'))
        self.assertFalse(_safe_cleanup_prefix('creation/u1/p1/../', 'u1', 'p1'))
        self.assertFalse(_safe_audio_prefix('creation-audio/u2/p1/', 'u1', 'p1'))


if __name__ == '__main__':
    unittest.main()
