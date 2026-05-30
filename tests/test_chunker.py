import unittest
from app.core.chunker import TextChunker

class TestTextChunker(unittest.TestCase):
    """Verifies that TextChunker divides text accurately along sentence boundaries within character limits."""

    def test_chunking_boundaries(self) -> None:
        pages = [
            {"page_num": 0, "raw_text": "Primera oración larga. Segunda oración corta."},
            {"page_num": 1, "raw_text": "Tercera oración aquí."}
        ]
        
        # Split with short limits to force splits
        chunks = TextChunker.chunk_pages(pages, max_chars=30)
        
        # Verify that we generated multiple chunks
        self.assertTrue(len(chunks) >= 2)
        
        # Verify trace page numbers are accurate (1-indexed)
        self.assertEqual(chunks[0]["page_number"], 1)
        self.assertTrue(len(chunks[0]["clean_text"]) <= 30)

    def test_empty_pages_ignored(self) -> None:
        pages = [
            {"page_num": 0, "raw_text": ""},
            {"page_num": 1, "raw_text": "     "},
            {"page_num": 2, "raw_text": "Contenido válido."}
        ]
        chunks = TextChunker.chunk_pages(pages, max_chars=100)
        self.assertEqual(len(chunks), 1)
        self.assertEqual(chunks[0]["page_number"], 3)
        self.assertEqual(chunks[0]["clean_text"], "Contenido válido.")

if __name__ == "__main__":
    unittest.main()
