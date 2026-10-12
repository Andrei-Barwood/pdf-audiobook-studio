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

def cached_audio_count() -> int:
    """Counts non-empty audio files in the temp cache."""
    temp_dir = get_temp_dir()
    n = 0
    try:
        for name in os.listdir(temp_dir):
            if not name.lower().endswith((".mp3", ".m4a", ".wav")):
                continue
            path = os.path.join(temp_dir, name)
            if os.path.isfile(path) and os.path.getsize(path) > 0:
                n += 1
    except OSError:
        return 0
    return n


def destination_note(path: str) -> Optional[str]:
    """Warn when the user picked a slow/fragile volume (HFS+, USB, network)."""
    if not path:
        return None
    try:
        import subprocess
        info = subprocess.run(
            ["diskutil", "info", path],
            capture_output=True,
            text=True,
            timeout=8,
        )
        text = (info.stdout or "") + (info.stderr or "")
        if "HFS" in text or "Mac OS Extended" in text:
            return (
                "El destino está en un volumen HFS+ (típico de discos USB viejos). "
                "Los capítulos se arman en el SSD interno. No borres la caché si la copia falla."
            )
        if "External" in text or "USB" in text or "Network" in text:
            return (
                "El destino está en un disco extraíble. "
                "Los capítulos se arman en el SSD interno y luego se copian."
            )
    except Exception:
        return None
    return None


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
