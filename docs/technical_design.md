# Diseño Técnico y Empaquetado: PDF Audiobook Studio

Este documento detalla la arquitectura de software de **PDF Audiobook Studio**, el flujo de datos de conversión de PDFs extensos y las directrices profesionales para empaquetar y distribuir la aplicación en entornos de producción (con especial foco en macOS).

---

## 1. Arquitectura de Software

La aplicación sigue un patrón de diseño **MVC/Modular** adaptado para aplicaciones de escritorio con interfaces reactivas:

```
                  ┌────────────────────────────────────────┐
                  │            Capa de Interfaz            │
                  │        (PySide6 MainWindow + QSS)      │
                  └───────────────────┬────────────────────┘
                                      │
                         [Lanza hilo en 2do plano]
                                      ▼
                  ┌────────────────────────────────────────┐
                  │             Capa Asíncrona             │
                  │          (ConversionWorker)            │
                  └───────────────────┬────────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          ▼                           ▼                           ▼
┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
│Capítulo/Fragmento│        │   Motores TTS    │        │Unión & Filtros   │
│  (pdf_extractor, │        │(BaseTTSEngine -> │        │     de Audio     │
│ text_cleaner,    │        │ Edge, Local,     │        │ (audio_builder)  │
│ chunker)         │        │  Google TTS)     │        └──────────────────┘
└─────────┬────────┘        └─────────┬────────┘
          │                           │
          └─────────────┬─────────────┘
                        ▼
            ┌───────────────────────┐
            │ Capa de Persistencia  │
            │   (SQLite Database)   │
            └───────────────────────┘
```

### Componentes Clave:
1. **Extracción y Fragmentación Segmentada:**
   - La lectura convencional de PDFs tiende a cargar todo el archivo en memoria o generar una sola cadena de texto masiva. Esto congela los motores de síntesis.
   - Nuestro diseño utiliza `pdf_extractor.py` (PyMuPDF) para leer página por página bajo demanda.
   - `chunker.py` agrupa estas páginas y divide los textos en segmentos pequeños (máximo 1800-2000 caracteres) respetando los límites de las oraciones. Esto evita desbordamientos en las llamadas HTTPS de `edge-tts` y permite guardar estados parciales.
2. **Caché SQLite Local:**
   - Cada bloque fragmentado se almacena en la tabla `chunks` vinculada a un `project_id`.
   - Cuando se completa la síntesis de un fragmento, su estado cambia a `COMPLETED` y se registra la ruta física de su archivo `.mp3` o `.wav` temporal.
   - Este modelo garantiza una resiliencia del 100%: si hay un corte de energía, red o cancelación manual, el sistema puede consultar las rutas físicas válidas en la base de datos y saltar bloques ya generados al reanudar.
3. **Concurrencia con QThread:**
   - La GUI de Qt corre en el hilo principal (*main thread*). Llamar a APIs de síntesis web o local en el main thread congelaría la ventana ("Application Not Responding").
   - `ConversionWorker` hereda de `QThread`. Corre de forma aislada e interactúa con la interfaz de usuario mediante mecanismos de señales y slots seguros de Qt (`Signal`), lo que evita colisiones de memoria.

---

## 2. Empaquetado y Distribución para Producción

Para convertir este script de Python en una aplicación nativa instalable (especialmente un archivo `.app` en macOS o `.exe` en Windows), se proponen las siguientes metodologías robustas.

### Opción A: PyInstaller (La más sencilla y estable para macOS)
PyInstaller compila el intérprete de Python, tus scripts y las dependencias compiladas (C extensions de PySide6 y PyMuPDF) dentro de un único paquete ejecutable.

#### Pasos para generar un ejecutable independiente en macOS:

1. **Instala PyInstaller en tu entorno virtual `hokkaido`:**
   ```bash
   pyenv activate hokkaido
   pip install pyinstaller
   ```

2. **Crea el archivo `.spec` de configuración o compila directamente:**
   Dado que usamos recursos de PySide6, es muy recomendable compilar especificando el modo ventana (`--windowed`) y asignando un icono:
   ```bash
   pyinstaller --noconfirm --onedir --windowed \
     --name="PDF Audiobook Studio" \
     --add-data="app:app" \
     --clean \
     main.py
   ```

3. **Verificación de dependencias dinámicas:**
   - PyInstaller analiza los imports estáticos. Sin embargo, dado que `edge-tts`, `pydub` y `pyttsx3` pueden importar módulos dinámicamente, asegúrate de añadirlos si hay fallos en las "hidden imports".
   - Si tienes problemas de imports dinámicos en la app empaquetada, compila usando:
     ```bash
     pyinstaller --noconfirm --onedir --windowed \
       --name="PDF Audiobook Studio" \
       --hidden-import="edge_tts" \
       --hidden-import="pyttsx3" \
       --hidden-import="pydub" \
       --hidden-import="gtts" \
       --clean \
       main.py
     ```

4. **Resultado:**
   Se creará una carpeta `dist/` que contendrá el paquete nativo **`PDF Audiobook Studio.app`**. Podrás arrastrarlo directamente a tu carpeta de `/Applications` de macOS.

---

### Opción B: Nuitka (Compilación a C/C++ de alto rendimiento)
Nuitka no empaqueta el intérprete, sino que traduce tu código Python a código ejecutable C y lo enlaza con `libpython`. Esto reduce los tiempos de inicio del programa y aumenta la velocidad de ejecución.

1. **Instala Nuitka:**
   ```bash
   pip install nuitka
   ```
2. **Ejecuta la compilación con soporte para PySide6:**
   ```bash
   python -m nuitka --standalone --macos-create-app-bundle --enable-plugin=pyside6 --show-memory main.py
   ```
3. Nuitka generará un paquete altamente optimizado y compilado en C nativo.

---

### Opción C: Briefcase (Empaquetado oficial del proyecto BeeWare)
Briefcase es excelente si deseas empaquetar aplicaciones de escritorio y móviles con un look 100% nativo mediante plantillas Xcode en macOS.

1. Instala Briefcase: `pip install briefcase`
2. Configura tu proyecto con `briefcase new` y sigue las instrucciones para enlazar los scripts de `pdf-audiobook-studio`.
3. Ejecuta `briefcase package` para crear una imagen de disco `.dmg` distribuible y firmada para macOS.

---

## 3. Firmado y Notarización en macOS (Distribución Pública)

Si deseas compartir el archivo `.app` empaquetado con otros usuarios de macOS fuera de tu computadora local, el sistema de seguridad *Gatekeeper* de Apple bloqueará la aplicación indicando que es de "un desarrollador no identificado". Para evitar esto en distribuciones comerciales, debes seguir estos pasos:

1. **Obtén una cuenta de desarrollador de Apple** (Apple Developer Program).
2. **Firma el código (`codesign`):**
   Utiliza tu certificado "Developer ID Application" para firmar el binario empaquetado y todos sus frameworks:
   ```bash
   codesign --deep --force --options runtime --sign "Developer ID Application: Tu Nombre (ID)" dist/PDF\ Audiobook\ Studio.app
   ```
3. **Crea un archivo ZIP o DMG:**
   ```bash
   ditto -c -k --keepParent dist/PDF\ Audiobook\ Studio.app dist/PDF_Audiobook_Studio.zip
   ```
4. **Envía a Notarización de Apple:**
   Sube la aplicación a los servidores de Apple para su escaneo de seguridad automático:
   ```bash
   xcrun notarytool submit dist/PDF_Audiobook_Studio.zip --apple-id "tu-email@apple.com" --password "app-specific-password" --team-id "TU_TEAM_ID" --wait
   ```
5. **Grapar el ticket de notarización:**
   Una vez aprobado, grapa el certificado de seguridad en la aplicación física:
   ```bash
   xcrun stapler staple dist/PDF\ Audiobook\ Studio.app
   ```

Una vez completado este proceso, tu audiolibro de escritorio se abrirá de forma instantánea y segura en cualquier Mac del mundo sin advertencias de seguridad de Gatekeeper.
