"""Chapter detection for PDF documents.

Provides automatic chapter boundary detection using two strategies:
1. Structured TOC extraction via PyMuPDF (fitz) — preferred when available.
2. Regex-based heuristic detection of common chapter heading patterns
   in both English and Spanish.
"""

import json
import os
import re
from dataclasses import dataclass, field, asdict
from typing import Dict, Any, List, Optional

try:
    import fitz  # PyMuPDF
    PYMUPDF_AVAILABLE = True
except ImportError:
    PYMUPDF_AVAILABLE = False

from app.utils.logger import logger
from app.utils.errors import AudiobookStudioError


# ---------------------------------------------------------------------------
# Custom exceptions
# ---------------------------------------------------------------------------

class ChapterDetectionError(AudiobookStudioError):
    """Raised when chapter detection fails or produces invalid results."""
    pass


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Chapter:
    """Represents a single chapter (or major section) detected in a PDF.

    Attributes:
        title:      Human-readable chapter title.
        start_page: First page of the chapter (1-indexed, inclusive).
        end_page:   Last page of the chapter (1-indexed, inclusive).
                    May be ``None`` until boundaries are finalised.
    """
    title: str
    start_page: int
    end_page: Optional[int] = None

    def to_dict(self) -> Dict[str, Any]:
        """Serialise to a plain dictionary."""
        return asdict(self)

    @staticmethod
    def from_dict(data: Dict[str, Any]) -> "Chapter":
        """Deserialise from a dictionary."""
        return Chapter(
            title=data["title"],
            start_page=data["start_page"],
            end_page=data.get("end_page"),
        )


# ---------------------------------------------------------------------------
# Compiled regex patterns for heading detection
# ---------------------------------------------------------------------------

# Explicit "Chapter / Capítulo" patterns (with optional number and title)
_CHAPTER_KEYWORD_PATTERNS: List[re.Pattern] = [
    # "Capítulo 1", "CAPÍTULO 1: Título", "Capítulo I – Título"
    re.compile(
        r"^\s*cap[íi]tulo\s+(\d+|[IVXLCDM]+)"
        r"(\s*[:.\-–—]\s*(.+))?\s*$",
        re.IGNORECASE,
    ),
    # "Chapter 1", "CHAPTER 1: Title", "Chapter I – Title"
    re.compile(
        r"^\s*chapter\s+(\d+|[IVXLCDM]+)"
        r"(\s*[:.\-–—]\s*(.+))?\s*$",
        re.IGNORECASE,
    ),
    # "Part 1", "Parte I", "PART III - Title"
    re.compile(
        r"^\s*part[e]?\s+(\d+|[IVXLCDM]+)"
        r"(\s*[:.\-–—]\s*(.+))?\s*$",
        re.IGNORECASE,
    ),
]

# Major structural units in a TOC. Prefer these over dumping every level-1 bookmark
# (some books, like multi-part treatises, mark sections and subsections as level 1).
_MAJOR_HEADING = re.compile(
    r"^\s*(?:"
    r"parte\s+(?:\d+|[ivxlcdm]+)|"
    r"part\s+(?:\d+|[ivxlcdm]+)|"
    r"cap[íi]tulo\s+(?:\d+|[ivxlcdm]+)|"
    r"chapter\s+(?:\d+|[ivxlcdm]+)|"
    r"libro\s+(?:\d+|[ivxlcdm]+)|"
    r"book\s+(?:\d+|[ivxlcdm]+)|"
    r"secci[oó]n\s+(?:\d+|[ivxlcdm]+)|"
    r"volumen\s+(?:\d+|[ivxlcdm]+)|"
    r"volume\s+(?:\d+|[ivxlcdm]+)|"
    r"ap[eé]ndice(?:\s|$)|"
    r"appendix(?:\s|$)"
    r")",
    re.IGNORECASE,
)

_INDEX_TITLE = re.compile(
    r"^\s*(índice(?:\s+general)?|indice(?:\s+general)?|"
    r"tabla de contenidos|table of contents|contents|toc)\s*$",
    re.IGNORECASE,
)

# Numbered headings at line start: "1.", "2.", "10." (but not "1.5" — must end line or have title)
_NUMBERED_HEADING = re.compile(
    r"^\s*(\d{1,3})\.\s+(.{2,80})\s*$"
)

# Roman-numeral headings: "I.", "II.", "IV. Title text"
_ROMAN_HEADING = re.compile(
    r"^\s*([IVXLCDM]{1,6})\.\s+(.{2,80})\s*$"
)

# All-caps title lines (at least 4 word-characters, no lower-case)
_ALLCAPS_TITLE = re.compile(
    r"^\s*([A-ZÁÉÍÓÚÑÜ\s]{4,80})\s*$"
)


# ---------------------------------------------------------------------------
# Detector class
# ---------------------------------------------------------------------------

class ChapterDetector:
    """Detects chapter boundaries in a PDF document.

    Usage::

        detector = ChapterDetector(pdf_path="/path/to/book.pdf")
        chapters = detector.detect()
        detector.export_to_json("/path/to/chapters.json")
    """

    def __init__(
        self,
        pdf_path: Optional[str] = None,
        page_texts: Optional[List[Dict[str, Any]]] = None,
        total_pages: Optional[int] = None,
    ):
        """Initialise the detector.

        Args:
            pdf_path:    Path to the PDF file.  Used for TOC extraction via
                         PyMuPDF and as a fallback for ``total_pages``.
            page_texts:  List of dicts ``{"page_num": int (0-indexed), "text": str}``
                         representing the already-extracted text of each page.
                         Required for regex-based detection.
            total_pages: Total number of pages in the document.  If omitted it
                         is inferred from *pdf_path* or *page_texts*.
        """
        self.pdf_path = pdf_path
        self.page_texts = page_texts or []
        self._chapters: List[Chapter] = []

        # Resolve total page count
        if total_pages is not None:
            self.total_pages = total_pages
        elif self.page_texts:
            self.total_pages = max(p["page_num"] for p in self.page_texts) + 1
        elif self.pdf_path and PYMUPDF_AVAILABLE:
            try:
                doc = fitz.open(self.pdf_path)
                self.total_pages = len(doc)
                doc.close()
            except Exception as exc:
                logger.warning(f"Could not determine page count from PDF: {exc}")
                self.total_pages = 0
        else:
            self.total_pages = 0

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def detect(self) -> List[Chapter]:
        """Run chapter detection and return the resulting chapter list.

        Strategy:
        1. Attempt TOC-based detection via PyMuPDF, preferring PARTES/capítulos
           when the outline flattens every heading to the same level.
        2. If no TOC entries are found, fall back to regex heuristics.
        3. If neither yields results, treat the entire document as one chapter.
        """
        logger.info("Starting chapter detection …")

        # Strategy 1 — structured TOC
        chapters = self._detect_from_toc()
        if len(chapters) >= 2:
            logger.info(f"Detected {len(chapters)} chapter(s) from PDF Table of Contents.")
            self._chapters = chapters
            return self._chapters

        # Strategy 2 — regex heuristics
        if self.page_texts:
            chapters = self._detect_from_text()
            if len(chapters) >= 2:
                logger.info(f"Detected {len(chapters)} chapter(s) via text heuristics.")
                self._chapters = chapters
                return self._chapters

        # Fallback — single chapter spanning the whole document
        logger.warning("No chapters detected; treating entire document as a single chapter.")
        self._chapters = [
            Chapter(
                title="Full Document",
                start_page=1,
                end_page=self.total_pages or 1,
            )
        ]
        return self._chapters

    @property
    def chapters(self) -> List[Chapter]:
        """Return chapters previously detected (empty if ``detect()`` has not been called)."""
        return self._chapters

    def export_to_json(self, output_path: str) -> str:
        """Serialise the detected chapters to a JSON file.

        Args:
            output_path: Destination file path for the JSON output.

        Returns:
            The absolute path to the written file.

        Raises:
            ChapterDetectionError: If writing fails.
        """
        if not self._chapters:
            raise ChapterDetectionError(
                "No chapters to export. Call detect() first."
            )

        try:
            os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
            payload = {
                "source": os.path.basename(self.pdf_path) if self.pdf_path else "unknown",
                "total_pages": self.total_pages,
                "chapter_count": len(self._chapters),
                "chapters": [ch.to_dict() for ch in self._chapters],
            }
            with open(output_path, "w", encoding="utf-8") as fh:
                json.dump(payload, fh, ensure_ascii=False, indent=2)

            logger.info(f"Chapter data exported to {output_path}")
            return os.path.abspath(output_path)
        except OSError as exc:
            logger.error(f"Failed to write chapter JSON: {exc}")
            raise ChapterDetectionError(f"Could not write chapter JSON: {exc}")

    @staticmethod
    def clip_to_range(
        chapters: List[Chapter],
        start_page: int,
        end_page: int,
    ) -> List[Chapter]:
        """Keep chapters that overlap ``start_page…end_page`` (1-indexed, inclusive)."""
        clipped: List[Chapter] = []
        for chapter in chapters:
            last = chapter.end_page if chapter.end_page is not None else end_page
            start = max(chapter.start_page, start_page)
            end = min(last, end_page)
            if start <= end:
                clipped.append(Chapter(title=chapter.title, start_page=start, end_page=end))
        return clipped

    @staticmethod
    def sanitize_filename(title: str, index: int, total: int, ext: str) -> str:
        """Build a filesystem-safe ``01_Titulo.mp3`` name."""
        width = 3 if total >= 100 else 2
        safe = "".join(c if c.isalnum() or c in " _-" else "_" for c in (title or ""))
        safe = re.sub(r"[\s_]+", "_", safe).strip("._ ")
        if len(safe) > 72:
            safe = safe[:72].rstrip("._ ")
        if not safe:
            safe = f"capitulo_{index}"
        return f"{index:0{width}d}_{safe}.{ext.lstrip('.')}"

    @staticmethod
    def chapters_from_toc(toc: List[list], total_pages: int) -> List[Chapter]:
        """Turn a PyMuPDF-style TOC (``[level, title, page]``) into chapters.

        When the outline contains two or more PARTES / capítulos / chapters,
        those become the split points even if the PDF marked every subsection
        as the same bookmark level.
        """
        cleaned: List[tuple] = []
        for entry in toc or []:
            if not entry or len(entry) < 3:
                continue
            level, title, page = entry[0], (entry[1] or "").strip(), int(entry[2] or 1)
            if not title or _INDEX_TITLE.match(title):
                continue
            cleaned.append((level, title, max(1, page)))

        if not cleaned:
            return []

        majors = [item for item in cleaned if _MAJOR_HEADING.match(item[1])]
        if len(majors) >= 2:
            logger.info(
                f"TOC has {len(cleaned)} bookmarks; splitting on {len(majors)} "
                "major headings (PARTE / capítulo / chapter)."
            )
            selected = majors
        else:
            min_level = min(item[0] for item in cleaned)
            selected = [item for item in cleaned if item[0] == min_level]

        return ChapterDetector._entries_to_chapters(selected, total_pages)

    @staticmethod
    def _entries_to_chapters(entries: List[tuple], total_pages: int) -> List[Chapter]:
        """Convert ``(level, title, page)`` rows into chapters with end pages."""
        unique: List[tuple] = []
        for item in entries:
            if unique and unique[-1][1] == item[1] and unique[-1][2] == item[2]:
                continue
            unique.append(item)

        chapters: List[Chapter] = []
        for idx, (_level, title, page) in enumerate(unique):
            title = title.strip() if title else f"Capítulo {idx + 1}"
            if idx + 1 < len(unique):
                next_page = unique[idx + 1][2]
                end_page = next_page - 1 if next_page > page else page
            else:
                end_page = total_pages or page
            page = max(1, page)
            end_page = max(page, end_page)
            chapters.append(Chapter(title=title, start_page=page, end_page=end_page))
        return chapters

    # ------------------------------------------------------------------
    # Strategy 1 — TOC-based detection
    # ------------------------------------------------------------------

    def _detect_from_toc(self) -> List[Chapter]:
        """Extract chapters from the PDF's embedded Table of Contents."""
        if not self.pdf_path or not PYMUPDF_AVAILABLE:
            return []

        try:
            doc = fitz.open(self.pdf_path)
            toc: List[list] = doc.get_toc()
            if not self.total_pages:
                self.total_pages = len(doc)
            doc.close()
        except Exception as exc:
            logger.warning(f"TOC extraction failed: {exc}")
            return []

        if not toc:
            logger.debug("PDF has no embedded Table of Contents.")
            return []

        return self.chapters_from_toc(toc, self.total_pages)

    # ------------------------------------------------------------------
    # Strategy 2 — Regex-based heuristic detection
    # ------------------------------------------------------------------

    def _detect_from_text(self) -> List[Chapter]:
        """Scan page texts for lines that look like chapter headings."""
        raw_hits: List[Dict[str, Any]] = []

        for page_info in self.page_texts:
            page_num_0 = page_info["page_num"]  # 0-indexed
            page_num_1 = page_num_0 + 1          # 1-indexed for Chapter model
            text: str = page_info.get("text", page_info.get("raw_text", ""))

            if not text:
                continue

            # Only inspect the first few lines of each page — chapter titles
            # almost always appear near the top.
            lines = text.split("\n")
            header_lines = lines[: min(len(lines), 8)]

            for line in header_lines:
                match_result = self._match_heading(line)
                if match_result is not None:
                    raw_hits.append({
                        "title": match_result,
                        "page": page_num_1,
                    })
                    break  # one heading per page is enough

        if not raw_hits:
            return []

        # De-duplicate consecutive hits on the same page
        seen_pages: set = set()
        unique_hits: List[Dict[str, Any]] = []
        for hit in raw_hits:
            if hit["page"] not in seen_pages:
                unique_hits.append(hit)
                seen_pages.add(hit["page"])

        # Build Chapter objects with end-page boundaries
        chapters: List[Chapter] = []
        for idx, hit in enumerate(unique_hits):
            if idx + 1 < len(unique_hits):
                end_page = unique_hits[idx + 1]["page"] - 1
            else:
                end_page = self.total_pages or hit["page"]

            end_page = max(hit["page"], end_page)
            chapters.append(
                Chapter(title=hit["title"], start_page=hit["page"], end_page=end_page)
            )

        return chapters

    # ------------------------------------------------------------------
    # Heading matchers
    # ------------------------------------------------------------------

    @staticmethod
    def _match_heading(line: str) -> Optional[str]:
        """Test a single line against known heading patterns.

        Returns the normalised title string if matched, otherwise ``None``.
        """
        stripped = line.strip()
        if not stripped or len(stripped) < 3:
            return None

        # 1. Explicit keyword patterns (Chapter, Capítulo, Part/Parte)
        for pattern in _CHAPTER_KEYWORD_PATTERNS:
            m = pattern.match(stripped)
            if m:
                # Re-build a clean title from the match
                return stripped

        # 2. Numbered heading: "1. Introduction"
        m = _NUMBERED_HEADING.match(stripped)
        if m:
            number = m.group(1)
            title_text = m.group(2).strip()
            # Avoid matching list items or dates — require title portion to start with a letter
            if title_text and title_text[0].isalpha():
                return stripped

        # 3. Roman-numeral heading: "II. The Beginning"
        m = _ROMAN_HEADING.match(stripped)
        if m:
            title_text = m.group(2).strip()
            if title_text and title_text[0].isalpha():
                return stripped

        # 4. All-caps title (but not short lines that are likely page numbers or labels)
        m = _ALLCAPS_TITLE.match(stripped)
        if m:
            candidate = m.group(1).strip()
            # Must contain at least two words to qualify
            words = candidate.split()
            if len(words) >= 2 and not candidate.isdigit():
                # Reject if it contains only common header/footer words
                reject_words = {"PAGE", "PÁGINA", "PAGINA", "OF", "DE"}
                if not set(words).issubset(reject_words):
                    return candidate

        return None
