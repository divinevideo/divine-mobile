"""Run the actual helper; decode synthetic output independently of GES."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import queue
import threading
import unittest

WORKER = Path(sys.argv.pop(1)).resolve()
FIXTURE = Path(__file__).resolve().parents[2] / "test/fixtures/synthetic-colors.mp4"


class WorkerTests(unittest.TestCase):
    def invoke(self, method="renderVideo", args=None, raw=None, on_data=None):
        self.directory = tempfile.TemporaryDirectory(prefix="native media test ")
        self.addCleanup(self.directory.cleanup)
        request = dict(protocol=1, method=method, arguments=args or {},
                       workingDirectory=self.directory.name)
        # communicate closes stdin. Native clients keep it open until result;
        # this test supplies a pipe and acknowledges the result below instead.
        child = subprocess.Popen([str(WORKER)], stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                 text=True)
        self.addCleanup(self.stop, child)
        child.stdin.write((raw if raw is not None else json.dumps(request)) + "\n")
        child.stdin.flush()
        events = []
        lines = queue.Queue()
        def read_lines():
            for line in child.stdout:
                lines.put(line)
            lines.put(None)
        reader = threading.Thread(target=read_lines, daemon=True)
        reader.start()
        while True:
            line = lines.get(timeout=30)
            if line is None:
                break
            event = json.loads(line)
            events.append(event)
            self.assertEqual(event["protocol"], 1)
            if event['event'] == 'data':
                self.assertEqual(event['sequence'], 1 + sum(e['event'] == 'data' for e in events[:-1]))
                if on_data:
                    on_data(event['value'])
                child.stdin.write(json.dumps(dict(protocol=1, ack=event['sequence'])) + '\n')
                child.stdin.flush()
            if event["event"] in ("result", "error"):
                child.stdin.close()
                break
        child.wait(timeout=30)
        reader.join(timeout=1)
        self.assertFalse(reader.is_alive())
        child.stdout.close()
        return child.returncode, events

    @staticmethod
    def stop(child):
        if child.poll() is None:
            child.kill()
            child.wait()
        if child.stdin and not child.stdin.closed:
            child.stdin.close()
        if child.stdout:
            child.stdout.close()

    def test_bad_json_is_classified_without_echoing_payload(self):
        code, events = self.invoke(raw="synthetic-private-payload")
        self.assertNotEqual(code, 0)
        self.assertEqual(events, [dict(protocol=1, event="error", value="request")])

    def test_missing_input_has_no_output(self):
        code, events = self.invoke(args={"videoClips": [{"inputPath": "/missing"}]})
        self.assertNotEqual(code, 0)
        self.assertEqual(events[-1]["value"], "input")
        self.assertEqual(list(Path(self.directory.name).iterdir()), [])

    def test_unknown_effect_is_rejected_instead_of_silently_omitted(self):
        code, events = self.invoke(args={
            "videoClips": [{"inputPath": str(FIXTURE)}],
            "customEffects": [{"effectId": "unimplemented"}],
        })
        self.assertNotEqual(code, 0)
        self.assertEqual(events[-1]["value"], "unsupported")
        self.assertEqual(list(Path(self.directory.name).iterdir()), [])

    def test_metadata_matches_encoded_media(self):
        code, events = self.invoke('getMetadata', {
            'inputPath': str(FIXTURE), 'extension': 'mp4',
            'checkStreamingOptimization': True,
        })
        self.assertEqual(code, 0, events)
        metadata = events[-1]['value']
        self.assertEqual((metadata['width'], metadata['height']), (128, 240))
        self.assertAlmostEqual(metadata['duration'], 1000, delta=50)
        self.assertEqual(metadata['rotation'], 0)
        self.assertEqual(metadata['fileSize'], FIXTURE.stat().st_size)
        self.assertEqual(metadata['frameRate'], 20.0)
        self.assertFalse(metadata['isOptimizedForStreaming'])
        self.assertNotIn('latitude', metadata)
        self.assertNotIn('longitude', metadata)

    def test_metadata_supports_audio_only_imports_without_inventing_video_dimensions(self):
        directory = tempfile.TemporaryDirectory(prefix='audio only input ')
        self.addCleanup(directory.cleanup)
        source = Path(directory.name) / 'audio.wav'
        subprocess.run(['ffmpeg', '-v', 'error', '-i', str(FIXTURE), '-vn',
            '-c:a', 'pcm_s16le', str(source)], check=True)
        code, events = self.invoke('getMetadata', {'inputPath': str(source)})
        self.assertEqual(code, 0, events)
        metadata = events[-1]['value']
        self.assertEqual((metadata['width'], metadata['height']), (0, 0))
        self.assertFalse(metadata['hasVideo'])
        self.assertTrue(metadata['hasAudio'])
        self.assertAlmostEqual(metadata['duration'], 1000, delta=50)
        self.assertNotIn('frameRate', metadata)

    def test_detects_actual_audio_track(self):
        code, events = self.invoke('hasAudioTrack', {'inputPath': str(FIXTURE)})
        self.assertEqual(code, 0, events)
        self.assertIs(events[-1]['value'], True)

    def test_requested_network_optimization_moves_metadata_before_media(self):
        code, events = self.invoke(args={
            'videoClips': [{'inputPath': str(FIXTURE), 'startUs': 250000, 'endUs': 750000}],
            'maxFrameRate': 20, 'shouldOptimizeForNetworkUse': True,
        })
        self.assertEqual(code, 0, events)
        output = Path(events[-1]['value']['path'])
        data = output.read_bytes()
        self.assertLess(data.index(b'moov'), data.index(b'mdat'))
        code, checked = self.invoke('getMetadata', {
            'inputPath': str(output), 'checkStreamingOptimization': True,
        })
        self.assertEqual(code, 0, checked)
        self.assertTrue(checked[-1]['value']['isOptimizedForStreaming'])
        subprocess.run(['ffmpeg', '-v', 'error', '-i', str(output), '-f', 'null', '-'],
                       check=True, stderr=subprocess.PIPE)

    def test_rotated_input_uses_its_display_canvas(self):
        directory = tempfile.TemporaryDirectory(prefix='rotated source ')
        self.addCleanup(directory.cleanup)
        source = Path(directory.name) / 'rotated.mp4'
        subprocess.run(['ffmpeg', '-v', 'error', '-display_rotation:v:0', '90',
                        '-i', str(FIXTURE), '-c', 'copy', str(source)], check=True)
        encoded = json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
            '-show_entries', 'stream_side_data=rotation', '-of', 'json', str(source)]))
        rotations = [side['rotation'] for stream in encoded['streams']
            for side in stream.get('side_data_list', []) if 'rotation' in side]
        self.assertEqual(rotations, [90])
        code, events = self.invoke('getMetadata', {'inputPath': str(source)})
        self.assertEqual(code, 0, events)
        self.assertEqual((events[-1]['value']['width'], events[-1]['value']['height']), (240, 128))
        code, thumbs = self.invoke('getThumbnails', {
            'inputPath': str(source), 'timestamps': [250000], 'outputWidth': 64,
            'outputHeight': 64, 'outputFormat': 'png', 'boxFit': 'contain',
        })
        self.assertEqual(code, 0, thumbs)
        actual = self.rgb(Path(thumbs[-1]['value'][0]['path']))
        expected = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(source),
            '-vf', 'scale=64:34', '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])
        self.assertEqual(len(actual), 64 * 34 * 3)
        for x, y in [(8, 4), (56, 4), (8, 28), (56, 28)]:
            offset = (y * 64 + x) * 3
            for index in range(3):
                self.assertAlmostEqual(actual[offset + index], expected[offset + index], delta=8)
        code, events = self.invoke(args={
            'videoClips': [{'inputPath': str(source), 'startUs': 250000, 'endUs': 750000}],
            'maxFrameRate': 20,
        })
        self.assertEqual(code, 0, events)
        output = Path(events[-1]['value']['path'])
        data = json.loads(subprocess.check_output([
            'ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(output)]))
        video = next(s for s in data['streams'] if s['codec_type'] == 'video')
        self.assertEqual((video['width'], video['height']), (240, 128))
        def frame(file):
            return subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(file),
                '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])
        expected, actual = frame(source), frame(output)
        self.assertEqual(len(actual), 240 * 128 * 3)
        for x, y in [(30, 16), (210, 16), (30, 112), (210, 112)]:
            offset = (y * 240 + x) * 3
            for index in range(3):
                self.assertAlmostEqual(actual[offset + index], expected[offset + index], delta=20)

    def test_trim_flip_preserves_real_video_and_audio(self):
        code, events = self.invoke(args={
            "videoClips": [{"inputPath": str(FIXTURE), "startUs": 250000,
                            "endUs": 750000}],
            "flipX": True, "enableAudio": True, "maxFrameRate": 20,
        })
        self.assertEqual(code, 0, events)
        self.assertEqual(events[-1]["event"], "result")
        output = Path(events[-1]["value"]["path"])
        self.assertEqual(output.parent, Path(self.directory.name))
        streams = json.loads(subprocess.check_output([
            "ffprobe", "-v", "error", "-count_frames", "-show_streams",
            "-show_format", "-of", "json", str(output),
        ]))
        video = next(s for s in streams["streams"] if s["codec_type"] == "video")
        audio = next(s for s in streams["streams"] if s["codec_type"] == "audio")
        self.assertEqual((video["codec_name"], video["width"], video["height"]),
                         ("h264", 128, 240))
        self.assertEqual(video["nb_read_frames"], "10")
        self.assertEqual(audio["codec_name"], "aac")
        self.assertAlmostEqual(float(streams["format"]["duration"]), 0.5, delta=0.06)
        pixels = subprocess.check_output([
            "ffmpeg", "-v", "error", "-i", str(output), "-frames:v", "1",
            "-f", "rawvideo", "-pix_fmt", "rgb24", "-",
        ])
        def pixel(x, y):
            start = (y * 128 + x) * 3
            return tuple(pixels[start:start + 3])
        left, right = pixel(16, 120), pixel(112, 120)
        self.assertGreater(left[2], 220, (left, right))
        self.assertLess(left[0], 30)
        self.assertGreater(right[0], 220)
        self.assertLess(right[2], 30)
        samples = subprocess.check_output([
            "ffmpeg", "-v", "error", "-i", str(output), "-vn",
            "-f", "s16le", "-ac", "1", "-ar", "16000", "-",
        ])
        import array
        audio_samples = array.array("h", samples)
        rms = (sum(float(x) ** 2 for x in audio_samples) / len(audio_samples)) ** 0.5
        self.assertGreater(rms, 100)
        subprocess.run(["ffmpeg", "-v", "error", "-i", str(output),
                        "-f", "null", "-"], check=True, stderr=subprocess.PIPE)


    def moving_fixture(self):
        directory = tempfile.TemporaryDirectory(prefix='changing frames ')
        self.addCleanup(directory.cleanup)
        output = Path(directory.name) / 'changing.mp4'
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
            'color=red:s=128x240:r=10:d=0.5', '-f', 'lavfi', '-i',
            'color=blue:s=128x240:r=10:d=0.5', '-filter_complex',
            '[0:v][1:v]concat=n=2:v=1:a=0', '-c:v', 'libx264', str(output)], check=True)
        return output

    @staticmethod
    def rgb(file):
        return subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(file),
            '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])

    def test_thumbnail_seeks_requested_time_and_uses_contain_dimensions(self):
        source = self.moving_fixture()
        code, events = self.invoke('getThumbnails', {
            'inputPath': str(source), 'timestamps': [100000, 800000],
            'outputWidth': 64, 'outputHeight': 64, 'outputFormat': 'png',
            'boxFit': 'contain', 'jpegQuality': 90,
        })
        self.assertEqual(code, 0, events)
        files = [Path(value['path']) for value in events[-1]['value']]
        self.assertEqual(len(files), 2)
        for file in files:
            probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
                '-show_streams', '-of', 'json', str(file)]))['streams'][0]
            self.assertEqual((probe['width'], probe['height']), (34, 64))
        red, blue = [self.rgb(file) for file in files]
        self.assertGreater(red[0], 220)
        self.assertLess(red[2], 30)
        self.assertGreater(blue[2], 220)
        self.assertLess(blue[0], 30)

    def test_thumbnail_cover_matches_sdk_scaled_aspect_and_jpeg(self):
        code, events = self.invoke('getThumbnails', {
            'inputPath': str(FIXTURE), 'timestamps': [250000],
            'outputWidth': 64, 'outputHeight': 64, 'outputFormat': 'jpeg',
            'boxFit': 'cover', 'jpegQuality': 75,
        })
        self.assertEqual(code, 0, events)
        file = Path(events[-1]['value'][0]['path'])
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
            '-show_streams', '-of', 'json', str(file)]))['streams'][0]
        self.assertEqual((probe['codec_name'], probe['width'], probe['height']),
                         ('mjpeg', 64, 120))
        pixels = self.rgb(file)
        self.assertGreater(pixels[(60 * 64 + 8) * 3], 220)
        self.assertGreater(pixels[(60 * 64 + 56) * 3 + 2], 220)

    def test_thumbnail_stream_reuses_file_only_after_acknowledged_consumption(self):
        source = self.moving_fixture()
        frames = []
        def consume(value):
            file = Path(value['path'])
            self.assertEqual(file.parent, Path(self.directory.name))
            frames.append((value, self.rgb(file)))
        code, events = self.invoke('startThumbnailStream', {
            'inputPath': str(source), 'timestamps': [100000, 800000],
            'outputWidth': 64, 'outputHeight': 64, 'outputFormat': 'png',
            'boxFit': 'contain', 'jpegQuality': 90,
        }, on_data=consume)
        self.assertEqual(code, 0, events)
        self.assertEqual([v['indices'] for v, _ in frames], [[0], [1]])
        self.assertEqual([v['progress'] for v, _ in frames], [0.5, 1.0])
        self.assertEqual(frames[0][0]['path'], frames[1][0]['path'])
        self.assertGreater(frames[0][1][0], 220)
        self.assertGreater(frames[1][1][2], 220)

    def test_luma_stream_has_real_pts_tight_rows_range_and_rate_limit(self):
        source = self.moving_fixture()
        frames = []
        def consume(value):
            frames.append((value, Path(value['path']).read_bytes()))
        code, events = self.invoke('startFrameStream', {
            'inputPath': str(source), 'outputWidth': 63, 'outputHeight': 63,
            'startUs': 200000, 'endUs': 900000, 'maxFrameRate': 5,
        }, on_data=consume)
        self.assertEqual(code, 0, events)
        self.assertEqual([v['ptsUs'] for v, _ in frames], [200000, 400000, 600000, 800000])
        for value, pixels in frames:
            self.assertEqual((value['width'], value['height']), (33, 63))
            self.assertEqual(len(pixels), 33 * 63)
        self.assertGreater(frames[0][1][0], frames[-1][1][0] + 20, [(min(p), max(p), p[len(p)//2]) for _, p in frames])

    def test_unacknowledged_stream_frame_cannot_be_reused_and_future_ack_is_rejected(self):
        directory = tempfile.TemporaryDirectory(prefix='leased native frame ')
        self.addCleanup(directory.cleanup)
        child = subprocess.Popen([str(WORKER)], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.addCleanup(self.stop, child)
        request = dict(protocol=1, method='startThumbnailStream',
            workingDirectory=directory.name, arguments=dict(inputPath=str(FIXTURE),
            timestamps=[100000, 800000], outputWidth=64, outputHeight=64,
            outputFormat='png', boxFit='contain'))
        child.stdin.write(json.dumps(request) + '\n')
        child.stdin.flush()
        lines = queue.Queue()
        def read_lines():
            for line in child.stdout:
                lines.put(json.loads(line))
        reader = threading.Thread(target=read_lines, daemon=True)
        reader.start()
        first = lines.get(timeout=30)
        self.assertEqual((first['event'], first['sequence']), ('data', 1))
        file = Path(first['value']['path'])
        original = file.read_bytes()
        self.assertGreater(len(original), 0)
        # This is a bounded assertion of protocol quiescence, not a wait for
        # decoding to finish: no second event is legal before this ACK.
        with self.assertRaises(queue.Empty):
            lines.get(timeout=0.2)
        self.assertEqual(file.read_bytes(), original)
        child.stdin.write(json.dumps(dict(protocol=1, ack=2)) + '\n')
        child.stdin.flush()
        self.assertEqual(child.wait(timeout=5), 2)
        reader.join(timeout=1)
        self.assertFalse(reader.is_alive())
        self.assertEqual(file.read_bytes(), original)

    def test_reader_rejects_invalid_size_and_range_before_writing(self):
        for patch in [{'outputWidth': 0}, {'endUs': 2, 'startUs': 4},
                      {'maxFrameRate': -1}]:
            code, events = self.invoke('startFrameStream', dict(dict(inputPath=str(FIXTURE), outputWidth=64, outputHeight=64), **patch))
            self.assertNotEqual(code, 0)
            self.assertEqual(events[-1]['value'], 'request')
            self.assertEqual(list(Path(self.directory.name).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
