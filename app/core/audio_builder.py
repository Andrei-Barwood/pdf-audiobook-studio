import os
from typing import List, Optional, Dict, Any
from app.utils.logger import logger
from app.utils.file_utils import check_ffmpeg_installed
from app.utils.errors import AudioBuilderError

class AudioBuilder:
    """Concatenates, normalizes, and packages audio chunks into final output audiobook files.
    
    Supports MP3, WAV, and M4A formats. M4A/M4B require ffmpeg to be installed.
    Metadata embedding (title, author, album art) is available when ffmpeg is present.
    """

    SUPPORTED_FORMATS = {"mp3", "wav", "m4a", "m4b"}

    @staticmethod
    def merge_chunks(
        audio_paths: List[str],
        output_path: str,
        format_ext: str = "mp3",
        silence_duration_ms: int = 500,
        normalize_volume: bool = True,
        metadata: Optional[Dict[str, str]] = None
    ) -> None:
        """Joins several audio chunk files together, inserting small silences between blocks.
        
        Args:
            audio_paths: Ordered list of audio chunk file paths.
            output_path: Destination path for the merged audiobook file.
            format_ext: Output format (mp3, wav, m4a, m4b).
            silence_duration_ms: Milliseconds of silence between chunks.
            normalize_volume: Whether to normalize audio levels.
            metadata: Optional dict with keys like 'title', 'artist', 'album', 
                      'album_artist', 'genre', 'comment', 'date', 'track'.
        """
        if not audio_paths:
            raise AudioBuilderError("No audio chunks provided for merging.")

        # Ensure output directory exists
        out_dir = os.path.dirname(output_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)

        # Validate that all source files actually exist on disk
        valid_paths = []
        for path in audio_paths:
            if path and os.path.exists(path) and os.path.getsize(path) > 0:
                valid_paths.append(path)
            else:
                logger.warning(f"Audio chunk file missing or empty: {path}")

        if not valid_paths:
            raise AudioBuilderError("All audio chunk files were missing or empty. Cannot merge.")

        has_ffmpeg = check_ffmpeg_installed()
        format_ext = format_ext.lower().strip(".")

        if format_ext not in AudioBuilder.SUPPORTED_FORMATS:
            raise AudioBuilderError(f"Unsupported format '{format_ext}'. Supported: {AudioBuilder.SUPPORTED_FORMATS}")

        is_wav = False
        try:
            with open(valid_paths[0], "rb") as f_chk:
                is_wav = (f_chk.read(4) == b"RIFF")
        except Exception:
            pass

        staging_ext = "wav" if is_wav else "mp3"
        staging_path = output_path + f".staging.{staging_ext}"
        try:
            logger.info(f"Merging {len(valid_paths)} chunks by streaming copy ({staging_ext})...")
            if is_wav:
                AudioBuilder._binary_merge_wav(valid_paths, staging_path)
            else:
                AudioBuilder._binary_merge_mp3(valid_paths, staging_path)

            if os.path.getsize(staging_path) <= 0:
                raise AudioBuilderError("La unión de bloques produjo un archivo vacío.")

            if format_ext == staging_ext:
                os.replace(staging_path, output_path)
                logger.info(f"Audiobook exported by stream copy to: {output_path}")
                return

            if not has_ffmpeg:
                fallback_file = os.path.splitext(output_path)[0] + f".{staging_ext}"
                os.replace(staging_path, fallback_file)
                raise AudioBuilderError(
                    f"No hay ffmpeg para convertir a {format_ext.upper()}. "
                    f"El audio quedó guardado como {staging_ext.upper()} en {fallback_file}"
                )

            AudioBuilder._ffmpeg_transcode(staging_path, output_path, format_ext, metadata)
            logger.info(f"Audiobook transcoded with ffmpeg to: {output_path}")
        finally:
            if os.path.exists(staging_path):
                try:
                    os.remove(staging_path)
                except OSError:
                    pass

    @staticmethod
    def merge_chapter_files(
        chapter_audio_map: Dict[str, List[str]],
        output_dir: str,
        format_ext: str = "mp3",
        silence_duration_ms: int = 500,
        normalize_volume: bool = True,
        metadata: Optional[Dict[str, str]] = None
    ) -> List[str]:
        """Merges audio chunks into separate per-chapter output files.
        
        Args:
            chapter_audio_map: Dict mapping chapter name -> list of chunk audio paths.
            output_dir: Directory to save per-chapter files.
            format_ext: Output format.
            silence_duration_ms: Silence between chunks within a chapter.
            normalize_volume: Whether to normalize.
            metadata: Base metadata; 'track' will be auto-set per chapter.
            
        Returns:
            List of created chapter file paths.
        """
        os.makedirs(output_dir, exist_ok=True)
        created_files = []
        
        from app.core.chapter_detector import ChapterDetector

        total = len(chapter_audio_map)
        for idx, (chapter_name, chunk_paths) in enumerate(chapter_audio_map.items(), start=1):
            filename = ChapterDetector.sanitize_filename(
                chapter_name, index=idx, total=total, ext=format_ext
            )
            output_path = os.path.join(output_dir, filename)
            
            chapter_meta = dict(metadata) if metadata else {}
            chapter_meta["track"] = str(idx)
            chapter_meta["title"] = chapter_name
            
            try:
                AudioBuilder.merge_chunks(
                    audio_paths=chunk_paths,
                    output_path=output_path,
                    format_ext=format_ext,
                    silence_duration_ms=silence_duration_ms,
                    normalize_volume=normalize_volume,
                    metadata=chapter_meta
                )
                created_files.append(output_path)
                logger.info(f"Chapter '{chapter_name}' exported to: {output_path}")
            except Exception as e:
                logger.error(f"Failed to export chapter '{chapter_name}': {e}")

        return created_files

    @staticmethod
    def _build_tags(metadata: Dict[str, str]) -> Dict[str, str]:
        """Maps user-friendly metadata keys to ffmpeg-compatible tag names."""
        tag_map = {
            "title": "title",
            "author": "artist",
            "artist": "artist",
            "narrator": "album_artist",
            "album_artist": "album_artist",
            "album": "album",
            "genre": "genre",
            "year": "date",
            "date": "date",
            "description": "comment",
            "comment": "comment",
            "track": "track",
        }
        
        tags = {}
        for key, value in metadata.items():
            mapped = tag_map.get(key.lower())
            if mapped and value:
                tags[mapped] = value
                
        # Default genre to Audiobook if not set
        if "genre" not in tags:
            tags["genre"] = "Audiobook"
            
        return tags

    @staticmethod
    def _binary_merge_wav(paths: List[str], output_path: str) -> None:
        """Stitches standard PCM WAV files at a binary level without loading a whole chapter into RAM."""
        import struct
        bufsize = 256 * 1024
        try:
            with open(paths[0], "rb") as f_first:
                first_data = f_first.read(128)

            data_chunk_idx = first_data.find(b"data")
            header_len = 44 if data_chunk_idx == -1 else data_chunk_idx + 8

            total_pcm_bytes = 0
            with open(output_path, "wb") as outfile:
                with open(paths[0], "rb") as f_first:
                    outfile.write(f_first.read(header_len))

                for path in paths:
                    with open(path, "rb") as infile:
                        infile.seek(header_len)
                        while True:
                            chunk = infile.read(bufsize)
                            if not chunk:
                                break
                            outfile.write(chunk)
                            total_pcm_bytes += len(chunk)

                if data_chunk_idx != -1:
                    outfile.seek(data_chunk_idx + 4)
                    outfile.write(struct.pack("<I", total_pcm_bytes))
                outfile.seek(4)
                outfile.write(struct.pack("<I", total_pcm_bytes + header_len - 8))
        except Exception as e:
            raise RuntimeError(f"Binary WAV stream write error: {e}")

    @staticmethod
    def _binary_merge_mp3(paths: List[str], output_path: str) -> None:
        """Stitches MP3 files at a binary level without loading a whole chapter into RAM."""
        bufsize = 256 * 1024
        try:
            with open(output_path, "wb") as outfile:
                for path in paths:
                    with open(path, "rb") as infile:
                        while True:
                            chunk = infile.read(bufsize)
                            if not chunk:
                                break
                            outfile.write(chunk)
        except Exception as e:
            raise RuntimeError(f"Binary stream write error: {e}")

    @staticmethod
    def _ffmpeg_transcode(
        source_audio: str,
        output_path: str,
        format_ext: str,
        metadata: Optional[Dict[str, str]] = None,
    ) -> None:
        """Remux/transcode audio file using ffmpeg."""
        import subprocess
        import shutil

        ffmpeg_bin = shutil.which("ffmpeg")
        if not ffmpeg_bin:
            for cand in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]:
                if os.path.isfile(cand) and os.access(cand, os.X_OK):
                    ffmpeg_bin = cand
                    break
        ffmpeg_bin = ffmpeg_bin or "ffmpeg"

        cmd = [ffmpeg_bin, "-y", "-i", source_audio]
        tags = AudioBuilder._build_tags(metadata) if metadata else {}
        for key, value in tags.items():
            cmd.extend(["-metadata", f"{key}={value}"])
        if format_ext in ("m4a", "m4b"):
            cmd.extend(["-c:a", "aac", "-b:a", "64k", output_path])
        elif format_ext == "wav":
            cmd.extend(["-c:a", "pcm_s16le", output_path])
        elif format_ext == "mp3":
            cmd.extend(["-c:a", "libmp3lame", "-b:a", "192k", output_path])
        else:
            cmd.extend(["-c", "copy", output_path])
        try:
            subprocess.run(
                cmd,
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            raise AudioBuilderError(f"ffmpeg transcode failed: {e.stderr[-800:] if e.stderr else e}")
