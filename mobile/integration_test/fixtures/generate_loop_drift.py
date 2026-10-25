#!/usr/bin/env python3
"""Generate encoded, synthetic camera-drift fixtures for native verification.

Usage: python3 integration_test/fixtures/generate_loop_drift.py /absolute/output/dir
Requires ffmpeg on PATH. Produces no account or camera footage.
"""
import math
import pathlib
import subprocess
import sys

output = pathlib.Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
for name, width, height in [('portrait', 180, 320), ('landscape', 320, 180)]:
    command = [
        'ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pixel_format', 'gray',
        '-video_size', f'{width}x{height}', '-framerate', '30', '-i', 'pipe:0',
        '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=3',
        '-vf', 'scale=iw*4:ih*4:flags=lanczos,format=yuv420p',
        '-c:v', 'libx264', '-crf', '16', '-preset', 'fast', '-c:a', 'aac',
        '-b:a', '96k', '-shortest', '-movflags', '+faststart',
        str(output / f'{name}-drift.mp4'),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    try:
        for frame in range(90):
            shift = 2 * frame / 89
            pixels = bytearray(width * height)
            for y in range(height):
                for x in range(width):
                    sx, sy = x - shift, y
                    value = 100 if sx < width * .1 or sy < height * .1 else (
                        100 + 26 * math.sin(sx * .43 + sy * .11)
                        + 23 * math.cos(sy * .37 - sx * .09)
                        + 21 * math.sin(sx * .17 + sy * .23)
                        + 17 * math.cos(sx * .61 - sy * .41)
                    )
                    pixels[y * width + x] = max(0, min(255, round(value)))
            process.stdin.write(pixels)
    finally:
        process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError(f'ffmpeg failed for {name}')
    print(f'{name}: {width * 4}x{height * 4}, 90 frames, 3s, AAC audio')
