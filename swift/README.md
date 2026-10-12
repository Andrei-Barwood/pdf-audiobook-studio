# PDF Audiobook Studio — Swift (macOS)

Versión nativa de **PDF Audiobook Studio** para Mac. Misma idea que la app Python: PDF largo → audiolibro. La diferencia importante está en las voces.

## Por qué no usa las voces de macOS

Las voces «Premium» / Enhanced de Apple (AVSpeechSynthesizer) tienen una curva de entonación predefinida. Suenan correctas, pero planas: no cambian el carácter de la frase.

Esta app usa **voces neuronales en la nube**, las mismas que hacen que la versión Python suene más viva:

| Motor | Coste | Qué hace |
|---|---|---|
| **Edge Neural (Microsoft)** | Gratis, sin API key | Las mismas voces que Edge-TTS (`Álvaro`, `Elvira`, `Dalia`, `Andrew Multilingual`…). El modelo adapta pausas y tono a cada oración. |
| **Google AI Pro / Cloud TTS** | API key de Google (Google AI Studio / Cloud) | Las voces más bellas del mundo: **Journey** (`Princesa de cuento`, `Narrador legendario`), **Studio** (grabación acústica) y **Gemini** (`Kore`, `Aoede`, `Leda`…). |
| **Grok TTS (xAI)** | Créditos en [console.x.ai](https://console.x.ai) (15 USD / 1M caracteres). SuperGrok no cubre esto. | Voces de Grok (`Ara`, `Eve`, `Rex`…). Detecta español, normaliza números y abreviaturas. |
| **OpenAI TTS** | API key opcional | `gpt-4o-mini-tts` con instrucciones de narrador de audiolibro. Aún más expresivo: preguntas, diálogo y descriptivo se leen distinto. |

No hay motor `pyttsx3` / Siri / voces del sistema a propósito.

## Requisitos

- macOS 14 Sequoia o posterior
- Xcode 16+ (incluye Swift 5/6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Red (las voces neuronales son online)

## Cómo abrir y ejecutar

```bash
cd swift
./build.sh          # genera el .xcodeproj, compila y abre la app
```

O a mano:

```bash
cd swift
xcodegen generate
open PDFAudiobookStudio.xcodeproj
```

En Xcode: selecciona el scheme **PDFAudiobookStudio** y pulsa ⌘R.

## Uso

1. Arrastra un PDF (o ⌘O).
2. Elige rango de páginas, motor y voz.
3. Si el PDF trae índice, activa **Un archivo por capítulo**: la app crea una carpeta `Nombre_audiolibro/` con un audio por parte o capítulo (por ejemplo 40 PARTES → 40 archivos). El índice impreso del principio no se lee.
4. **Probar voz** reproduce una frase de muestra.
5. Elige carpeta de destino y **Iniciar conversión**.
6. Puedes pausar, reanudar o cancelar. El progreso vive en SQLite: si cierras la app, el proyecto reaparece en la barra lateral.

Los PDFs escaneados se leen con **Vision OCR** nativo (español + inglés), sin Tesseract.

Formatos de salida: **MP3** (concatenación directa del stream neural), **M4A** y **WAV**.

## Google / Grok / OpenAI (opcional)

Ajustes → pega la API key. Se guarda en el Llavero de macOS, no en disco.

- **Google AI Pro / Cloud TTS** (cuenta andrewvkaamo@gmail.com): Obtén tu API key gratuita con 1 clic en [Google AI Studio](https://aistudio.google.com/apikey) o habilita Cloud TTS en [Google Cloud Console](https://console.cloud.google.com/apis/library/texttospeech.googleapis.com).
- Grok: [console.x.ai](https://console.x.ai/team/default/api-keys) (`xai-…`)
- OpenAI: [platform.openai.com](https://platform.openai.com/api-keys) (`sk-…`)

## Datos locales

```
~/Library/Application Support/PDFAudiobookStudio/studio.db
~/Library/Application Support/PDFAudiobookStudio/temp_cache/
```

La app Python original sigue en la raíz del repo (`python main.py`). Las dos conviven; no comparten base de datos.
