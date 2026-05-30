# Guía de Uso: PDF Audiobook Studio

Esta guía te ayudará a aprovechar al máximo todas las funciones de **PDF Audiobook Studio**.

---

## 1. Primeros Pasos

Al iniciar la aplicación con `python main.py`, verás una interfaz dividida en tres grandes bloques:
1. **Panel Lateral Izquierdo:** Aquí reside el historial de tus proyectos creados en tu base de datos local. Al hacer clic en cualquiera de ellos, la aplicación cargará el archivo y la configuración para continuar la conversión si quedó incompleta.
2. **Área de Trabajo Central (Izquierda):** El panel de configuración. Aquí arrastras el PDF y ajustas los parámetros de conversión (rango de páginas, velocidad, carpeta de salida, etc.).
3. **Área de Vista Previa (Derecha):** Al cargar un PDF, se mostrará el texto extraído de las primeras páginas para que verifiques que el extractor funciona correctamente y que el texto no contiene errores antes de comenzar a generar audio.
4. **Consola y Controles Inferiores:** Muestra la barra de progreso del audiolibro y una terminal interactiva que escribe en tiempo real los eventos importantes (por ejemplo: "Iniciando bloque 5/45", "Sintetizando página 12...").

---

## 2. Flujo de Trabajo Detallado

### Paso 1: Carga de un PDF Largo
- Suelta el archivo PDF de tu elección sobre el área punteada que dice **"Arrastra y suelta tu archivo PDF aquí"**.
- O bien, haz clic en esa misma zona punteada. Se abrirá una ventana de exploración del sistema macOS para que selecciones el archivo manualmente.
- Una vez cargado, observa los metadatos. Si el PDF tiene **160 páginas o más**, la aplicación calculará el tamaño total en MB y comprobará de forma inteligente si el documento contiene texto editable o si es un documento escaneado (imágenes).

### Paso 2: Selección del Rango de Páginas
Por defecto, la aplicación cargará todo el rango de páginas (desde la página 1 hasta la última). Si solo deseas escuchar un capítulo o sección específica:
- Ajusta el valor del control **"Desde"** (por ejemplo, página 25).
- Ajusta el valor del control **"Hasta"** (por ejemplo, página 50).
- La aplicación solo extraerá y sintetizará el texto comprendido dentro de ese intervalo.

### Paso 3: Selección del Motor de Voz y Parámetros
- **Motor de Voz:** Te recomendamos firmemente seleccionar la opción **Edge-TTS (Alta Calidad)**. Este motor utiliza sintetizadores neuronales avanzados en la nube de Microsoft, proporcionando pausas naturales, entonación conversacional y una pronunciación excelente tanto en español como en inglés.
- **Voz / Idioma:** Selecciona tu voz favorita (como Álvaro para acento de España, Jorge o Dalia para acento de México, o voces en inglés si estás estudiando ese idioma).
- **Velocidad:** Puedes acelerar o ralentizar la narración según tus necesidades de comprensión (desde 0.5x hasta 2.0x).
- **Formato:** Selecciona si deseas empaquetar el audiolibro en formato **MP3** (más ligero y compatible con cualquier reproductor) o **WAV** (audio sin compresión).

### Paso 4: Definición de la Carpeta de Destino
Haz clic en el botón **"📁 Buscar"** y selecciona la carpeta en tu computadora donde deseas guardar el audiolibro final. Por defecto, la aplicación seleccionará la misma carpeta donde reside el archivo PDF de origen.

### Paso 5: Proceso de Conversión
- Haz clic en **"▶ Iniciar Conversión"**.
- El extractor dividirá inteligentemente el texto en bloques asíncronos y comenzará a generar los archivos de audio en segundo plano sin congelar la ventana gráfica.
- **Pausa y Reanudación:** Si necesitas pausar el proceso para liberar ancho de banda o procesador, haz clic en **"⏸ Pausar"**. Cuando estés listo, haz clic en **"⏯ Reanudar"**.
- Si el proceso falla por algún motivo (pérdida de red en motores online), puedes cerrar la app o presionar cancelar. Al volver a abrir la aplicación, selecciona el proyecto en la barra lateral izquierda y presiona **"Iniciar Conversión"**. SQLite detectará qué bloques de audio ya se guardaron físicamente en tu carpeta temporal y continuará directamente con los bloques faltantes.

---

## 3. Consejos para un Audiolibro Profesional

1. **Aprovecha la caché temporal:** Si quieres cambiar de velocidad de reproducción o de voz pero ya tenías chunks hechos, el sistema de base de datos te permite guardar tus progresos. No limpies la caché temporal (`Limpiar Caché Temporal` en el panel lateral) a menos que hayas completado tus proyectos o desees liberar espacio en disco.
2. **Instalación de FFmpeg:** Si deseas que el audio final tenga un volumen perfectamente uniforme entre páginas, instala `ffmpeg` mediante `brew install ffmpeg`. La aplicación activará automáticamente el filtro de **normalización dinámica** de pydub para un sonido más agradable al oído.
