import sqlite3
import os
import pathlib
from typing import Dict, Any, List, Optional
from app.utils.logger import logger
from app.utils.file_utils import get_app_dir
from app.utils.errors import DatabaseError

class DatabaseManager:
    """Manages connection, schema creation, and database transactions for the application."""
    
    def __init__(self, db_path: Optional[str] = None):
        if db_path is None:
            self.db_path = str(get_app_dir() / "studio.db")
        else:
            self.db_path = db_path
            
        self.initialize_schema()

    def get_connection(self) -> sqlite3.Connection:
        """Returns a connection with dictionary-like row formatting enabled."""
        try:
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to SQLite database at {self.db_path}: {e}")
            raise DatabaseError(f"Database connection error: {e}")

    def initialize_schema(self) -> None:
        """Creates database tables if they do not exist."""
        sql_projects = """
        CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            pdf_path TEXT NOT NULL,
            output_dir TEXT NOT NULL,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, COMPLETED, FAILED
            engine_type TEXT NOT NULL,
            voice_id TEXT NOT NULL,
            rate REAL NOT NULL,
            format_ext TEXT NOT NULL DEFAULT 'mp3'
        );
        """
        
        sql_chunks = """
        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            page_number INTEGER NOT NULL,
            original_text TEXT NOT NULL,
            clean_text TEXT NOT NULL,
            audio_path TEXT,
            status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING, PROCESSING, COMPLETED, FAILED
            error_message TEXT,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
            UNIQUE(project_id, chunk_index)
        );
        """
        
        sql_settings = """
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """

        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            cursor.execute(sql_projects)
            cursor.execute(sql_chunks)
            cursor.execute(sql_settings)
            conn.commit()
            logger.info("Database schema initialized successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize database tables: {e}")
            raise DatabaseError(f"Database schema initialization failed: {e}")
        finally:
            if conn:
                conn.close()

    def save_setting(self, key: str, value: str) -> None:
        """Saves a setting key-value pair."""
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            cursor.execute(
                "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                (key, value)
            )
            conn.commit()
        except Exception as e:
            logger.error(f"Failed to save setting {key}: {e}")
        finally:
            if conn:
                conn.close()

    def get_setting(self, key: str, default: Optional[str] = None) -> Optional[str]:
        """Gets a setting value by its key."""
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT value FROM settings WHERE key = ?", (key,))
            row = cursor.fetchone()
            return row["value"] if row else default
        except Exception as e:
            logger.error(f"Failed to fetch setting {key}: {e}")
            return default
        finally:
            if conn:
                conn.close()
                
# Global database manager instance
db = DatabaseManager()
