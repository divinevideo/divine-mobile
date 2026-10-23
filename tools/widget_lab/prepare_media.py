#!/usr/bin/env python3
"""Sample existing local videos; generated assets stay outside version control."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
FRAME_COUNT = 16
FPS = 8


def prepare(clips):
    frames_root = ROOT / "ios/Media/Frames.xcassets"
    frames_root.mkdir(parents=True, exist_ok=True)
    (frames_root / "Contents.json").write_text(json.dumps({"info": {"version": 1, "author": "xcode"}}))
    android_drawables = ROOT / "android/res/drawable-nodpi"
    android_drawables.mkdir(parents=True, exist_ok=True)
    for index, source in enumerate(clips):
        scratch = ROOT / f".build/media/clip_{index}"
        scratch.mkdir(parents=True, exist_ok=True)
        # FFmpeg overwrites only the frames it produces. A shorter replacement
        # must not borrow the previous sample's remaining frames.
        for stale_frame in scratch.glob("frame_*.jpg"):
            stale_frame.unlink()
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
            "-t", "2", "-vf", f"fps={FPS},scale=320:180:force_original_aspect_ratio=increase,crop=320:180",
            "-frames:v", str(FRAME_COUNT), "-q:v", "3", "-start_number", "0", str(scratch / "frame_%02d.jpg"),
        ], check=True)
        for frame in range(FRAME_COUNT):
            name = f"clip_{index}_frame_{frame:02d}"
            image = scratch / f"frame_{frame:02d}.jpg"
            if not image.exists():
                raise ValueError(f"Clip {index} is too short: need at least two seconds")
            image_set = frames_root / f"{name}.imageset"
            image_set.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(image, image_set / "frame.jpg")
            (image_set / "Contents.json").write_text(json.dumps({
                "images": [{"filename": "frame.jpg", "idiom": "universal"}],
                "info": {"version": 1, "author": "xcode"},
            }))
            shutil.copyfile(image, android_drawables / f"{name}.jpg")
        for destination in [ROOT / "ios/Media/Clips", ROOT / "android/assets"]:
            destination.mkdir(parents=True, exist_ok=True)
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                "-t", "6", "-vf", "scale=640:-2", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                "-an", "-movflags", "+faststart", str(destination / f"clip_{index}.mp4"),
            ], check=True)
    print("Prepared three local clips and 16 frames per clip for both platforms.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clips", nargs="*", type=Path, help="Exactly three local video files, or use repository samples")
    args = parser.parse_args()
    clips = args.clips or sorted((ROOT.parents[1] / "mobile/assets/seed_media/videos").glob("*.mp4"))[:3]
    if len(clips) != 3 or any(not path.is_file() for path in clips):
        parser.error("Provide exactly three existing local videos")
    prepare(clips)
