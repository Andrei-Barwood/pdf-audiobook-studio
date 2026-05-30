import os
from typing import List, Optional, Dict, Any
from app.utils.logger import logger
from app.utils.file_utils import check_ffmpeg_installed
from app.utils.errors import AudioBuilderError

try:
    from pydub import AudioSegment
    from pydub.effects import normalize
    PYDUB_AVAILABLE = True
except ImportError:
    PYDUB_AVAILABLE = False


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

        # M4A/M4B require ffmpeg unconditionally
        if format_ext in ("m4a", "m4b") and not has_ffmpeg:
            raise AudioBuilderError(
                f"Cannot export to {format_ext.upper()} without ffmpeg installed. "
                "Please install ffmpeg (brew install ffmpeg) or choose MP3/WAV."
            )

        if PYDUB_AVAILABLE and has_ffmpeg:
            logger.info(f"Merging {len(valid_paths)} chunks using pydub (ffmpeg enabled)...")
            try:
                combined = AudioSegment.empty()
                silence = AudioSegment.silent(duration=silence_duration_ms)

                for i, path in enumerate(valid_paths):
                    segment = AudioSegment.from_file(path)
                    if i > 0:
                        combined += silence
                    combined += segment

                if normalize_volume:
                    logger.info("Normalizing output audiobook volume...")
                    combined = normalize(combined)

                # Build export tags for metadata embedding
                export_tags = AudioBuilder._build_tags(metadata) if metadata else None
                
                # M4B is actually M4A with a different extension; ffmpeg uses 'ipod' format
                if format_ext == "m4b":
                    combined.export(
                        output_path, format="ipod",
                        codec="aac",
                        tags=export_tags
                    )
                elif format_ext == "m4a":
                    combined.export(
                        output_path, format="ipod",
                        codec="aac",
                        tags=export_tags
                    )
                else:
                    combined.export(
                        output_path, format=format_ext,
                        tags=export_tags
                    )
                    
                logger.info(f"Audiobook successfully exported using pydub to: {output_path}")
            except Exception as e:
                logger.error(f"Pydub merging failed: {e}")
                raise AudioBuilderError(f"Pydub merging failed: {e}")
        else:
            # Fallback when ffmpeg is missing or pydub is unavailable
            if format_ext == "mp3":
                logger.info(f"Merging {len(valid_paths)} MP3 chunks using binary frame concatenation (no ffmpeg fallback)...")
                try:
                    AudioBuilder._binary_merge_mp3(valid_paths, output_path)
                    logger.info(f"Audiobook successfully exported using binary fallback to: {output_path}")
                except Exception as e:
                    logger.error(f"Binary MP3 merging failed: {e}")
                    raise AudioBuilderError(f"Binary merging failed: {e}")
            else:
                msg = (
                    f"Cannot merge {format_ext} files without ffmpeg. "
                    "Please install ffmpeg (brew install ffmpeg) or choose MP3 format."
                )
                logger.error(msg)
                raise AudioBuilderError(msg)

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
        
        for idx, (chapter_name, chunk_paths) in enumerate(chapter_audio_map.items(), start=1):
            # Sanitize chapter name for filename
            safe_name = "".join(c if c.isalnum() or c in " _-" else "_" for c in chapter_name).strip()
            if not safe_name:
                safe_name = f"capitulo_{idx:03d}"
            
            output_path = os.path.join(output_dir, f"{idx:03d}_{safe_name}.{format_ext}")
            
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
    def _binary_merge_mp3(paths: List[str], output_path: str) -> None:
        """Stitches MP3 files directly together at a binary level (supported by MP3 streaming format)."""
        try:
            with open(output_path, "wb") as outfile:
                for path in paths:
                    with open(path, "rb") as infile:
                        outfile.write(infile.read())
        except Exception as e:
            raise RuntimeError(f"Binary stream write error: {e}")
