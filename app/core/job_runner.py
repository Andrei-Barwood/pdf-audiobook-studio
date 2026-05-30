import os
import time
from typing import Dict, Any, List, Optional
from PySide6.QtCore import QThread, Signal
from app.core.project_manager import ProjectManager
from app.core.tts_engine import get_tts_engine
from app.core.audio_builder import AudioBuilder
from app.utils.logger import logger
from app.utils.file_utils import get_temp_dir
from app.utils.errors import AudiobookStudioError

class ConversionWorker(QThread):
    """Asynchronous worker that processes PDF text chunks into audio, featuring robust Pause/Resume/Cancel."""
    
    progress_changed = Signal(int)             # Emits overall progress percentage (0-100)
    chunk_completed = Signal(int, str)         # Emits (chunk_index, audio_path)
    status_changed = Signal(str)               # Emits status message updates
    error_occurred = Signal(str, str)          # Emits (source_name, error_message)
    finished = Signal(bool, str)               # Emits (success_boolean, output_path_or_summary)

    def __init__(
        self,
        project_id: str,
        engine_type: str,
        voice_id: str,
        rate: float,
        format_ext: str,
        output_file: str,
        parent=None
    ):
        super().__init__(parent)
        self.project_id = project_id
        self.engine_type = engine_type
        self.voice_id = voice_id
        self.rate = rate
        self.format_ext = format_ext.lower().strip(".")
        self.output_file = output_file
        
        self._is_paused = False
        self._is_canceled = False
        self.retry_limit = 3

    def pause(self) -> None:
        """Pauses execution safely."""
        self._is_paused = True
        self.status_changed.emit("Conversión pausada.")
        logger.info(f"Worker for project {self.project_id} requested PAUSE.")

    def resume(self) -> None:
        """Resumes execution."""
        self._is_paused = False
        self.status_changed.emit("Reanudando conversión...")
        logger.info(f"Worker for project {self.project_id} requested RESUME.")

    def cancel(self) -> None:
        """Cancels execution."""
        self._is_canceled = True
        self._is_paused = False # Escape pause loop if stuck there
        self.status_changed.emit("Cancelando conversión...")
        logger.info(f"Worker for project {self.project_id} requested CANCEL.")

    def run(self) -> None:
        """Core worker loop execution."""
        logger.info(f"Starting conversion job for project {self.project_id}")
        self.status_changed.emit("Iniciando conversión...")
        
        try:
            # 1. Fetch chunks
            chunks = ProjectManager.get_chunks(self.project_id)
            if not chunks:
                self.error_occurred.emit("General", "No se encontraron bloques de texto para procesar.")
                self.finished.emit(False, "Sin bloques")
                return

            total_chunks = len(chunks)
            logger.info(f"Loaded {total_chunks} chunks to process for project {self.project_id}")
            
            # Initialize TTS Engine
            tts = get_tts_engine(self.engine_type)
            
            temp_cache_dir = get_temp_dir()
            
            # Track audio paths of successfully completed chunks in sequence
            completed_audio_paths: List[str] = [None] * total_chunks

            for idx, chunk in enumerate(chunks):
                chunk_index = chunk["chunk_index"]
                
                # Check for cancellation
                if self._is_canceled:
                    ProjectManager.update_project_status(self.project_id, "FAILED")
                    self.finished.emit(False, "Conversión cancelada por el usuario.")
                    return

                # Check and handle pause loop
                while self._is_paused:
                    if self._is_canceled:
                        ProjectManager.update_project_status(self.project_id, "FAILED")
                        self.finished.emit(False, "Conversión cancelada por el usuario.")
                        return
                    time.sleep(0.2)

                # Retrieve current chunk parameters
                clean_text = chunk["clean_text"]
                db_status = chunk["status"]
                cached_audio_path = chunk["audio_path"]
                page_num = chunk["page_number"]
                
                # Define temporary audio file path for this chunk
                temp_filename = f"{self.project_id}_chunk_{chunk_index}.{self.format_ext}"
                temp_audio_path = os.path.join(temp_cache_dir, temp_filename)

                # Check cache: if completed database record exists and file is physically valid, skip synthesis!
                if db_status == "COMPLETED" and cached_audio_path and os.path.exists(cached_audio_path) and os.path.getsize(cached_audio_path) > 0:
                    logger.info(f"Chunk {chunk_index} loaded from local cache: {cached_audio_path}")
                    completed_audio_paths[chunk_index] = cached_audio_path
                    
                    # Update progress and UI
                    progress = int(((chunk_index + 1) / total_chunks) * 100)
                    self.progress_changed.emit(progress)
                    self.chunk_completed.emit(chunk_index, cached_audio_path)
                    continue

                # Synthesize chunk with automatic retries
                self.status_changed.emit(f"Sintetizando bloque {chunk_index + 1} de {total_chunks} (Pág. {page_num})...")
                ProjectManager.update_chunk_status(self.project_id, chunk_index, "PROCESSING")
                
                success = False
                attempt = 0
                error_msg = ""

                while attempt < self.retry_limit and not self._is_canceled:
                    attempt += 1
                    try:
                        logger.info(f"Synthesizing chunk {chunk_index} (Attempt {attempt}/{self.retry_limit})...")
                        # Synchronous or awaitable wrapper call
                        tts.synthesize(
                            text=clean_text,
                            output_path=temp_audio_path,
                            voice_id=self.voice_id,
                            rate=self.rate
                        )
                        success = True
                        break
                    except Exception as e:
                        error_msg = str(e)
                        logger.warning(f"Synthesis attempt {attempt} failed for chunk {chunk_index}: {e}")
                        time.sleep(1.0) # Small pause before retry

                if self._is_canceled:
                    ProjectManager.update_project_status(self.project_id, "FAILED")
                    self.finished.emit(False, "Conversión cancelada por el usuario.")
                    return

                if success:
                    # Update chunk in SQLite as successfully processed
                    ProjectManager.update_chunk_status(
                        self.project_id,
                        chunk_index,
                        "COMPLETED",
                        audio_path=temp_audio_path
                    )
                    completed_audio_paths[chunk_index] = temp_audio_path
                    self.chunk_completed.emit(chunk_index, temp_audio_path)
                else:
                    # Log failure but continue processing other blocks to satisfy "not stopping the whole project"
                    ProjectManager.update_chunk_status(
                        self.project_id,
                        chunk_index,
                        "FAILED",
                        error_message=error_msg
                    )
                    self.error_occurred.emit(f"Bloque {chunk_index+1} (Pág. {page_num})", f"Error de síntesis: {error_msg}")
                    logger.error(f"Chunk {chunk_index} failed all {self.retry_limit} synthesis attempts.")

                # Calculate and emit total progress percentage
                progress = int(((chunk_index + 1) / total_chunks) * 100)
                self.progress_changed.emit(progress)

            # Filter out chunks that failed to generate audio
            final_audio_segments = [path for path in completed_audio_paths if path is not None]
            
            if not final_audio_segments:
                raise AudiobookStudioError("Todos los bloques de audio fallaron. No hay archivos que unir.")

            # 3. Assemble Audio
            self.status_changed.emit("Procesando y uniendo archivos finales...")
            logger.info("Starting audio concatenation of completed chunks...")
            
            AudioBuilder.merge_chunks(
                audio_paths=final_audio_segments,
                output_path=self.output_file,
                format_ext=self.format_ext
            )

            ProjectManager.update_project_status(self.project_id, "COMPLETED")
            
            failed_count = total_chunks - len(final_audio_segments)
            if failed_count > 0:
                summary = f"Audiolibro creado con éxito en {self.output_file} ({failed_count} bloques omitidos debido a fallos)."
            else:
                summary = f"¡Audiolibro creado con éxito en {self.output_file}!"
                
            self.finished.emit(True, summary)
            
        except Exception as e:
            logger.error(f"Fatal error in conversion thread: {e}")
            ProjectManager.update_project_status(self.project_id, "FAILED")
            self.error_occurred.emit("General", f"Error fatal de conversión: {e}")
            self.finished.emit(False, str(e))
