import os
import asyncio
from abc import ABC, abstractmethod
from typing import Dict, Any, List, Optional
from app.utils.logger import logger
from app.utils.errors import TTSEngineError

# Try to import optional packages
try:
    import pyttsx3
    PYTTSX3_AVAILABLE = True
except ImportError:
    PYTTSX3_AVAILABLE = False

try:
    import edge_tts
    import edge_tts.constants
    import edge_tts.communicate
    edge_tts.constants.WSS_URL = (
        "wss://api.msedgeservices.com/tts/cognitiveservices/websocket/v1"
        f"?Ocp-Apim-Subscription-Key={edge_tts.constants.TRUSTED_CLIENT_TOKEN}"
    )
    edge_tts.communicate.WSS_URL = edge_tts.constants.WSS_URL
    EDGE_TTS_AVAILABLE = True
except ImportError:
    EDGE_TTS_AVAILABLE = False

try:
    from gtts import gTTS
    GTTS_AVAILABLE = True
except ImportError:
    GTTS_AVAILABLE = False


class BaseTTSEngine(ABC):
    """Abstract base class defining the Text-to-Speech Engine interface."""

    @abstractmethod
    def synthesize(self, text: str, output_path: str, voice_id: str, rate: float, volume: float = 1.0) -> None:
        """Synthesizes text and saves the resulting audio to output_path."""
        pass

    @abstractmethod
    def get_available_voices(self) -> List[Dict[str, str]]:
        """Returns a list of dictionaries containing 'id' and 'name' of available voices."""
        pass


class EdgeTTSEngine(BaseTTSEngine):
    """TTS engine using Microsoft Edge online high-quality neural voices."""

    def synthesize(self, text: str, output_path: str, voice_id: str, rate: float, volume: float = 1.0) -> None:
        if not EDGE_TTS_AVAILABLE:
            raise TTSEngineError("edge-tts library is not installed.")
            
        try:
            # edge-tts speed rate format is like '+10%' or '-5%' or '+0%'
            # Rate param is expected as a multiplier (e.g. 1.0 = normal, 1.2 = 20% faster)
            speed_percent = int((rate - 1.0) * 100)
            speed_str = f"{'+' if speed_percent >= 0 else ''}{speed_percent}%"
            
            # Volume formatting (e.g., '+0%' or '-10%')
            volume_percent = int((volume - 1.0) * 100)
            volume_str = f"{'+' if volume_percent >= 0 else ''}{volume_percent}%"

            async def _run():
                communicate = edge_tts.Communicate(text, voice_id, rate=speed_str, volume=volume_str)
                await communicate.save(output_path)

            # Use a dedicated event loop to avoid conflicts when called from QThread
            # asyncio.run() fails if there's already a running loop in the thread
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                loop = None
                
            if loop and loop.is_running():
                # We're inside an existing event loop — create a new one in this thread
                new_loop = asyncio.new_event_loop()
                try:
                    new_loop.run_until_complete(_run())
                finally:
                    new_loop.close()
            else:
                asyncio.run(_run())
                
            logger.info(f"EdgeTTS synthesized chunk successfully. Output: {output_path}")
        except Exception as e:
            logger.error(f"EdgeTTS synthesis failed: {e}")
            raise TTSEngineError(f"EdgeTTS failed to synthesize: {e}")

    def get_available_voices(self) -> List[Dict[str, str]]:
        # Static list of premium Spanish and English neural voices for high reliability
        return [
            {"id": "es-ES-AlvaroNeural", "name": "Álvaro (Neural) - España 🇪🇸"},
            {"id": "es-ES-ElviraNeural", "name": "Elvira (Neural) - España 🇪🇸"},
            {"id": "es-MX-JorgeNeural", "name": "Jorge (Neural) - México 🇲🇽"},
            {"id": "es-MX-DaliaNeural", "name": "Dalia (Neural) - México 🇲🇽"},
            {"id": "es-AR-ElenaNeural", "name": "Elena (Neural) - Argentina 🇦🇷"},
            {"id": "es-AR-TomasNeural", "name": "Tomás (Neural) - Argentina 🇦🇷"},
            {"id": "en-US-GuyNeural", "name": "Guy (Neural) - USA 🇺🇸"},
            {"id": "en-US-AriaNeural", "name": "Aria (Neural) - USA 🇺🇸"},
            {"id": "en-GB-SoniaNeural", "name": "Sonia (Neural) - UK 🇬🇧"},
            {"id": "en-GB-RyanNeural", "name": "Ryan (Neural) - UK 🇬🇧"},
        ]


class PyTTSX3Engine(BaseTTSEngine):
    """TTS engine running locally offline using native operating system speech services."""

    def synthesize(self, text: str, output_path: str, voice_id: str, rate: float, volume: float = 1.0) -> None:
        if not PYTTSX3_AVAILABLE:
            raise TTSEngineError("pyttsx3 library is not installed.")
            
        # Run init on current thread safely
        engine = None
        try:
            engine = pyttsx3.init()
            
            # Configure native rate (standard pyttsx3 rate is ~200. Speed scale rate*200)
            base_rate = engine.getProperty("rate") or 200
            engine.setProperty("rate", int(base_rate * rate))
            
            # Configure volume (0.0 to 1.0)
            engine.setProperty("volume", volume)
            
            if voice_id:
                engine.setProperty("voice", voice_id)
                
            engine.save_to_file(text, output_path)
            engine.runAndWait()
            
            # Double check that the file was actually written to disk
            if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
                raise TTSEngineError("pyttsx3 finished, but audio file was not written successfully.")
                
            logger.info(f"PyTTSX3 offline synthesized successfully. Output: {output_path}")
        except Exception as e:
            logger.error(f"pyttsx3 synthesis failed: {e}")
            raise TTSEngineError(f"Local offline engine failed: {e}")
        finally:
            if engine:
                try:
                    del engine
                except Exception:
                    pass

    def get_available_voices(self) -> List[Dict[str, str]]:
        if not PYTTSX3_AVAILABLE:
            return [{"id": "local", "name": "Local Default (Offline)"}]
            
        try:
            engine = pyttsx3.init()
            voices = engine.getProperty("voices")
            result = []
            
            for v in voices:
                # Localize displays
                lang = v.languages[0] if v.languages else "desconocido"
                result.append({
                    "id": v.id,
                    "name": f"{v.name} ({lang})"
                })
            
            # If no voices returned, add fallback
            if not result:
                result.append({"id": "", "name": "Local System Voice (Default)"})
                
            return result
        except Exception as e:
            logger.warning(f"Failed to query system offline voices: {e}")
            return [{"id": "", "name": "Local System Voice (Default)"}]


class GTTSEngine(BaseTTSEngine):
    """TTS engine using standard Google Translate online synthesis (gTTS)."""

    def synthesize(self, text: str, output_path: str, voice_id: str, rate: float, volume: float = 1.0) -> None:
        if not GTTS_AVAILABLE:
            raise TTSEngineError("gTTS library is not installed.")
            
        try:
            # voice_id can specify language accent (e.g., 'es' or 'en')
            lang = voice_id.split("-")[0] if "-" in voice_id else voice_id
            if not lang:
                lang = "es"
                
            tts = gTTS(text=text, lang=lang, slow=(rate < 0.95))
            tts.save(output_path)
            logger.info(f"gTTS synthesized successfully. Output: {output_path}")
        except Exception as e:
            logger.error(f"gTTS synthesis failed: {e}")
            raise TTSEngineError(f"Google online engine failed: {e}")

    def get_available_voices(self) -> List[Dict[str, str]]:
        return [
            {"id": "es", "name": "Español Estándar (Online) 🇪🇸"},
            {"id": "en", "name": "English Standard (Online) 🇺🇸"},
            {"id": "fr", "name": "Français (Online) 🇫🇷"},
            {"id": "pt", "name": "Português (Online) 🇵🇹"},
        ]


class GoogleCloudTTSEngine(BaseTTSEngine):
    """Google Cloud & Gemini AI Text-to-Speech engine supporting Journey, Studio, Neural2, and Gemini voices."""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")

    def synthesize(self, text: str, output_path: str, voice_id: str, rate: float, volume: float = 1.0) -> None:
        key = self.api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        if not key:
            raise TTSEngineError("Se requiere una API Key de Google (configurada en variable de entorno GOOGLE_API_KEY o en la app).")

        import requests
        import base64

        if voice_id.startswith("gemini-"):
            gemini_voice = voice_id.replace("gemini-", "").capitalize()
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key={key}"
            payload = {
                "contents": [{
                    "parts": [{
                        "text": f"Narrate the following text aloud with high expressiveness. Do not add introductions or comments, read only the exact words provided:\n\n{text}"
                    }]
                }],
                "generationConfig": {
                    "responseModalities": ["AUDIO"],
                    "speechConfig": {
                        "voiceConfig": {
                            "prebuiltVoiceConfig": {
                                "voiceName": gemini_voice
                            }
                        }
                    }
                }
            }
            resp = requests.post(url, json=payload, timeout=120)
            if resp.status_code != 200:
                raise TTSEngineError(f"Google Gemini TTS ({resp.status_code}): {resp.text}")
            data = resp.json()
            try:
                audio_b64 = data["candidates"][0]["content"]["parts"][0]["inlineData"]["data"]
                audio_bytes = base64.b64decode(audio_b64)
                with open(output_path, "wb") as f:
                    f.write(audio_bytes)
            except Exception as e:
                raise TTSEngineError(f"Error procesando audio de Gemini: {e}")
        else:
            url = f"https://texttospeech.googleapis.com/v1/text:synthesize?key={key}"
            lang = "-".join(voice_id.split("-")[:2]) if "-" in voice_id else "es-ES"
            speed = min(max(rate, 0.25), 4.0)
            payload = {
                "input": {"text": text},
                "voice": {"languageCode": lang, "name": voice_id},
                "audioConfig": {"audioEncoding": "MP3", "speakingRate": speed}
            }
            resp = requests.post(url, json=payload, timeout=120)
            if resp.status_code != 200:
                raise TTSEngineError(f"Google Cloud TTS ({resp.status_code}): {resp.text}")
            data = resp.json()
            audio_b64 = data.get("audioContent")
            if not audio_b64:
                raise TTSEngineError("Google Cloud TTS no devolvió audio.")
            with open(output_path, "wb") as f:
                f.write(base64.b64decode(audio_b64))

        logger.info(f"Google TTS synthesized successfully. Output: {output_path}")

    def get_available_voices(self) -> List[Dict[str, str]]:
        return [
            {"id": "es-ES-Journey-F", "name": "Journey · Princesa de Cuento 👑 (España)"},
            {"id": "es-ES-Journey-D", "name": "Journey · Narrador Legendario (España)"},
            {"id": "es-ES-Studio-C", "name": "Studio · Dama Distinguida ✨ (España)"},
            {"id": "es-ES-Studio-F", "name": "Studio · Narradora Cálida (España)"},
            {"id": "es-ES-Neural2-A", "name": "Neural2 · Clara y Juvenil (España)"},
            {"id": "es-ES-Neural2-C", "name": "Neural2 · Dulce y Melódica 🌸 (España)"},
            {"id": "es-ES-Neural2-E", "name": "Neural2 · Princesa Serena (España)"},
            {"id": "es-US-Journey-F", "name": "Journey · Princesa Latina 👑 (Latinoamérica)"},
            {"id": "es-US-Journey-D", "name": "Journey · Narrador Latino (Latinoamérica)"},
            {"id": "es-US-Neural2-A", "name": "Neural2 · Sofía (Latinoamérica)"},
            {"id": "gemini-kore", "name": "Gemini · Kore (Princesa Dulce) 🌸"},
            {"id": "gemini-aoede", "name": "Gemini · Aoede (Musa Artística) 🎶"},
            {"id": "gemini-leda", "name": "Gemini · Leda (Regia y Elegante) 👑"},
            {"id": "gemini-callirrhoe", "name": "Gemini · Callirrhoe (Cristalina) 💧"},
            {"id": "gemini-puck", "name": "Gemini · Puck (Ágil y Alegre)"},
            {"id": "gemini-fenrir", "name": "Gemini · Fenrir (Potente y Narrativa)"},
            {"id": "en-US-Journey-F", "name": "Journey · English Princess 👑"},
            {"id": "en-US-Studio-O", "name": "Studio · English Professional"},
        ]


def get_tts_engine(engine_type: str) -> BaseTTSEngine:
    """Factory function returning the selected engine instance."""
    engine_type = engine_type.lower()
    if engine_type == "edge-tts" and EDGE_TTS_AVAILABLE:
        return EdgeTTSEngine()
    elif engine_type in ("google", "google-tts", "google-cloud"):
        return GoogleCloudTTSEngine()
    elif engine_type == "gtts" and GTTS_AVAILABLE:
        return GTTSEngine()
    elif PYTTSX3_AVAILABLE:
        logger.info(f"Requested {engine_type} but falling back to local offline pyttsx3 engine.")
        return PyTTSX3Engine()
    else:
        raise TTSEngineError("No functional TTS engines available. Install PySide6/pyttsx3/edge-tts correctly.")
