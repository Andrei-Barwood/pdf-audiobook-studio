import unittest
from pathlib import Path

from app.core.chapter_detector import Chapter, ChapterDetector


COMPENDIO = Path(
    "/Users/andreibarwood/Documents/Mega Doll/Compendio_Tecnicas_Composicion.pdf"
)


class TestChapterDetector(unittest.TestCase):
    def test_prefers_partes_over_flat_level1_bookmarks(self) -> None:
        toc = [
            [1, "Índice general", 2],
            [1, "PARTE 0 — Cómo usar este compendio", 49],
            [1, "0.1 Qué es y qué no es este libro", 49],
            [2, "0.1.1 Diez funciones simultáneas", 49],
            [1, "PARTE I — Fundamentos del material musical", 58],
            [1, "I.1 Altura: el material antes del estilo", 58],
            [1, "PARTE II — Escalas, modos y colecciones", 97],
        ]
        chapters = ChapterDetector.chapters_from_toc(toc, total_pages=135)
        self.assertEqual(len(chapters), 3)
        self.assertEqual(chapters[0].title, "PARTE 0 — Cómo usar este compendio")
        self.assertEqual(chapters[0].start_page, 49)
        self.assertEqual(chapters[0].end_page, 57)
        self.assertEqual(chapters[1].start_page, 58)
        self.assertEqual(chapters[1].end_page, 96)
        self.assertEqual(chapters[2].start_page, 97)
        self.assertEqual(chapters[2].end_page, 135)

    def test_numbered_chapters_when_no_partes(self) -> None:
        toc = [
            [1, "Chapter 1: Beginnings", 1],
            [2, "1.1 A subsection", 3],
            [1, "Chapter 2: The middle", 10],
            [1, "Chapter 3: End", 20],
        ]
        chapters = ChapterDetector.chapters_from_toc(toc, total_pages=30)
        self.assertEqual([c.title for c in chapters], [
            "Chapter 1: Beginnings",
            "Chapter 2: The middle",
            "Chapter 3: End",
        ])
        self.assertEqual(chapters[0].end_page, 9)
        self.assertEqual(chapters[2].end_page, 30)

    def test_falls_back_to_shallowest_outline_level(self) -> None:
        toc = [
            [1, "Introduction", 1],
            [2, "Details", 2],
            [1, "Body", 5],
            [1, "Coda", 12],
        ]
        chapters = ChapterDetector.chapters_from_toc(toc, total_pages=15)
        self.assertEqual([c.title for c in chapters], ["Introduction", "Body", "Coda"])
        self.assertEqual(chapters[0].end_page, 4)

    def test_clip_to_range_keeps_overlapping_chapters(self) -> None:
        chapters = [
            Chapter("A", 1, 10),
            Chapter("B", 11, 20),
            Chapter("C", 21, 30),
        ]
        clipped = ChapterDetector.clip_to_range(chapters, 8, 22)
        self.assertEqual([c.title for c in clipped], ["A", "B", "C"])
        self.assertEqual(clipped[0].start_page, 8)
        self.assertEqual(clipped[0].end_page, 10)
        self.assertEqual(clipped[2].start_page, 21)
        self.assertEqual(clipped[2].end_page, 22)

    def test_clip_drops_chapters_outside_range(self) -> None:
        chapters = [
            Chapter("A", 1, 10),
            Chapter("B", 11, 20),
        ]
        self.assertEqual(ChapterDetector.clip_to_range(chapters, 12, 15)[0].title, "B")
        self.assertEqual(ChapterDetector.clip_to_range(chapters, 40, 50), [])

    def test_sanitize_filename_keeps_spanish_and_pads_index(self) -> None:
        name = ChapterDetector.sanitize_filename(
            "PARTE I — Fundamentos del material musical",
            index=2,
            total=40,
            ext="mp3",
        )
        self.assertTrue(name.startswith("02_"))
        self.assertTrue(name.endswith(".mp3"))
        self.assertIn("PARTE", name)
        self.assertNotIn("/", name)
        self.assertNotIn("—", name)

    def test_heuristic_headings_from_page_text(self) -> None:
        pages = [
            {"page_num": 0, "text": "Prólogo\nTexto inicial."},
            {"page_num": 4, "text": "Capítulo 1: El motivo\nHabía una vez."},
            {"page_num": 9, "text": "Capítulo 2: El desarrollo\nMás texto."},
        ]
        detector = ChapterDetector(page_texts=pages, total_pages=12)
        chapters = detector.detect()
        self.assertGreaterEqual(len(chapters), 2)
        self.assertTrue(any("Capítulo 1" in c.title for c in chapters))
        self.assertEqual(chapters[-1].end_page, 12)

    @unittest.skipUnless(COMPENDIO.exists(), "compendio PDF not present")
    def test_compendio_splits_into_forty_partes(self) -> None:
        detector = ChapterDetector(pdf_path=str(COMPENDIO))
        chapters = detector.detect()
        self.assertEqual(len(chapters), 40)
        self.assertTrue(chapters[0].title.startswith("PARTE 0"))
        self.assertEqual(chapters[0].start_page, 49)
        self.assertTrue(chapters[1].title.startswith("PARTE I"))
        self.assertEqual(chapters[0].end_page, chapters[1].start_page - 1)
        self.assertTrue(chapters[-1].title.startswith("PARTE XXXIX"))
        self.assertEqual(chapters[-1].end_page, detector.total_pages)


if __name__ == "__main__":
    unittest.main()
