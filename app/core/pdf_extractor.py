import os
from typing import Dict, Any, List, Optional
try:
    import fitz  # PyMuPDF
    PYMUPDF_AVAILABLE = True
except ImportError:
    PYMUPDF_AVAILABLE = False

try:
    import pytesseract
    from PIL import Image
    import io
    OCR_AVAILABLE = True
except ImportError:
    OCR_AVAILABLE = False

from app.utils.logger import logger
from app.utils.errors import PDFError, PDFEncryptedError, PDFExtractionError

class PDFExtractor:
    """Handles text extraction and metadata retrieval from PDF files."""

    def __init__(self, pdf_path: str):
        if not os.path.exists(pdf_path):
            raise PDFError(f"PDF file not found at: {pdf_path}")
            
        self.pdf_path = pdf_path
        self._doc = None
        
        if not PYMUPDF_AVAILABLE:
            raise PDFError("PyMuPDF (fitz) is not installed. Please run pip install PyMuPDF.")
            
        self._open_document()

    def _open_document(self) -> None:
        """Opens the PDF document and validates encryption status."""
        try:
            self._doc = fitz.open(self.pdf_path)
            if self._doc.is_encrypted:
                raise PDFEncryptedError(f"The PDF file '{os.path.basename(self.pdf_path)}' is encrypted/password-protected.")
        except PDFEncryptedError:
            raise
        except Exception as e:
            logger.error(f"Failed to open PDF document: {e}")
            raise PDFError(f"Could not open PDF file: {e}")

    def get_metadata(self) -> Dict[str, Any]:
        """Extracts key file parameters and returns metadata dictionary."""
        if not self._doc:
            raise PDFError("Document is not open.")
            
        try:
            page_count = len(self._doc)
            file_size_mb = os.path.getsize(self.pdf_path) / (1024 * 1024)
            name = os.path.basename(self.pdf_path)
            
            # Simple scanned detection
            scanned = self.is_probably_scanned()
            
            meta = {
                "name": name,
                "path": self.pdf_path,
                "page_count": page_count,
                "file_size_mb": round(file_size_mb, 2),
                "is_scanned": scanned,
                "author": self._doc.metadata.get("author", "Desconocido"),
                "title": self._doc.metadata.get("title", "Sin título"),
                "subject": self._doc.metadata.get("subject", ""),
                "keywords": self._doc.metadata.get("keywords", "")
            }
            logger.info(f"PDF Metadata extracted: {meta['name']} ({meta['page_count']} páginas, {meta['file_size_mb']} MB, Scanned={scanned})")
            return meta
        except Exception as e:
            logger.error(f"Failed to extract metadata: {e}")
            raise PDFExtractionError(f"Error reading PDF metadata: {e}")

    def extract_page_text(self, page_num: int) -> str:
        """Extracts raw text from a specific page (0-indexed)."""
        if not self._doc:
            raise PDFError("Document is not open.")
            
        if page_num < 0 or page_num >= len(self._doc):
            raise PDFError(f"Page number {page_num} is out of bounds (0 to {len(self._doc)-1}).")
            
        try:
            page = self._doc[page_num]
            text = page.get_text("text")
            return text or ""
        except Exception as e:
            logger.error(f"Failed to extract text from page {page_num}: {e}")
            raise PDFExtractionError(f"Error extracting text from page {page_num}: {e}")

    def is_probably_scanned(self, sample_limit: int = 10) -> bool:
        """Determines if the PDF is scanned by looking for selectability in a few pages."""
        if not self._doc:
            return False
            
        total_pages = len(self._doc)
        pages_to_check = min(total_pages, sample_limit)
        
        selectable_chars = 0
        for i in range(pages_to_check):
            try:
                text = self.extract_page_text(i)
                selectable_chars += len(text.strip())
            except Exception:
                continue
                
        # If there are almost no selectable characters in the sampled pages, it is probably scanned
        avg_chars = selectable_chars / pages_to_check if pages_to_check > 0 else 0
        logger.debug(f"Selectable characters average in sample pages: {avg_chars}")
        return avg_chars < 50

    def extract_page_ocr(self, page_num: int) -> str:
        """Performs OCR on a page using pytesseract if available."""
        if not self._doc:
            raise PDFError("Document is not open.")
            
        if not OCR_AVAILABLE:
            raise PDFError("OCR is not available because 'pytesseract' or 'PIL' is missing. Please install dependencies and Tesseract OCR engine.")
            
        try:
            page = self._doc[page_num]
            # Render page to high-res image (pixmap)
            pix = page.get_pixmap(dpi=150)
            img_data = pix.tobytes("png")
            
            # Load into PIL
            image = Image.open(io.BytesIO(img_data))
            
            # Run Tesseract OCR in Spanish and English
            text = pytesseract.image_to_string(image, lang="spa+eng")
            return text or ""
        except Exception as e:
            logger.error(f"OCR failed for page {page_num}: {e}")
            raise PDFExtractionError(f"OCR conversion failed for page {page_num}: {e}")

    def close(self) -> None:
        """Closes the opened document handle."""
        if self._doc:
            self._doc.close()
            self._doc = None
            
    def __del__(self):
        self.close()
