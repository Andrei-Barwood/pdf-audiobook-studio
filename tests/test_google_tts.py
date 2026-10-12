import unittest
from app.core.tts_engine import get_tts_engine, GoogleCloudTTSEngine

class TestGoogleTTSEngine(unittest.TestCase):
    def test_factory_returns_google_engine(self):
        engine = get_tts_engine("google")
        self.assertIsInstance(engine, GoogleCloudTTSEngine)

    def test_voice_catalog_contains_princess_and_gemini_voices(self):
        engine = GoogleCloudTTSEngine(api_key="test_key")
        voices = engine.get_available_voices()
        voice_ids = [v["id"] for v in voices]
        self.assertIn("es-ES-Journey-F", voice_ids)
        self.assertIn("es-ES-Studio-C", voice_ids)
        self.assertIn("gemini-kore", voice_ids)
        self.assertIn("gemini-aoede", voice_ids)
        self.assertIn("gemini-leda", voice_ids)

if __name__ == "__main__":
    unittest.main()
