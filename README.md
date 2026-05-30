# 🎧 PDF Audiobook Studio 🎙️

![PDF Audiobook Studio](https://img.shields.io/badge/Status-Ready%20for%20Distribution-success) ![Python](https://img.shields.io/badge/Python-3.13-blue) ![PySide6](https://img.shields.io/badge/GUI-PySide6-green)

**PDF Audiobook Studio** es una aplicación de escritorio profesional y elegante diseñada para convertir documentos PDF largos (incluso de más de 160 páginas) en archivos de audio de alta calidad. ¡Convierte tus libros, apuntes o manuales en audiolibros organizados y llévalos contigo a donde quieras! 🚀

---

## ✨ Características Principales

*   **🎙️ Múltiples Motores de Voz (TTS):** Soporte para Edge-TTS (voces neuronales de alta calidad), pyttsx3 (offline) y gTTS (Google).
*   **📚 Soporte para Documentos Largos:** Procesamiento optimizado por bloques (chunks) para no saturar la memoria, ideal para PDFs de cientos de páginas.
*   **⏸️ Control Total:** Posibilidad de pausar, reanudar o cancelar la conversión en cualquier momento.
*   **💾 Persistencia:** Tu progreso se guarda automáticamente en una base de datos local (SQLite). ¡Si cierras la app, puedes continuar desde donde lo dejaste!
*   **🎵 Formatos de Exportación:** Soporte para salida en `.mp3`, `.wav` y `.m4a` (con metadatos y etiquetas).
*   **🎨 Interfaz Moderna y Elegante:** Desarrollada con PySide6, incluye temas Claro 💡 y Oscuro 🌙, barra de progreso interactiva y una terminal de registros en tiempo real.

---

## 🛠️ Requisitos Previos (Dependencias)

Para ejecutar esta aplicación localmente, necesitarás:

1.  **Python 3.13** instalado en tu sistema.
2.  **FFmpeg:** Requerido para exportar en M4A y unir audios con precisión. 
    *   En macOS: `brew install ffmpeg`
    *   En Windows: Descarga y añade FFmpeg al PATH.
    *   En Linux: `sudo apt install ffmpeg`

### Librerías de Python
Las dependencias están listadas en el archivo `requirements.txt`:
*   `PySide6` (Interfaz Gráfica)
*   `PyMuPDF` (Extracción de texto rápida y precisa)
*   `edge-tts`, `pyttsx3`, `gTTS` (Motores de Texto a Voz)
*   `pydub` (Manipulación y unión de audio)

---

## 🚀 Instalación y Uso (Tutorial)

Sigue estos sencillos pasos para empezar a usar la aplicación:

### 1. Clonar el repositorio
```bash
git clone https://github.com/TU_USUARIO/pdf-audiobook-studio.git
cd pdf-audiobook-studio
```

### 2. Crear un Entorno Virtual e instalar dependencias
Es altamente recomendable usar un entorno virtual:
```bash
python3 -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Ejecutar la Aplicación
```bash
python main.py
```

### 4. ¡Convierte tu primer PDF!
1. Arrastra y suelta un archivo `.pdf` en el área de carga.
2. Selecciona el rango de páginas.
3. Elige el motor de voz (recomendamos **Edge-TTS** para máxima calidad) y ajusta la velocidad.
4. Selecciona la carpeta de destino.
5. Haz clic en **"▶ Iniciar Conversión"**.
6. ¡Relájate mientras la aplicación hace la magia! ✨ Puedes ver el progreso en tiempo real en la terminal inferior.

---

## 🏗️ Arquitectura del Proyecto

El proyecto está diseñado con una arquitectura robusta MVC y multiproceso:

*   `main.py`: Punto de entrada que inicializa la GUI.
*   `app/gui/`: Contiene la ventana principal, temas personalizados y widgets.
*   `app/core/`: Motores de procesamiento, extracción de PDF, limpieza de texto, conversión a voz y ejecución asíncrona (`QThread`).
*   `app/data/`: Manejo de SQLite para persistencia y recuperación de proyectos fallidos.
*   `tests/`: Suite de pruebas unitarias automatizadas (`pytest`).

---

## 👨‍💻 Contribución

¡Las contribuciones son bienvenidas! Si deseas mejorar la app (por ejemplo, añadiendo detección avanzada de capítulos mediante TOC), siéntete libre de hacer un _fork_ del repositorio y enviar un _pull request_.

## ⚖️ Aviso Legal y Copyright

⚠️ **Importante:** Esta aplicación está diseñada para uso personal. Asegúrate de tener los derechos o el permiso necesario para convertir y reproducir el contenido de los documentos PDF que proceses. No promuevas la infracción de derechos de autor.

---
_Hecho con ❤️ para que nunca pares de aprender y escuchar._
