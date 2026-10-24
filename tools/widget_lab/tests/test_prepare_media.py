import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "prepare_media", Path(__file__).resolve().parents[1] / "prepare_media.py"
)
media = importlib.util.module_from_spec(spec)
spec.loader.exec_module(media)


class PrepareMediaTests(unittest.TestCase):
    def test_square_source_produces_square_widget_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "square.mp4"
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
                "testsrc=size=480x480:rate=8", "-t", "2", "-c:v", "libx264", "-pix_fmt", "yuv420p", str(source),
            ], check=True)
            with patch.object(media, "ROOT", root):
                media.prepare([source])
            frame = root / "android/res/drawable-nodpi/clip_0_frame_00.jpg"
            info = json.loads(subprocess.check_output([
                "ffprobe", "-v", "error", "-show_entries", "stream=width,height", "-of", "json", str(frame),
            ]))["streams"][0]
            self.assertEqual(info["width"], info["height"], "Square videos must not be cut into landscape strips")

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
