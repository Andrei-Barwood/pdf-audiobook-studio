import unittest
from app.core.text_cleaner import TextCleaner

class TestTextCleaner(unittest.TestCase):
    """Verifies that TextCleaner processes raw PDF extracts correctly into normalized outputs."""

    def test_basic_cleaning(self) -> None:
        raw = "  Este es un   ejemplo   con múltiples   espacios.  "
        expected = "Este es un ejemplo con múltiples espacios."
        self.assertEqual(TextCleaner.clean(raw), expected)

    def test_hyphen_fix(self) -> None:
        # Word cut across newline: "infor-\nmación" should yield "información"
        raw = "Estamos procesando infor-\nmación importante."
        expected = "Estamos procesando información importante."
        self.assertEqual(TextCleaner.clean(raw), expected)

    def test_header_footer_removal(self) -> None:
        raw = "Título del Libro\nPágina 1 de 200\nContenido de valor aquí.\n25 de 200\nFin de sección"
        cleaned = TextCleaner.clean(raw)
        
        # Ensure standard contents remain but page markers are gone
        self.assertIn("Contenido de valor aquí", cleaned)
        self.assertNotIn("Página 1 de 200", cleaned)
        self.assertNotIn("25 de 200", cleaned)

    def test_special_chars_replacements(self) -> None:
        raw = "Texto con guión — largo y comillas “elegantes”."
        expected = 'Texto con guión - largo y comillas "elegantes".'
        self.assertEqual(TextCleaner.clean(raw), expected)

if __name__ == "__main__":
    unittest.main()
