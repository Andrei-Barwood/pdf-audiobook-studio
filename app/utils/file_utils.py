import os
import shutil
import tempfile
import pathlib
from typing import Optional
from app.utils.logger import logger

def get_app_dir() -> pathlib.Path:
    """Gets the standard user configuration directory for the application."""
    path = pathlib.Path.home() / ".pdf_audiobook_studio"
    path.mkdir(parents=True, exist_ok=True)
    return path

def get_temp_dir() -> pathlib.Path:
    """Gets a stable temporary directory within the application folder to save audio chunks."""
    path = get_app_dir() / "temp_cache"
    path.mkdir(parents=True, exist_ok=True)
    return path

def check_ffmpeg_installed() -> bool:
    """Checks if ffmpeg is available on the system PATH."""
    has_ffmpeg = shutil.which("ffmpeg") is not None
    if not has_ffmpeg:
        logger.warning("ffmpeg was not detected on system PATH. Direct high-performance merging will be disabled, falling back to binary concatenation for MP3 files.")
    return has_ffmpeg

def clean_temp_dir() -> None:
    """Removes all files in the temporary cache directory."""
    temp_dir = get_temp_dir()
    try:
        shutil.rmtree(temp_dir)
        temp_dir.mkdir(parents=True, exist_ok=True)
        logger.info("Temporary audio cache cleared successfully.")
    except Exception as e:
        logger.error(f"Failed to clear temporary cache directory: {e}")

def get_file_size_mb(filepath: str) -> float:
    """Returns the size of a file in Megabytes."""
    try:
        return os.path.getsize(filepath) / (1024 * 1024)
    except Exception:
        return 0.0

def validate_write_permission(directory: str) -> bool:
    """Checks if the application has write permissions in the specified directory."""
    try:
        test_file = os.path.join(directory, ".write_test")
        with open(test_file, "w") as f:
            f.write("test")
        os.remove(test_file)
        return True
    except Exception as e:
        logger.error(f"No write permissions in directory {directory}: {e}")
        return False
