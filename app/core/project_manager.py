import uuid
import datetime
from typing import Dict, Any, List, Optional
from app.data.database import db
from app.utils.logger import logger
from app.utils.errors import ProjectError

class ProjectManager:
    """Handles logic for creating, loading, list-viewing, and updating audiobook conversion projects."""

    @staticmethod
    def create_project(
        name: str,
        pdf_path: str,
        output_dir: str,
        engine_type: str,
        voice_id: str,
        rate: float,
        format_ext: str = "mp3"
    ) -> Dict[str, Any]:
        """Creates a new project record and returns the project data dictionary."""
        project_id = str(uuid.uuid4())
        created_at = datetime.datetime.now().isoformat()
        
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO projects (id, name, pdf_path, output_dir, created_at, status, engine_type, voice_id, rate, format_ext)
                VALUES (?, ?, ?, ?, ?, 'ACTIVE', ?, ?, ?, ?)
                """,
                (project_id, name, pdf_path, output_dir, created_at, engine_type, voice_id, rate, format_ext)
            )
            conn.commit()
            logger.info(f"Project '{name}' successfully created in database. ID: {project_id}")
            
            return {
                "id": project_id,
                "name": name,
                "pdf_path": pdf_path,
                "output_dir": output_dir,
                "created_at": created_at,
                "status": "ACTIVE",
                "engine_type": engine_type,
                "voice_id": voice_id,
                "rate": rate,
                "format_ext": format_ext
            }
        except Exception as e:
            logger.error(f"Failed to create project record: {e}")
            raise ProjectError(f"Error creating project: {e}")
        finally:
            if conn:
                conn.close()

    @staticmethod
    def load_project(project_id: str) -> Optional[Dict[str, Any]]:
        """Loads a project dictionary from database by project_id."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM projects WHERE id = ?", (project_id,))
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None
        except Exception as e:
            logger.error(f"Failed to load project with ID {project_id}: {e}")
            raise ProjectError(f"Error loading project: {e}")
        finally:
            if conn:
                conn.close()

    @staticmethod
    def list_projects() -> List[Dict[str, Any]]:
        """Lists all projects ordered by creation date desc."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM projects ORDER BY created_at DESC")
            rows = cursor.fetchall()
            return [dict(r) for r in rows]
        except Exception as e:
            logger.error(f"Failed to retrieve projects list: {e}")
            return []
        finally:
            if conn:
                conn.close()

    @staticmethod
    def delete_project(project_id: str) -> None:
        """Deletes a project and its cascade-related chunks."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            # Cascade deletion is enforced by schema constraint. Turn on foreign keys:
            cursor.execute("PRAGMA foreign_keys = ON")
            cursor.execute("DELETE FROM projects WHERE id = ?", (project_id,))
            conn.commit()
            logger.info(f"Project with ID {project_id} deleted successfully.")
        except Exception as e:
            logger.error(f"Failed to delete project {project_id}: {e}")
            raise ProjectError(f"Error deleting project: {e}")
        finally:
            if conn:
                conn.close()

    @staticmethod
    def add_chunks(project_id: str, chunks: List[Dict[str, Any]]) -> None:
        """Registers a list of chunks inside the DB for tracking."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            
            # Prepare batch inputs
            params = [
                (
                    project_id,
                    c["chunk_index"],
                    c["page_number"],
                    c["original_text"],
                    c["clean_text"],
                    c.get("audio_path"),
                    c.get("status", "PENDING"),
                    c.get("error_message")
                )
                for c in chunks
            ]
            
            cursor.executemany(
                """
                INSERT OR IGNORE INTO chunks (project_id, chunk_index, page_number, original_text, clean_text, audio_path, status, error_message)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                params
            )
            conn.commit()
            logger.info(f"Registered {len(chunks)} text chunks for project {project_id}.")
        except Exception as e:
            logger.error(f"Failed to register chunks for project {project_id}: {e}")
            raise ProjectError(f"Error registering project chunks: {e}")
        finally:
            if conn:
                conn.close()

    @staticmethod
    def update_chunk_status(
        project_id: str,
        chunk_index: int,
        status: str,
        audio_path: Optional[str] = None,
        error_message: Optional[str] = None
    ) -> None:
        """Updates status, path, and potential errors of a single chunk."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            
            if audio_path is not None:
                cursor.execute(
                    """
                    UPDATE chunks 
                    SET status = ?, audio_path = ?, error_message = ?
                    WHERE project_id = ? AND chunk_index = ?
                    """,
                    (status, audio_path, error_message, project_id, chunk_index)
                )
            else:
                cursor.execute(
                    """
                    UPDATE chunks 
                    SET status = ?, error_message = ?
                    WHERE project_id = ? AND chunk_index = ?
                    """,
                    (status, error_message, project_id, chunk_index)
                )
            conn.commit()
        except Exception as e:
            logger.error(f"Failed to update chunk status for project {project_id}, index {chunk_index}: {e}")
        finally:
            if conn:
                conn.close()

    @staticmethod
    def get_project_progress(project_id: str) -> Dict[str, Any]:
        """Calculates conversion progress metrics for a project."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) as total FROM chunks WHERE project_id = ?", (project_id,))
            total = cursor.fetchone()["total"]
            
            cursor.execute("SELECT COUNT(*) as completed FROM chunks WHERE project_id = ? AND status = 'COMPLETED'", (project_id,))
            completed = cursor.fetchone()["completed"]
            
            cursor.execute("SELECT COUNT(*) as failed FROM chunks WHERE project_id = ? AND status = 'FAILED'", (project_id,))
            failed = cursor.fetchone()["failed"]
            
            progress = (completed / total * 100.0) if total > 0 else 0.0
            
            return {
                "total_chunks": total,
                "completed_chunks": completed,
                "failed_chunks": failed,
                "progress_percentage": progress
            }
        except Exception as e:
            logger.error(f"Failed to calculate progress for project {project_id}: {e}")
            return {
                "total_chunks": 0,
                "completed_chunks": 0,
                "failed_chunks": 0,
                "progress_percentage": 0.0
            }
        finally:
            if conn:
                conn.close()

    @staticmethod
    def get_chunks(project_id: str) -> List[Dict[str, Any]]:
        """Gets all chunks for a project sorted by chunk index."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM chunks WHERE project_id = ? ORDER BY chunk_index ASC", (project_id,))
            rows = cursor.fetchall()
            return [dict(r) for r in rows]
        except Exception as e:
            logger.error(f"Failed to get chunks for project {project_id}: {e}")
            return []
        finally:
            if conn:
                conn.close()
                
    @staticmethod
    def update_project_status(project_id: str, status: str) -> None:
        """Updates overall project status."""
        conn = None
        try:
            conn = db.get_connection()
            cursor = conn.cursor()
            cursor.execute("UPDATE projects SET status = ? WHERE id = ?", (status, project_id))
            conn.commit()
        except Exception as e:
            logger.error(f"Failed to update project status: {e}")
        finally:
            if conn:
                conn.close()
