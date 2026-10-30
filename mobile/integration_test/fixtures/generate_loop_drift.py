#!/usr/bin/env python3
"""Generate encoded, synthetic camera/subject fixtures for native verification.

Usage: python3 integration_test/fixtures/generate_loop_drift.py /absolute/output/dir
Requires ffmpeg on PATH. Produces no account or camera footage.
"""
import math
import pathlib
import subprocess
import sys

output = pathlib.Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
cases = [
    (orientation + suffix, width, height, kind)
    for orientation, width, height in [('portrait', 180, 320), ('landscape', 320, 180)]
    for suffix, kind in [('', 'translation'), ('-rotation', 'rotation'), ('-subject', 'subject'), ('-ambiguous', 'ambiguous')]
]
for name, width, height, kind in cases:
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
            fraction = frame / 89
            shift = 2 * fraction if kind in ('translation', 'ambiguous') else 0
            angle = .01 * fraction if kind == 'rotation' else 0
            scale = 1.01 ** fraction if kind == 'rotation' else 1
            cosine, sine = math.cos(angle), math.sin(angle)
            pixels = bytearray(width * height)
            for y in range(height):
                for x in range(width):
                    cx, cy = x - width / 2 - shift, y - height / 2
                    sx = (cosine * cx + sine * cy) / scale + width / 2
                    sy = (-sine * cx + cosine * cy) / scale + height / 2
                    value = 100 if kind in ('subject', 'ambiguous') and (sx < width * .1 or sy < height * .1) else (
                        100 + 26 * math.sin(sx * .43 + sy * .11)
                        + 23 * math.cos(sy * .37 - sx * .09)
                        + 21 * math.sin(sx * .17 + sy * .23)
                        + 17 * math.cos(sx * .61 - sy * .41)
                    )
                    if kind == 'subject' and x > width * .1 and y > height * .1:
                        phase = 1 + 2 * fraction
                        value = 160 + 40 * math.sin((x - phase) * .7) * math.cos((y + phase) * .6)
                    pixels[y * width + x] = max(0, min(255, round(value)))
            process.stdin.write(pixels)
    finally:
        process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError(f'ffmpeg failed for {name}')
    print(f'{name}: {width * 4}x{height * 4}, 90 frames, 3s, AAC audio')
