class AudiobookStudioError(Exception):
    """Base exception class for all PDF Audiobook Studio errors."""
    pass

class PDFError(AudiobookStudioError):
    """Raised when an issue occurs reading or processing a PDF file."""
    pass

class PDFEncryptedError(PDFError):
    """Raised specifically when a PDF is encrypted or password-protected."""
    pass

class PDFExtractionError(PDFError):
    """Raised when text extraction fails or returns corrupt results."""
    pass

class TTSEngineError(AudiobookStudioError):
    """Raised when text-to-speech engines fail or are configured incorrectly."""
    pass

class AudioBuilderError(AudiobookStudioError):
    """Raised when concatenating, converting, or normalising audio fails."""
    pass

class DatabaseError(AudiobookStudioError):
    """Raised when operations on the SQLite database fail."""
    pass

class ProjectError(AudiobookStudioError):
    """Raised when loading or saving a project encounters configuration faults."""
    pass
