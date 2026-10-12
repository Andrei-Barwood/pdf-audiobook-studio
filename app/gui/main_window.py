import os
import sys
from typing import Dict, Any, List, Optional
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, 
    QFileDialog, QComboBox, QSpinBox, QProgressBar, QMessageBox, 
    QSplitter, QTextEdit, QFormLayout, QLineEdit, QListWidget, QListWidgetItem,
    QCheckBox, QScrollArea,
)
from PySide6.QtCore import Qt, Slot, QSettings

from app.gui.styles import DARK_THEME_QSS, LIGHT_THEME_QSS
from app.gui.widgets import DragDropFrame, CardFrame, LogTerminal
from app.core.pdf_extractor import PDFExtractor
from app.core.chunker import TextChunker
from app.core.chapter_detector import Chapter, ChapterDetector
from app.core.project_manager import ProjectManager
from app.core.tts_engine import get_tts_engine
from app.core.job_runner import ConversionWorker
from app.core.text_cleaner import TextCleaner
from app.utils.logger import logger
from app.utils.file_utils import cached_audio_count, clean_temp_dir, destination_note

class MainWindow(QMainWindow):
    """The central application window for PDF Audiobook Studio, integrating core pipelines and elegant styling."""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PDF Audiobook Studio")
        self.resize(1000, 700)
        self.setMinimumSize(750, 500)
        
        self.pdf_path: Optional[str] = None
        self.extractor: Optional[PDFExtractor] = None
        self.chunks: List[Dict[str, Any]] = []
        self.active_project: Optional[Dict[str, Any]] = None
        self.worker: Optional[ConversionWorker] = None
        self.detected_chapters: List[Chapter] = []
        
        self.batch_queue: List[str] = []
        
        self.is_dark_theme = True
        self.settings = QSettings("PDFAudiobookStudio", "PDFAudiobookStudio")
        
        self.setup_ui()
        self.apply_theme()
        self.load_recent_projects()
        
        logger.info("Application main window initialized successfully.")

    def setup_ui(self) -> None:
        """Constructs widgets, layouts, and panels."""
        central_widget = QWidget(self)
        self.setCentralWidget(central_widget)
        
        # Main Outer Horizontal Layout (Left: Projects sidebar, Right: Workspace Area)
        main_layout = QHBoxLayout(central_widget)
        main_layout.setContentsMargins(15, 15, 15, 15)
        main_layout.setSpacing(15)

        # ----------------------------------------------------
        # SIDEBAR: RECENT PROJECTS PANEL
        # ----------------------------------------------------
        sidebar = CardFrame(self)
        sidebar.setMaximumWidth(220)
        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setContentsMargins(10, 10, 10, 10)
        
        sidebar_title = QLabel("Proyectos Recientes", sidebar)
        sidebar_title.setObjectName("sectionTitle")
        sidebar_layout.addWidget(sidebar_title)
        
        self.projects_list = QListWidget(sidebar)
        self.projects_list.itemClicked.connect(self.load_selected_project)
        sidebar_layout.addWidget(self.projects_list)
        
        btn_clear_cache = QPushButton("Limpiar Caché Temporal", sidebar)
        btn_clear_cache.clicked.connect(self.clear_temp_cache)
        sidebar_layout.addWidget(btn_clear_cache)
        
        main_layout.addWidget(sidebar)

        # ----------------------------------------------------
        # MAIN WORKSPACE SPLITTER (Top: Controls/Config, Bottom: Logs)
        # ----------------------------------------------------
        workspace_splitter = QSplitter(Qt.Vertical)
        
        # Inner Upper Area: Splitter (Left: PDF Upload & Settings, Right: Preview Panel)
        upper_area = QWidget()
        upper_layout = QHBoxLayout(upper_area)
        upper_layout.setContentsMargins(0, 0, 0, 0)
        upper_layout.setSpacing(15)
        
        # Workspace Panel LEFT: Config Card
        config_scroll = QScrollArea(upper_area)
        config_scroll.setWidgetResizable(True)
        config_scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")
        
        config_card = CardFrame()
        config_scroll.setWidget(config_card)
        
        config_layout = QVBoxLayout(config_card)
        config_layout.setContentsMargins(15, 15, 15, 15)
        config_layout.setSpacing(10)
        
        # Header Row
        header_layout = QHBoxLayout()
        title_label = QLabel("PDF Audiobook Studio", config_card)
        title_label.setObjectName("titleLabel")
        header_layout.addWidget(title_label)
        
        header_layout.addStretch()
        
        self.theme_btn = QPushButton("💡 Tema Claro", config_card)
        self.theme_btn.setMaximumWidth(120)
        self.theme_btn.clicked.connect(self.toggle_theme)
        header_layout.addWidget(self.theme_btn)
        
        config_layout.addLayout(header_layout)
        
        # Upload Area
        self.upload_zone = DragDropFrame(config_card)
        self.upload_zone.files_dropped.connect(self.load_pdf_batch)
        config_layout.addWidget(self.upload_zone)
        
        # File Metadata Form Panel
        self.meta_card = QWidget(config_card)
        meta_form = QFormLayout(self.meta_card)
        meta_form.setContentsMargins(0, 5, 0, 5)
        meta_form.setSpacing(6)
        
        self.lbl_pdf_name = QLabel("Sin archivo cargado", self.meta_card)
        self.lbl_pdf_pages = QLabel("-", self.meta_card)
        self.lbl_pdf_size = QLabel("-", self.meta_card)
        self.lbl_pdf_ocr = QLabel("-", self.meta_card)
        
        meta_form.addRow("Archivo:", self.lbl_pdf_name)
        meta_form.addRow("Páginas Totales:", self.lbl_pdf_pages)
        meta_form.addRow("Tamaño:", self.lbl_pdf_size)
        meta_form.addRow("OCR Requerido:", self.lbl_pdf_ocr)
        
        config_layout.addWidget(self.meta_card)
        
        # Audio & Configuration Form Panel
        settings_title = QLabel("Configuración de Conversión", config_card)
        settings_title.setObjectName("sectionTitle")
        config_layout.addWidget(settings_title)
        
        settings_form = QFormLayout()
        settings_form.setSpacing(8)
        
        # Range Selectors
        range_layout = QHBoxLayout()
        self.spn_start_page = QSpinBox(config_card)
        self.spn_start_page.setMinimum(1)
        self.spn_start_page.setEnabled(False)
        self.spn_end_page = QSpinBox(config_card)
        self.spn_end_page.setMinimum(1)
        self.spn_end_page.setEnabled(False)
        
        range_layout.addWidget(QLabel("Desde:"))
        range_layout.addWidget(self.spn_start_page)
        range_layout.addWidget(QLabel("Hasta:"))
        range_layout.addWidget(self.spn_end_page)
        settings_form.addRow("Rango de páginas:", range_layout)
        self.spn_start_page.valueChanged.connect(self.refresh_chapter_list)
        self.spn_end_page.valueChanged.connect(self.refresh_chapter_list)

        self.chk_split_chapters = QCheckBox(
            "Un archivo por capítulo (según el índice)",
            config_card,
        )
        self.chk_split_chapters.setChecked(self.settings.value("split_by_chapter", True, type=bool))
        self.chk_split_chapters.setToolTip(
            "Lee el índice del PDF y exporta una carpeta con un audio por parte o capítulo. "
            "Si el índice mezcla secciones, se agrupa por PARTES / capítulos."
        )
        self.chk_split_chapters.toggled.connect(self.on_split_chapters_toggled)
        settings_form.addRow("Capítulos:", self.chk_split_chapters)

        self.lbl_chapters = QLabel("Carga un PDF para detectar el índice.", config_card)
        self.lbl_chapters.setWordWrap(True)
        settings_form.addRow("", self.lbl_chapters)

        self.lst_chapters = QListWidget(config_card)
        self.lst_chapters.setMaximumHeight(130)
        self.lst_chapters.setVisible(False)
        settings_form.addRow("", self.lst_chapters)
        
        # TTS Engine selector
        self.cmb_engine = QComboBox(config_card)
        self.cmb_engine.addItems(["Edge-TTS (Alta Calidad)", "Google AI Pro / Cloud TTS 👑", "pyttsx3 (Offline Local)", "gTTS (Google Online)"])
        self.cmb_engine.currentIndexChanged.connect(self.populate_voices)
        settings_form.addRow("Motor de Voz:", self.cmb_engine)
        
        # Voice Dropdown
        self.cmb_voices = QComboBox(config_card)
        settings_form.addRow("Voz / Idioma:", self.cmb_voices)

        self.chk_omit_symbols = QCheckBox(
            "Omitir símbolos (Elena no dirá asterisco, barra, almohadilla…)",
            config_card,
        )
        self.chk_omit_symbols.setChecked(self.settings.value("omit_symbols", True, type=bool))
        self.chk_omit_symbols.setToolTip(
            "Las voces de Edge, sobre todo Elena, pronuncian los símbolos. "
            "Actívalo para silenciarlos y dejar solo el texto."
        )
        self.chk_omit_symbols.toggled.connect(self.on_omit_symbols_toggled)
        settings_form.addRow("Lectura:", self.chk_omit_symbols)
        
        # Speed Slider scale
        self.cmb_speed = QComboBox(config_card)
        self.cmb_speed.addItems(["0.5x (Muy lento)", "0.75x (Lento)", "1.0x (Normal)", "1.25x (Rápido)", "1.5x (Muy rápido)", "2.0x (Veloz)"])
        self.cmb_speed.setCurrentIndex(2) # Default 1.0x
        settings_form.addRow("Velocidad:", self.cmb_speed)
        
        # Output Format
        self.cmb_format = QComboBox(config_card)
        self.cmb_format.addItems(["MP3", "WAV"])
        settings_form.addRow("Formato:", self.cmb_format)
        
        # Output folder browse selector
        folder_layout = QHBoxLayout()
        self.txt_output_dir = QLineEdit(config_card)
        self.txt_output_dir.setPlaceholderText("Carpeta de salida...")
        btn_browse = QPushButton("📁 Buscar", config_card)
        btn_browse.clicked.connect(self.browse_output_dir)
        folder_layout.addWidget(self.txt_output_dir)
        folder_layout.addWidget(btn_browse)
        settings_form.addRow("Destino:", folder_layout)
        
        config_layout.addLayout(settings_form)
        upper_layout.addWidget(config_scroll)
        
        # Workspace Panel RIGHT: Preview Card
        preview_card = CardFrame(upper_area)
        preview_layout = QVBoxLayout(preview_card)
        preview_layout.setContentsMargins(15, 15, 15, 15)
        
        preview_title = QLabel("Vista Previa de Texto Extraído", preview_card)
        preview_title.setObjectName("sectionTitle")
        preview_layout.addWidget(preview_title)
        
        self.txt_preview = QTextEdit(preview_card)
        self.txt_preview.setReadOnly(True)
        self.txt_preview.setPlaceholderText("El texto de las primeras páginas del PDF cargado se mostrará aquí para validación...")
        preview_layout.addWidget(self.txt_preview)
        
        upper_layout.addWidget(preview_card)
        
        # Equal stretch for config and preview panel
        upper_layout.setStretch(0, 1)
        upper_layout.setStretch(1, 1)
        
        workspace_splitter.addWidget(upper_area)

        # ----------------------------------------------------
        # BOTTOM AREA: PROGRESS & SYSTEM TERMINAL
        # ----------------------------------------------------
        bottom_area = QWidget()
        bottom_layout = QVBoxLayout(bottom_area)
        bottom_layout.setContentsMargins(0, 0, 0, 0)
        bottom_layout.setSpacing(10)
        
        # Progress Controls Row
        progress_card = CardFrame(bottom_area)
        prog_card_layout = QVBoxLayout(progress_card)
        prog_card_layout.setContentsMargins(15, 10, 15, 10)
        
        prog_label_layout = QHBoxLayout()
        self.lbl_progress_status = QLabel("Listo para convertir", progress_card)
        self.lbl_progress_status.setStyleSheet("font-weight: bold;")
        self.lbl_progress_percent = QLabel("0%", progress_card)
        self.lbl_progress_percent.setStyleSheet("font-weight: bold; color: #818CF8;")
        
        prog_label_layout.addWidget(self.lbl_progress_status)
        prog_label_layout.addStretch()
        prog_label_layout.addWidget(self.lbl_progress_percent)
        prog_card_layout.addLayout(prog_label_layout)
        
        # Progress Bar
        self.progress_bar = QProgressBar(progress_card)
        self.progress_bar.setValue(0)
        self.progress_bar.setTextVisible(False)
        prog_card_layout.addWidget(self.progress_bar)
        
        # Button Controls Area
        buttons_layout = QHBoxLayout()
        
        self.btn_start = QPushButton("▶ Iniciar Conversión", progress_card)
        self.btn_start.setObjectName("primaryButton")
        self.btn_start.setEnabled(False)
        self.btn_start.clicked.connect(self.start_conversion)
        buttons_layout.addWidget(self.btn_start)
        
        self.btn_pause = QPushButton("⏸ Pausar", progress_card)
        self.btn_pause.setEnabled(False)
        self.btn_pause.clicked.connect(self.pause_conversion)
        buttons_layout.addWidget(self.btn_pause)
        
        self.btn_resume = QPushButton("⏯ Reanudar", progress_card)
        self.btn_resume.setEnabled(False)
        self.btn_resume.clicked.connect(self.resume_conversion)
        buttons_layout.addWidget(self.btn_resume)
        
        self.btn_cancel = QPushButton("🛑 Cancelar", progress_card)
        self.btn_cancel.setObjectName("dangerButton")
        self.btn_cancel.setEnabled(False)
        self.btn_cancel.clicked.connect(self.cancel_conversion)
        buttons_layout.addWidget(self.btn_cancel)
        
        self.btn_open_folder = QPushButton("📂 Abrir Carpeta", progress_card)
        self.btn_open_folder.clicked.connect(self.open_output_folder)
        self.btn_open_folder.setEnabled(False)
        buttons_layout.addWidget(self.btn_open_folder)
        
        prog_card_layout.addLayout(buttons_layout)
        bottom_layout.addWidget(progress_card)
        
        # Log terminal
        self.log_terminal = LogTerminal(bottom_area)
        bottom_layout.addWidget(self.log_terminal)
        
        bottom_area.setLayout(bottom_layout)
        workspace_splitter.addWidget(bottom_area)
        
        # Set splitter sizes
        workspace_splitter.setSizes([450, 250])
        main_layout.addWidget(workspace_splitter)

    # ----------------------------------------------------
    # CORE INTERFACE FUNCTIONALITIES
    # ----------------------------------------------------
    def apply_theme(self) -> None:
        """Toggles styles cleanly based on theme settings."""
        if self.is_dark_theme:
            self.setStyleSheet(DARK_THEME_QSS)
            self.theme_btn.setText("💡 Tema Claro")
        else:
            self.setStyleSheet(LIGHT_THEME_QSS)
            self.theme_btn.setText("🌙 Tema Oscuro")

    def toggle_theme(self) -> None:
        """Toggles self.is_dark_theme boolean and updates styles."""
        self.is_dark_theme = not self.is_dark_theme
        self.apply_theme()
        self.log_terminal.append_log(f"Tema visual cambiado a {'Oscuro' if self.is_dark_theme else 'Claro'}.")

    def trigger_file_dialog(self) -> None:
        """Opens native file browse window for PDF uploads."""
        file_paths, _ = QFileDialog.getOpenFileNames(self, "Seleccionar archivo(s) PDF", "", "Documentos PDF (*.pdf)")
        if file_paths:
            self.load_pdf_batch(file_paths)

    def load_pdf_batch(self, file_paths: List[str]) -> None:
        """Handles a batch of dropped or selected PDFs."""
        if not file_paths:
            return
            
        # Clear any existing batch queue
        self.batch_queue = file_paths[1:]
        
        # Load the first one into the UI
        self.load_pdf(file_paths[0])
        
        if self.batch_queue:
            self.log_terminal.append_log(f"Lote detectado: {len(self.batch_queue)} PDF(s) en cola. Se procesarán automáticamente con la misma configuración.")
            self.lbl_pdf_name.setText(f"{self.lbl_pdf_name.text()} (+ {len(self.batch_queue)} en cola)")

    def browse_output_dir(self) -> None:
        """Opens native directory dialog to choose output path."""
        dir_path = QFileDialog.getExistingDirectory(self, "Seleccionar Carpeta de Destino")
        if dir_path:
            self.txt_output_dir.setText(dir_path)
            note = destination_note(dir_path)
            if note:
                self.log_terminal.append_log(note)

    def load_pdf(self, file_path: str) -> None:
        """Reads PDF metadata and updates form visuals."""
        if not file_path or not os.path.exists(file_path):
            return
            
        self.pdf_path = file_path
        self.log_terminal.append_log(f"Cargando PDF: {os.path.basename(file_path)}...")
        
        try:
            # Initialize core extractor
            self.extractor = PDFExtractor(file_path)
            meta = self.extractor.get_metadata()
            
            # Update fields
            self.lbl_pdf_name.setText(meta["name"])
            self.lbl_pdf_pages.setText(str(meta["page_count"]))
            self.lbl_pdf_size.setText(f"{meta['file_size_mb']} MB")
            self.lbl_pdf_ocr.setText("SÍ (Probablemente escaneado)" if meta["is_scanned"] else "NO (Texto editable)")
            
            # Spin box updates
            self.spn_start_page.setEnabled(True)
            self.spn_start_page.setMinimum(1)
            self.spn_start_page.setMaximum(meta["page_count"])
            self.spn_start_page.setValue(1)
            
            self.spn_end_page.setEnabled(True)
            self.spn_end_page.setMinimum(1)
            self.spn_end_page.setMaximum(meta["page_count"])
            self.spn_end_page.setValue(meta["page_count"])
            
            self.refresh_preview()
            self.detect_chapters()
            
            # Set default output dir if empty
            if not self.txt_output_dir.text():
                self.txt_output_dir.setText(os.path.dirname(file_path))
                
            self.btn_start.setEnabled(True)
            self.btn_open_folder.setEnabled(True)
            self.log_terminal.append_log(f"PDF '{meta['name']}' cargado con éxito. Listo para procesar.")
            
            # Auto-populate voices matching the engine
            self.populate_voices()
            
        except Exception as e:
            logger.error(f"Error loading PDF: {e}")
            QMessageBox.critical(self, "Error de Lectura", f"No se pudo cargar el PDF:\n{e}")
            self.lbl_pdf_name.setText("Error al cargar archivo")

    def on_split_chapters_toggled(self, checked: bool) -> None:
        """Persists the per-chapter export preference."""
        self.settings.setValue("split_by_chapter", checked)
        self.refresh_chapter_list()
        if checked:
            n = len(self.visible_chapters())
            if n >= 2:
                self.log_terminal.append_log(
                    f"Exportación por capítulos activada: {n} archivos de audio."
                )
            else:
                self.log_terminal.append_log(
                    "Exportación por capítulos activada. Se buscarán encabezados al convertir si el PDF no trae índice."
                )
        else:
            self.log_terminal.append_log("Se exportará un único archivo de audio.")

    def detect_chapters(self) -> None:
        """Read the PDF outline and show detected parts/chapters."""
        self.detected_chapters = []
        if not self.pdf_path:
            self.refresh_chapter_list()
            return
        try:
            detector = ChapterDetector(pdf_path=self.pdf_path)
            chapters = detector.detect()
            if len(chapters) >= 2 and not (
                len(chapters) == 1 and chapters[0].title == "Full Document"
            ):
                self.detected_chapters = chapters
                first = chapters[0]
                self.log_terminal.append_log(
                    f"Índice: {len(chapters)} partes/capítulos "
                    f"(pág. {first.start_page}–{chapters[-1].end_page})."
                )
                if first.start_page > 1:
                    self.log_terminal.append_log(
                        f"Las páginas 1–{first.start_page - 1} (portada/índice impreso) no se leen."
                    )
            else:
                self.detected_chapters = []
                self.log_terminal.append_log(
                    "Este PDF no tiene un índice de capítulos reconocible. Se puede exportar un solo archivo."
                )
        except Exception as e:
            logger.warning(f"Chapter detection failed: {e}")
            self.detected_chapters = []
        self.refresh_chapter_list()

    def visible_chapters(self) -> List[Chapter]:
        """Chapters overlapping the selected page range."""
        if not self.detected_chapters:
            return []
        return ChapterDetector.clip_to_range(
            self.detected_chapters,
            self.spn_start_page.value(),
            self.spn_end_page.value(),
        )

    def refresh_chapter_list(self) -> None:
        """Refresh the chapter list widget for the current page range."""
        if not hasattr(self, "lst_chapters"):
            return
        self.lst_chapters.clear()
        visible = self.visible_chapters()
        if visible:
            first = visible[0]
            last = visible[-1]
            self.lbl_chapters.setText(
                f"{len(visible)} archivos · pág. {first.start_page}–{last.end_page}"
            )
            self.lst_chapters.setVisible(True)
            for i, chapter in enumerate(visible, start=1):
                self.lst_chapters.addItem(
                    f"{i:02d}.  {chapter.start_page}–{chapter.end_page}  {chapter.title}"
                )
        elif self.detected_chapters:
            self.lbl_chapters.setText("Ningún capítulo cae en el rango de páginas seleccionado.")
            self.lst_chapters.setVisible(False)
        else:
            self.lbl_chapters.setText(
                "Sin índice estructurado. Si activas capítulos, se buscarán encabezados al convertir."
            )
            self.lst_chapters.setVisible(False)

    def on_omit_symbols_toggled(self, checked: bool) -> None:
        """Persists the omit-symbols preference and refreshes the spoken-text preview."""
        self.settings.setValue("omit_symbols", checked)
        if self.extractor:
            self.refresh_preview()
        self.log_terminal.append_log(
            "Omitir símbolos activado. Elena no pronunciará asteriscos ni barras."
            if checked
            else "Omitir símbolos desactivado. La voz leerá los símbolos del PDF."
        )

    def refresh_preview(self) -> None:
        """Rebuilds the preview using the same cleaning the TTS pipeline will hear."""
        if not self.extractor:
            return
        meta = self.extractor.get_metadata()
        omit = self.chk_omit_symbols.isChecked()
        preview_text = ""
        for i in range(min(meta["page_count"], 2)):
            preview_text += f"--- PÁGINA {i+1} ---\n"
            preview_text += TextCleaner.clean(
                self.extractor.extract_page_text(i),
                omit_symbols=omit,
            ) + "\n\n"
        self.txt_preview.setPlainText(
            preview_text.strip() or "[Sin texto extraíble en las primeras páginas]"
        )

    def populate_voices(self) -> None:
        """Fetches dynamic voice lists depending on TTS selection."""
        self.cmb_voices.clear()
        
        idx = self.cmb_engine.currentIndex()
        if idx == 0:
            engine_name = "edge-tts"
        elif idx == 1:
            engine_name = "google"
        elif idx == 2:
            engine_name = "pyttsx3"
        else:
            engine_name = "gtts"
            
        try:
            tts = get_tts_engine(engine_name)
            voices = tts.get_available_voices()
            for v in voices:
                self.cmb_voices.addItem(v["name"], v["id"])
        except Exception as e:
            logger.error(f"Could not populate voices for {engine_name}: {e}")
            self.cmb_voices.addItem("Sistema (Predeterminado)", "")

    def load_recent_projects(self) -> None:
        """Retrieves and lists historical projects from database."""
        self.projects_list.clear()
        try:
            projects = ProjectManager.list_projects()
            for p in projects:
                name = p["name"]
                status = p["status"]
                date_str = p["created_at"].split("T")[0]
                
                item = QListWidgetItem(f"{name} ({status}) - {date_str}")
                # Store project dictionary in item custom role for easy reloading
                item.setData(Qt.UserRole, p)
                self.projects_list.addItem(item)
        except Exception as e:
            logger.error(f"Failed to load recent projects: {e}")

    @Slot(QListWidgetItem)
    def load_selected_project(self, item: QListWidgetItem) -> None:
        """Reloads a previously registered project status."""
        project = item.data(Qt.UserRole)
        if not project:
            return
            
        pdf_path = project["pdf_path"]
        if not os.path.exists(pdf_path):
            QMessageBox.warning(self, "Archivo no encontrado", f"El archivo original del proyecto no existe:\n{pdf_path}")
            return
            
        self.load_pdf(pdf_path)
        self.batch_queue = []
        self.active_project = project
        self.txt_output_dir.setText(project["output_dir"])
        if "split_by_chapter" in project.keys():
            self.chk_split_chapters.setChecked(bool(project["split_by_chapter"]))
        
        # Select engine matching
        engine_map = {"edge-tts": 0, "google": 1, "google-tts": 1, "google-cloud": 1, "pyttsx3": 2, "gtts": 3}
        self.cmb_engine.setCurrentIndex(engine_map.get(project["engine_type"], 0))
        self.populate_voices()
        
        # Restore progress display
        progress = ProjectManager.get_project_progress(project["id"])
        pct = int(progress["progress_percentage"])
        self.progress_bar.setValue(pct)
        self.lbl_progress_percent.setText(f"{pct}%")
        self.lbl_progress_status.setText(f"Proyecto reanudado ({progress['completed_chunks']}/{progress['total_chunks']} bloques)")
        
        self.log_terminal.append_log(f"Proyecto '{project['name']}' cargado desde la base de datos.")
        
        # Toggle buttons
        if pct < 100:
            self.btn_resume.setEnabled(True)
            self.btn_start.setEnabled(True)
        else:
            self.btn_resume.setEnabled(False)
            self.btn_start.setEnabled(False)

    # ----------------------------------------------------
    # CONVERSION ACTIONS (PAUSE, RESUME, CANCEL)
    # ----------------------------------------------------
    def start_conversion(self) -> None:
        """Prepares pages, chunks text, registers SQLite schema, and launches synthesis worker."""
        if not self.pdf_path or not self.extractor:
            return

        # Read configs
        output_dir = self.txt_output_dir.text().strip()
        if not output_dir or not os.path.exists(output_dir):
            QMessageBox.warning(self, "Carpeta de destino", "Por favor seleccione una carpeta de salida válida.")
            return
        note = destination_note(output_dir)
        if note:
            self.log_terminal.append_log(note)

        start_page = self.spn_start_page.value() - 1 # 0-indexed
        end_page = self.spn_end_page.value() - 1     # 0-indexed
        
        idx = self.cmb_engine.currentIndex()
        engine_type = "edge-tts" if idx == 0 else ("google" if idx == 1 else ("pyttsx3" if idx == 2 else "gtts"))
        voice_id = self.cmb_voices.currentData()
        
        # Parse speed value
        speed_map = {0: 0.5, 1: 0.75, 2: 1.0, 3: 1.25, 4: 1.5, 5: 2.0}
        rate = speed_map.get(self.cmb_speed.currentIndex(), 1.0)
        
        format_ext = self.cmb_format.currentText().lower()
        omit_symbols = self.chk_omit_symbols.isChecked()
        split_by_chapter = self.chk_split_chapters.isChecked()
        pdf_name_noext = os.path.splitext(os.path.basename(self.pdf_path))[0]
        if split_by_chapter:
            output_file = os.path.join(output_dir, f"{pdf_name_noext}_audiolibro")
        else:
            output_file = os.path.join(output_dir, f"{pdf_name_noext}_audiolibro.{format_ext}")

        # Check if project exists already, otherwise create new
        if not self.active_project or self.active_project["pdf_path"] != self.pdf_path:
            self.log_terminal.append_log("Extrayendo páginas y agrupando texto en bloques seguros...")
            
            try:
                pages_data = []
                for i in range(start_page, end_page + 1):
                    text = self.extractor.extract_page_text(i)
                    pages_data.append({"page_num": i, "raw_text": text})

                chapters_for_split: List[Chapter] = []
                if split_by_chapter:
                    chapters_for_split = self.visible_chapters()
                    if len(chapters_for_split) < 2:
                        heuristic = ChapterDetector(
                            pdf_path=self.pdf_path,
                            page_texts=[
                                {"page_num": p["page_num"], "text": p["raw_text"]}
                                for p in pages_data
                            ],
                            total_pages=end_page + 1,
                        ).detect()
                        chapters_for_split = ChapterDetector.clip_to_range(
                            heuristic, start_page + 1, end_page + 1
                        )
                        if len(chapters_for_split) < 2 or (
                            len(chapters_for_split) == 1
                            and chapters_for_split[0].title == "Full Document"
                        ):
                            split_by_chapter = False
                            chapters_for_split = []
                            output_file = os.path.join(
                                output_dir, f"{pdf_name_noext}_audiolibro.{format_ext}"
                            )
                            self.log_terminal.append_log(
                                "No se encontraron capítulos. Se exportará un único archivo."
                            )

                if split_by_chapter and chapters_for_split:
                    self.chunks = []
                    chunk_idx = 0
                    for chapter_i, chapter in enumerate(chapters_for_split):
                        slice_pages = [
                            p for p in pages_data
                            if chapter.start_page <= p["page_num"] + 1 <= (chapter.end_page or end_page + 1)
                        ]
                        chapter_chunks = TextChunker.chunk_pages(
                            slice_pages, max_chars=1800, omit_symbols=omit_symbols
                        )
                        if not chapter_chunks:
                            self.log_terminal.append_log(
                                f"Sin texto sintetizable en «{chapter.title}»; se omite."
                            )
                            continue
                        for chunk in chapter_chunks:
                            chunk["chunk_index"] = chunk_idx
                            chunk["chapter_index"] = chapter_i
                            chunk["chapter_title"] = chapter.title
                            self.chunks.append(chunk)
                            chunk_idx += 1
                    self.log_terminal.append_log(
                        f"Texto agrupado en {len(chapters_for_split)} capítulos "
                        f"({len(self.chunks)} bloques)."
                    )
                else:
                    self.chunks = TextChunker.chunk_pages(
                        pages_data, max_chars=1800, omit_symbols=omit_symbols
                    )
                if omit_symbols:
                    self.log_terminal.append_log(
                        "Símbolos omitidos en el texto: Elena no pronunciará asterisco, barra ni almohadilla."
                    )
                
                if not self.chunks:
                    QMessageBox.warning(self, "Sin texto", "El rango seleccionado no contiene ningún texto para sintetizar.")
                    return

                # Register Project in SQLite
                proj_name = f"Audiolibro_{pdf_name_noext}"
                self.active_project = ProjectManager.create_project(
                    name=proj_name,
                    pdf_path=self.pdf_path,
                    output_dir=output_dir,
                    engine_type=engine_type,
                    voice_id=str(voice_id),
                    rate=rate,
                    format_ext=format_ext,
                    split_by_chapter=split_by_chapter,
                )
                
                # Add chunks to DB
                ProjectManager.add_chunks(self.active_project["id"], self.chunks)
                
            except Exception as e:
                logger.error(f"Project creation failed: {e}")
                QMessageBox.critical(self, "Error de inicialización", f"Error al preparar el proyecto:\n{e}")
                return

        # Start Thread
        self.btn_start.setEnabled(False)
        self.btn_pause.setEnabled(True)
        self.btn_resume.setEnabled(False)
        self.btn_cancel.setEnabled(True)
        self.cmb_engine.setEnabled(False)
        self.cmb_voices.setEnabled(False)
        self.cmb_format.setEnabled(False)
        self.cmb_speed.setEnabled(False)
        self.chk_omit_symbols.setEnabled(False)
        self.chk_split_chapters.setEnabled(False)
        self.spn_start_page.setEnabled(False)
        self.spn_end_page.setEnabled(False)
        
        self.worker = ConversionWorker(
            project_id=self.active_project["id"],
            engine_type=engine_type,
            voice_id=str(voice_id),
            rate=rate,
            format_ext=format_ext,
            output_file=output_file,
            omit_symbols=omit_symbols,
            split_by_chapter=split_by_chapter,
        )
        
        # Connect signals
        self.worker.progress_changed.connect(self.on_progress_changed)
        self.worker.status_changed.connect(self.on_status_changed)
        self.worker.chunk_completed.connect(self.on_chunk_completed)
        self.worker.error_occurred.connect(self.on_chunk_error)
        self.worker.finished.connect(self.on_conversion_finished)
        
        self.worker.start()

    def pause_conversion(self) -> None:
        """Requests background worker pause."""
        if self.worker:
            self.worker.pause()
            self.btn_pause.setEnabled(False)
            self.btn_resume.setEnabled(True)

    def resume_conversion(self) -> None:
        """Requests background worker resume."""
        if self.worker:
            self.worker.resume()
            self.btn_pause.setEnabled(True)
            self.btn_resume.setEnabled(False)

    def cancel_conversion(self) -> None:
        """Presents cancellation warning dialog and halts execution."""
        reply = QMessageBox.question(
            self, 
            "Cancelar conversión",
            "¿Está seguro de que desea detener y cancelar el proceso de conversión actual?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes and self.worker:
            self.worker.cancel()
            self.btn_pause.setEnabled(False)
            self.btn_resume.setEnabled(False)
            self.btn_cancel.setEnabled(False)

    def open_output_folder(self) -> None:
        """Opens standard OS file browser at the destination folder."""
        out_dir = self.txt_output_dir.text().strip()
        if out_dir and os.path.exists(out_dir):
            if sys.platform == "win32":
                os.startfile(out_dir)
            elif sys.platform == "darwin":
                import subprocess
                subprocess.Popen(["open", out_dir])
            else:
                import subprocess
                subprocess.Popen(["xdg-open", out_dir])

    def clear_temp_cache(self) -> None:
        """Safe execution trigger to clear out disk cached chunks."""
        n = cached_audio_count()
        if n > 0:
            reply = QMessageBox.question(
                self,
                "¿Borrar la caché de audio?",
                (
                    f"Hay {n} archivos de audio en la caché. "
                    "Si un libro largo falló al copiarse al USB, esos bloques SON el trabajo de todo el día. "
                    "Borrarlos obliga a sintetizar otra vez.\n\n¿Borrar de todos modos?"
                ),
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No,
            )
            if reply != QMessageBox.Yes:
                return
        clean_temp_dir()
        self.log_terminal.append_log("La caché de bloques de audio temporales ha sido limpiada.")
        QMessageBox.information(self, "Limpieza de Caché", "La carpeta de caché temporal ha sido limpiada exitosamente.")

    # ----------------------------------------------------
    # WORKER SIGNAL CALLBACKS
    # ----------------------------------------------------
    @Slot(int)
    def on_progress_changed(self, value: int) -> None:
        """Updates progress bars and percentages."""
        self.progress_bar.setValue(value)
        self.lbl_progress_percent.setText(f"{value}%")

    @Slot(str)
    def on_status_changed(self, status: str) -> None:
        """Updates display status text and prints to log view."""
        self.lbl_progress_status.setText(status)
        self.log_terminal.append_log(status)

    @Slot(int, str)
    def on_chunk_completed(self, chunk_index: int, audio_path: str) -> None:
        """Logs completed single chunk files."""
        self.log_terminal.append_log(f"Bloque {chunk_index + 1} sintetizado y guardado con éxito.")

    @Slot(str, str)
    def on_chunk_error(self, source: str, error_msg: str) -> None:
        """Logs chunk-specific synthesis failures."""
        self.log_terminal.append_log(f"⚠️ ERROR en {source}: {error_msg}")

    @Slot(bool, str)
    def on_conversion_finished(self, success: bool, result_msg: str) -> None:
        """Re-enables GUI controls and showcases conversion summaries."""
        self.btn_start.setEnabled(True)
        self.btn_pause.setEnabled(False)
        self.btn_resume.setEnabled(False)
        self.btn_cancel.setEnabled(False)
        
        self.cmb_engine.setEnabled(True)
        self.cmb_voices.setEnabled(True)
        self.cmb_format.setEnabled(True)
        self.cmb_speed.setEnabled(True)
        self.chk_omit_symbols.setEnabled(True)
        self.chk_split_chapters.setEnabled(True)
        self.spn_start_page.setEnabled(True)
        self.spn_end_page.setEnabled(True)
        
        if success:
            self.progress_bar.setValue(100)
            self.lbl_progress_percent.setText("100%")
            self.log_terminal.append_log("Proceso finalizado para este documento. Todo el audio ha sido ensamblado.")
            self.active_project = None
            
            if self.batch_queue:
                next_pdf = self.batch_queue.pop(0)
                self.log_terminal.append_log(f"Iniciando el siguiente documento en la cola: {os.path.basename(next_pdf)}")
                self.load_pdf(next_pdf)
                from PySide6.QtCore import QTimer
                QTimer.singleShot(500, self.start_conversion)
            else:
                QMessageBox.information(self, "Conversión Completada", result_msg)
        else:
            QMessageBox.warning(self, "Conversión Incompleta", f"El proceso terminó con advertencias o fallos:\n{result_msg}")
            self.log_terminal.append_log(f"Proceso detenido: {result_msg}")
            self.log_terminal.append_log(
                "El proyecto sigue cargado. Pulsa Iniciar para reanudar; no borres la caché."
            )
            
        self.load_recent_projects()
        self.worker = None
        
    def closeEvent(self, event) -> None:
        """Intercepts window close to safely shut down running worker threads."""
        if self.worker and self.worker.isRunning():
            reply = QMessageBox.question(
                self, 
                "Cerrar Aplicación",
                "Hay una conversión en curso en segundo plano. ¿Desea cancelarla y cerrar la aplicación?",
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No
            )
            if reply == QMessageBox.Yes:
                self.worker.cancel()
                self.worker.wait()
                event.accept()
            else:
                event.ignore()
        else:
            event.accept()
