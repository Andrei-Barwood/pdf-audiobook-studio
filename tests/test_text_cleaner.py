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

    def test_special_chars_replacements_kept_when_symbols_allowed(self) -> None:
        raw = "Texto con guión — largo y comillas “elegantes”."
        expected = 'Texto con guión - largo y comillas "elegantes".'
        self.assertEqual(TextCleaner.clean(raw, omit_symbols=False), expected)

    def test_omit_symbols_strips_glyphs_elena_would_read(self) -> None:
        raw = "Capítulo *3* / sección #2: nota_al_pie y correo@demo.com."
        cleaned = TextCleaner.clean(raw)
        self.assertNotIn("*", cleaned)
        self.assertNotIn("#", cleaned)
        self.assertNotIn("/", cleaned)
        self.assertNotIn("_", cleaned)
        self.assertNotIn("@", cleaned)
        self.assertIn("Capítulo", cleaned)
        self.assertIn("sección", cleaned)
        self.assertIn("nota", cleaned)

    def test_omit_symbols_expands_percent_and_currency(self) -> None:
        self.assertEqual(
            TextCleaner.omit_spoken_symbols("Hay un 50% de descuento y cuesta $20."),
            "Hay un 50 por ciento de descuento y cuesta 20 dólares.",
        )

    def test_omit_symbols_keeps_sentence_punctuation_and_hyphens(self) -> None:
        raw = "¿Estado-nación? Sí, claro."
        cleaned = TextCleaner.clean(raw)
        self.assertEqual(cleaned, "¿Estado-nación? Sí, claro.")

    def test_omit_symbols_slash_between_digits_becomes_de(self) -> None:
        self.assertEqual(TextCleaner.omit_spoken_symbols("Capítulo 3/4."), "Capítulo 3 de 4.")

    def test_omit_symbols_parenthesis_become_pause(self) -> None:
        cleaned = TextCleaner.omit_spoken_symbols("El autor (1972) lo explica.")
        self.assertNotIn("(", cleaned)
        self.assertNotIn(")", cleaned)
        self.assertIn("1972", cleaned)

    def test_omit_symbols_false_preserves_asterisks(self) -> None:
        raw = "Nota * importante."
        self.assertIn("*", TextCleaner.clean(raw, omit_symbols=False))

if __name__ == "__main__":
    unittest.main()
