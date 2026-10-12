import re
from app.utils.logger import logger

class TextCleaner:
    """Cleans extracted PDF text to prepare it for natural-sounding speech synthesis."""

    # Sentence punctuation kept so TTS still pauses naturally. Everything else
    # in this set is stripped because voices like es-AR-ElenaNeural read the
    # glyph name aloud ("asterisco", "barra", "almohadilla", "guión bajo"…).
    _ALLOWED_PUNCT = set(".,;:?!¿¡…'")

    @staticmethod
    def clean(text: str, omit_symbols: bool = True) -> str:
        """Applies a sequence of cleaning heuristics to normalize and format raw text."""
        if not text:
            return ""

        # 1. Normalize line endings
        text = text.replace("\r\n", "\n").replace("\r", "\n")
        
        # 2. Fix hyphenated word cuts across line breaks (e.g., infor-\nmación -> información)
        # Handles Spanish (ñ, á, é, í, ó, ú, ü) and English letters
        hyphen_pattern = re.compile(r"(\w+)-\s*\n\s*([a-zñáéíóúüü\w]+)", re.IGNORECASE)
        text = hyphen_pattern.sub(r"\1\2", text)
        
        # 3. Clean typical headers/footers (e.g. Page 1, Página 1 de 200, header labels)
        text = TextCleaner.remove_headers_footers(text)
        
        # 4. Replace single newlines within paragraphs with spaces, keeping double newlines as paragraph breaks
        paragraphs = text.split("\n\n")
        cleaned_paragraphs = []
        
        for p in paragraphs:
            # Replace single newlines inside paragraph with a space
            p_clean = p.replace("\n", " ")
            # Collapse multiple spaces
            p_clean = re.sub(r"\s+", " ", p_clean).strip()
            if p_clean:
                cleaned_paragraphs.append(p_clean)
                
        # Reconstruct with double newlines
        cleaned_text = "\n\n".join(cleaned_paragraphs)
        
        # 5. Normalize quotation marks and dashes for better TTS pauses
        cleaned_text = cleaned_text.replace("—", " - ").replace("–", " - ")
        cleaned_text = re.sub(r'["“”«»]', '"', cleaned_text)
        cleaned_text = re.sub(r"['‘’]", "'", cleaned_text)
        
        # Remove repeated non-alphanumeric patterns (e.g., ...., ----, ____)
        cleaned_text = re.sub(r"\.{4,}", "...", cleaned_text)
        cleaned_text = re.sub(r"_{2,}", " ", cleaned_text)
        cleaned_text = re.sub(r"-{3,}", " - ", cleaned_text)
        cleaned_text = re.sub(r"\*{2,}", " ", cleaned_text)
        
        if omit_symbols:
            cleaned_text = TextCleaner.omit_spoken_symbols(cleaned_text)

        # Collapse multiple spaces that might have been introduced by punctuation normalization
        cleaned_text = re.sub(r" +", " ", cleaned_text)
        
        return cleaned_text.strip()

    @staticmethod
    def omit_spoken_symbols(text: str) -> str:
        """Strips glyphs that Spanish Edge voices (especially Elena) tend to pronounce.

        Meaningful units are expanded first (% → por ciento, $ → dólares) so the
        number still makes sense. Sentence punctuation is kept for natural pauses.
        """
        if not text:
            return ""

        text = re.sub(r"https?://\S+", " ", text)
        text = re.sub(r"www\.\S+", " ", text)
        text = re.sub(r"\b[\w.+-]+@[\w.-]+\.\w{2,}\b", " ", text)

        text = re.sub(r"(\d+(?:[.,]\d+)?)\s*%", r"\1 por ciento", text)
        text = re.sub(r"\$\s*(\d+(?:[.,]\d+)?)", r"\1 dólares", text)
        text = re.sub(r"(\d+(?:[.,]\d+)?)\s*\$", r"\1 dólares", text)
        text = re.sub(r"€\s*(\d+(?:[.,]\d+)?)", r"\1 euros", text)
        text = re.sub(r"(\d+(?:[.,]\d+)?)\s*€", r"\1 euros", text)
        text = re.sub(r"£\s*(\d+(?:[.,]\d+)?)", r"\1 libras", text)
        text = re.sub(r"(\d+(?:[.,]\d+)?)\s*£", r"\1 libras", text)
        text = re.sub(r"(\d+(?:[.,]\d+)?)\s*°[CFcf]?", r"\1 grados", text)

        text = text.replace("&", " y ")
        text = re.sub(r"\by/o\b", "y o", text, flags=re.IGNORECASE)

        # 3/4, 12/03/2020 → spoken "de" instead of "barra"
        while True:
            replaced = re.sub(r"(\d+)\s*/\s*(\d+)", r"\1 de \2", text)
            if replaced == text:
                break
            text = replaced

        text = re.sub(r"\[\d+\]", " ", text)
        text = re.sub(r"[¹²³⁴⁵⁶⁷⁸⁹⁰]+", " ", text)

        text = text.replace("(", ", ").replace(")", ", ")
        text = re.sub(r'["“”«»]', " ", text)

        allowed = TextCleaner._ALLOWED_PUNCT
        out: list[str] = []
        for i, ch in enumerate(text):
            if ch.isalnum() or ch.isspace():
                out.append(ch)
                continue
            if ch in allowed:
                out.append(ch)
                continue
            if ch == "-":
                prev = text[i - 1] if i > 0 else " "
                nxt = text[i + 1] if i + 1 < len(text) else " "
                if prev.isalnum() and nxt.isalnum():
                    out.append(ch)
                    continue
            out.append(" ")

        result = "".join(out)
        result = re.sub(r"\s+", " ", result)
        result = re.sub(r"\s+([.,;:?!¡¿])", r"\1", result)
        result = re.sub(r"([,;:]){2,}", r"\1", result)
        result = re.sub(r"^[,.\s]+", "", result)
        return result.strip()

    @staticmethod
    def remove_headers_footers(text: str) -> str:
        """Removes common running header and footer patterns like page counts."""
        lines = text.split("\n")
        cleaned_lines = []
        
        page_num_patterns = [
            re.compile(r"^\s*p[áa]g(ina)?\s*\d+\s*(de\s*\d+)?\s*$", re.IGNORECASE),
            re.compile(r"^\s*page\s*\d+\s*(of\s*\d+)?\s*$", re.IGNORECASE),
            re.compile(r"^\s*\d+\s*de\s*\d+\s*$", re.IGNORECASE),
            re.compile(r"^\s*\d+\s*of\s*\d+\s*$", re.IGNORECASE),
            re.compile(r"^\s*\d+\s*$") # Just a line containing a single number
        ]
        
        for line in lines:
            stripped = line.strip()
            # If line is empty, keep it
            if not stripped:
                cleaned_lines.append(line)
                continue
                
            # If matches any page pattern, discard line
            is_page_marker = False
            for pattern in page_num_patterns:
                if pattern.match(stripped):
                    is_page_marker = True
                    break
                    
            if not is_page_marker:
                cleaned_lines.append(line)
                
        return "\n".join(cleaned_lines)
