import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "prepare_media", Path(__file__).resolve().parents[1] / "prepare_media.py"
)
media = importlib.util.module_from_spec(spec)
spec.loader.exec_module(media)


class PrepareMediaTests(unittest.TestCase):
    def test_short_replacement_cannot_reuse_previous_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scratch = root / ".build/media/clip_0"
            scratch.mkdir(parents=True)
            for frame in range(media.FRAME_COUNT):
                (scratch / f"frame_{frame:02d}.jpg").write_bytes(b"old sample")

            def sample_short_clip(command, **kwargs):
                for frame in range(4):
                    (scratch / f"frame_{frame:02d}.jpg").write_bytes(b"new sample")

            with patch.object(media, "ROOT", root), patch.object(
                media.subprocess, "run", side_effect=sample_short_clip
            ):
                with self.assertRaisesRegex(ValueError, "too short"):
                    media.prepare([root / "short.mp4"])
            self.assertFalse((scratch / "frame_04.jpg").exists())
