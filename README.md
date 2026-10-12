# 🎧 PDF Audiobook Studio 🎙️

![macOS Sequoia](https://img.shields.io/badge/macOS-14%2B%20Sequoia-black?logo=apple) ![Swift 5.0](https://img.shields.io/badge/Swift-Native%20macOS-orange?logo=swift) ![Python 3.13](https://img.shields.io/badge/Python-3.13-blue?logo=python) ![PySide6](https://img.shields.io/badge/GUI-PySide6-green?logo=qt) ![Licencia](https://img.shields.io/badge/License-MIT-purple)

**PDF Audiobook Studio** es una aplicación de escritorio diseñada para convertir documentos PDF extensos (libros, manuales, artículos o apuntes de cientos de páginas) en audiolibros de calidad profesional. Cuenta con dos ediciones independientes: una **aplicación nativa en Swift (macOS)** optimizada para el ecosistema Apple y una **versión multiplataforma en Python (PySide6)**.

---

## 🌟 Dos Ediciones Disponibles

| Edición | Plataforma | Cómo ejecutar | Motores de Voz |
|---|---|---|---|
| **Swift Nativa (macOS)** 🍎 | macOS 14+ | `cd swift && ./build.sh` | **Google AI Pro / Cloud TTS**, **Microsoft Edge Neural**, **Grok TTS (xAI)**, **OpenAI TTS** |
| **Python (PySide6)** 🐍 | macOS / Linux / Windows | `python main.py` | **Google AI Pro / Cloud TTS**, **Edge-TTS**, **gTTS**, **pyttsx3 (local)** |

> [!NOTE]
> La edición nativa de macOS **no utiliza las voces del sistema de Apple** (AVSpeechSynthesizer), ya que su entonación plana y sintética resulta monótona en lecturas largas. En su lugar, emplea modelos neuronales en la nube que modulan la prosodia, pausas y emoción según el contexto de cada oración.

---

## 🎙️ Motores de Voz Soportados

### 1. 👑 Google AI Pro / Cloud TTS (Voces Hermosas de Google)
Compatible con cuentas **Google AI Pro** (como cuentas de Gemini Advanced) y claves de Google Cloud o [Google AI Studio](https://aistudio.google.com/apikey).
* **Voces Journey (Hiperrealistas y Narrativas):**
  * `es-ES-Journey-F`: **Journey · Princesa de Cuento 👑** (Voz femenina dulce, mágica y cautivadora, perfecta para historias y novelas).
  * `es-ES-Journey-D`: **Journey · Narrador Legendario** (Voz masculina profunda y literaria).
  * `es-US-Journey-F`: **Journey · Princesa Latina 👑** (Español neutro / US, cálida y encantadora).
  * `es-US-Journey-D`: **Journey · Narrador Latino** (Tono envolvente y cercano).
* **Voces Studio (Grabadas en estudio acústico profesional):**
  * `es-ES-Studio-C`: **Studio · Dama Distinguida ✨** (Timbre fino y refinado).
  * `es-ES-Studio-F`: **Studio · Narradora Cálida** (Articulación de élite para audiolibros extensos).
* **Voces Multimodales Gemini (Google DeepMind - `gemini-3.8-flash`):**
  * `gemini-kore`: **Kore (Princesa Dulce) 🌸**
  * `gemini-aoede`: **Aoede (Musa Artística) 🎶**
  * `gemini-leda`: **Leda (Regia y Elegante) 👑**
  * `gemini-callirrhoe`: **Callirrhoe (Cristalina) 💧**
  * `gemini-puck`, `gemini-charon`, `gemini-fenrir`, `gemini-zephyr`.
* **Voces Neural2 (DeepMind):** `es-ES-Neural2-A`, `es-ES-Neural2-C` (Dulce y Melódica), `es-ES-Neural2-E` (Princesa Serena).

### 2. ⚡ Microsoft Edge Neural (Gratis y sin API Key)
Voces neuronales de alta calidad de Microsoft Edge (`Álvaro`, `Elvira`, `Dalia`, `Jorge`, `Elena`, `Andrew Multilingual`...). Conectado al endpoint de alta disponibilidad `api.msedgeservices.com`.

### 3. 🧠 Grok TTS (xAI)
Voces de xAI (`Ara`, `Eve`, `Rex`, `Sal`...). Incluye detección automática de español y normalización de números y abreviaturas. Requiere API key de [console.x.ai](https://console.x.ai).

### 4. 📖 OpenAI TTS
Voces neuronales (`Coral`, `Verse`, `Ballad`, `Sage`...) con instrucciones especializadas de narrador de audiolibro para dramatizar preguntas, exclamaciones y diálogos. Requiere API key de [platform.openai.com](https://platform.openai.com).

---

## ✨ Características Principales

* **🗂️ Un Archivo por Capítulo:** Detecta automáticamente el índice del PDF (marcadores TOC o encabezados tipográficos) y exporta una carpeta con un archivo de audio independiente por cada capítulo o parte.
* **🔍 Vision OCR Nativo:** En macOS, los PDFs escaneados o basados en imágenes son procesados automáticamente mediante Apple Vision OCR (español e inglés) sin necesidad de Tesseract.
* **💾 Persistencia con SQLite:** El progreso de conversión se guarda bloque por bloque en una base de datos local. Si cierras la aplicación o se interrumpe la conexión, puedes reanudar el proyecto exactamente donde quedó.
* **⏸️ Control de Conversión:** Pausa, reanuda o cancela la conversión en cualquier momento con liberación inmediata de recursos.
* **🧹 Limpieza Inteligente de Texto:** Normalización de ligaduras tipográficas, corrección de guiones de fin de línea, eliminación de pies de página repetitivos y opción de **"Omitir símbolos"** para evitar que el motor pronuncie caracteres como asteriscos o barras.
* **🎵 Formatos de Salida:** Exportación directa en **MP3** (unión sin pérdidas de streams neuronales), **M4A** (con metadatos AAC) y **WAV**.
* **🔐 Seguridad de Credenciales:** En macOS, todas las claves de API (Google, xAI, OpenAI) se almacenan de forma segura y encriptada en el **Llavero del Sistema (Apple Keychain)**.
* **🌓 Modo Claro y Oscuro:** Diseño visual moderno adaptado a las preferencias del sistema.

---

## 🚀 Inicio Rápido

### Edición Nativa para Mac (Swift / SwiftUI)

#### Requisitos:
* macOS 14 (Sequoia) o superior.
* Xcode 16+ instalado.
* XcodeGen: `brew install xcodegen`

#### Compilación y ejecución:
```bash
cd swift
./build.sh
```
El script generará el proyecto con XcodeGen, compilará el binario y abrirá la aplicación lista para usar.

---

### Edición en Python (PySide6)

#### Requisitos:
* Python 3.13.
* FFmpeg instalado (`brew install ffmpeg` en macOS, o en el PATH en Windows/Linux).

#### Instalación rápida:
```bash
# macOS / Linux
./install.sh
source venv/bin/activate
python main.py

# Windows (PowerShell)
.\install.ps1
.\venv\Scripts\activate
python main.py
```

---

## 🔑 Configuración de Claves de API (Opcional)

Puedes usar la aplicación inmediatamente de forma gratuita con las voces **Edge Neural**. Si deseas habilitar los motores de IA avanzada:

1. **Google AI Pro / Cloud TTS:**
   * Entra a [Google AI Studio](https://aistudio.google.com/apikey) con tu cuenta de Google.
   * Crea una API Key (gratuita e inmediata).
   * En la app, abre **Ajustes**, pega tu clave y haz clic en **Guardar**.
2. **Grok TTS:** Obtén tu clave en [console.x.ai](https://console.x.ai/team/default/api-keys) (`xai-...`).
3. **OpenAI TTS:** Obtén tu clave en [platform.openai.com/api-keys](https://platform.openai.com/api-keys) (`sk-...`).

---

## 🏗️ Estructura del Repositorio

```
pdf-audiobook-studio/
├── swift/                         # Edición nativa macOS (SwiftUI)
│   ├── PDFAudiobookStudio/
│   │   ├── Models/               # Catálogo de voces, modelos y opciones
│   │   ├── Pipeline/             # Extractor PDF, Vision OCR, Chunker, AudioBuilder
│   │   ├── TTS/                  # Clientes TTS (Google, Edge, Grok, OpenAI)
│   │   ├── Persistence/          # SQLite Store y Keychain Manager
│   │   └── Views/                # Vistas SwiftUI, temas y ViewModels
│   ├── build.sh                  # Script de compilación automática
│   └── project.yml               # Especificación de XcodeGen
├── app/                           # Edición Python (PySide6)
│   ├── core/                     # Lógica de audio, extracción, chunker y TTS
│   ├── gui/                      # Interfaz PySide6 y widgets
│   ├── data/                     # Persistencia SQLite
│   └── utils/                    # Manejo de archivos y logs
├── tests/                         # Pruebas unitarias
├── install.sh / install.ps1       # Scripts de instalación de entorno
├── main.py                        # Entrada de la versión Python
└── requirements.txt               # Dependencias de Python
```

---

## 🧪 Pruebas Unitarias

Para ejecutar la batería de pruebas automatizadas:
```bash
python -m unittest discover tests
```

---

## ⚖️ Licencia y Aviso Legal

Este proyecto se distribuye bajo la licencia MIT. Diseñado para uso personal y educativo. Asegúrate de contar con los derechos o autorización correspondiente de los documentos que proceses.
