import os
import tempfile
import unittest
from app.data.database import db
from app.core.project_manager import ProjectManager

class TestProjectManager(unittest.TestCase):
    """Verifies SQLite storage capabilities for conversions state tracking."""

    @classmethod
    def setUpClass(cls) -> None:
        # Create a separate temporary database for unit tests to avoid polluting user space
        cls.test_db_dir = tempfile.mkdtemp()
        cls.test_db_path = os.path.join(cls.test_db_dir, "test_studio.db")
        
        # Point the global DB manager to the temporary DB path
        db.db_path = cls.test_db_path
        db.initialize_schema()

    @classmethod
    def tearDownClass(cls) -> None:
        # Remove temporary DB
        try:
            if os.path.exists(cls.test_db_path):
                os.remove(cls.test_db_path)
            os.rmdir(cls.test_db_dir)
        except Exception:
            pass

    def test_project_lifecycle(self) -> None:
        # 1. Create Project
        proj = ProjectManager.create_project(
            name="TestBook",
            pdf_path="/path/to/test.pdf",
            output_dir="/path/to/output",
            engine_type="edge-tts",
            voice_id="es-ES-AlvaroNeural",
            rate=1.0,
            format_ext="mp3"
        )
        
        self.assertIsNotNone(proj["id"])
        self.assertEqual(proj["name"], "TestBook")
        
        # 2. Add Chunks
        chunks = [
            {"chunk_index": 0, "page_number": 1, "original_text": "Original 1", "clean_text": "Clean 1"},
            {"chunk_index": 1, "page_number": 2, "original_text": "Original 2", "clean_text": "Clean 2"}
        ]
        ProjectManager.add_chunks(proj["id"], chunks)
        
        registered_chunks = ProjectManager.get_chunks(proj["id"])
        self.assertEqual(len(registered_chunks), 2)
        
        # 3. Verify Initial Progress
        progress = ProjectManager.get_project_progress(proj["id"])
        self.assertEqual(progress["total_chunks"], 2)
        self.assertEqual(progress["completed_chunks"], 0)
        self.assertEqual(progress["progress_percentage"], 0.0)
        
        # 4. Update Chunk status
        ProjectManager.update_chunk_status(proj["id"], 0, "COMPLETED", "/path/to/audio0.mp3")
        
        progress = ProjectManager.get_project_progress(proj["id"])
        self.assertEqual(progress["completed_chunks"], 1)
        self.assertEqual(progress["progress_percentage"], 50.0)
        
        # 5. Delete project
        ProjectManager.delete_project(proj["id"])
        
        loaded = ProjectManager.load_project(proj["id"])
        self.assertIsNone(loaded)

if __name__ == "__main__":
    unittest.main()
