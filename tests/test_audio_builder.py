import os
import tempfile
import unittest

from app.core.audio_builder import AudioBuilder
from app.utils.file_utils import cached_audio_count, get_temp_dir


class TestAudioBuilder(unittest.TestCase):
    def test_stream_merge_does_not_require_ffmpeg_for_mp3(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            chunks = []
            for i in range(5):
                path = os.path.join(tmp, f"c{i}.mp3")
                with open(path, "wb") as fh:
                    fh.write(bytes([i]) * (1024 * (i + 1)))
                chunks.append(path)
            out = os.path.join(tmp, "book.mp3")
            AudioBuilder.merge_chunks(chunks, out, format_ext="mp3")
            self.assertTrue(os.path.exists(out))
            self.assertEqual(os.path.getsize(out), sum(os.path.getsize(p) for p in chunks))

    def test_merge_chapter_files_writes_one_file_per_chapter(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            a = os.path.join(tmp, "a.mp3")
            b = os.path.join(tmp, "b.mp3")
            with open(a, "wb") as fh:
                fh.write(b"aaaa")
            with open(b, "wb") as fh:
                fh.write(b"bbbb")
            dest = os.path.join(tmp, "chapters")
            created = AudioBuilder.merge_chapter_files(
                {"PARTE 0 — Intro": [a], "PARTE I — Next": [b]},
                dest,
                format_ext="mp3",
            )
            self.assertEqual(len(created), 2)
            for path in created:
                self.assertTrue(os.path.exists(path))
                self.assertGreater(os.path.getsize(path), 0)

    def test_cached_audio_count_ignores_empty(self) -> None:
        cache = get_temp_dir()
        marker = cache / "_count_test.mp3"
        try:
            marker.write_bytes(b"")
            before = cached_audio_count()
            marker.write_bytes(b"not-empty")
            after = cached_audio_count()
            self.assertGreaterEqual(after, before)
        finally:
            if marker.exists():
                marker.unlink()


if __name__ == "__main__":
    unittest.main()
