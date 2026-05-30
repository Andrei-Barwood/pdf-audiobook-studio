import os
from PySide6.QtWidgets import QFrame, QVBoxLayout, QLabel, QPlainTextEdit
from PySide6.QtCore import Signal, Qt, QMimeData
from PySide6.QtGui import QDragEnterEvent, QDropEvent

class CardFrame(QFrame):
    """A customized container frame that provides a premium card look with clean borders."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("cardFrame")
        
        # Set card shadow or extra styling if needed
        # (This is automatically integrated via our central QSS)


class DragDropFrame(QFrame):
    """A specialized frame that acts as a modern drag-and-drop zone for PDF files."""
    file_dropped = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("dropZone")
        self.setAcceptDrops(True)
        self.setMinimumHeight(120)
        
        # Internal layout
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignCenter)
        
        self.icon_label = QLabel("📥", self)
        self.icon_label.setStyleSheet("font-size: 32px;")
        self.icon_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.icon_label)
        
        self.text_label = QLabel("Arrastra y suelta tu archivo PDF aquí\no haz clic para seleccionar uno", self)
        self.text_label.setAlignment(Qt.AlignCenter)
        self.text_label.setStyleSheet("font-weight: 500; color: #94A3B8; font-size: 13px;")
        layout.addWidget(self.text_label)

    def dragEnterEvent(self, event: QDragEnterEvent) -> None:
        """Fired when dragging files over the frame."""
        if event.mimeData().hasUrls():
            urls = event.mimeData().urls()
            # Verify if there is at least one PDF
            if any(url.toLocalFile().lower().endswith(".pdf") for url in urls):
                event.acceptProposedAction()
                self.setStyleSheet("background-color: #312E81; border-color: #818CF8;")
                return
        event.ignore()

    def dragLeaveEvent(self, event) -> None:
        """Restores styles when drag leaves the frame area."""
        self.setStyleSheet("")
        event.accept()

    def dropEvent(self, event: QDropEvent) -> None:
        """Extracts the dropped file path and emits signal."""
        self.setStyleSheet("")
        urls = event.mimeData().urls()
        for url in urls:
            filepath = url.toLocalFile()
            if filepath.lower().endswith(".pdf"):
                event.acceptProposedAction()
                self.file_dropped.emit(filepath)
                return
        event.ignore()

    def mousePressEvent(self, event) -> None:
        """Trigger native dialog click if clicking inside drag zone."""
        if event.button() == Qt.LeftButton:
            # Emit standard signal to parent or trigger open action
            # We can handle this by delegating mousePress to standard clicked action
            # by forwarding to parent's file open trigger
            parent = self.parentWidget()
            if parent and hasattr(parent, "trigger_file_dialog"):
                parent.trigger_file_dialog()
            super().mousePressEvent(event)


class LogTerminal(QPlainTextEdit):
    """Custom stylized log console text viewer."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setReadOnly(True)
        self.setPlaceholderText("Registro del sistema... Los eventos importantes se mostrarán aquí.")
        self.setMaximumHeight(150)

    def append_log(self, message: str) -> None:
        """Appends a timestamped log to the text area and auto-scrolls to the bottom."""
        import datetime
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        self.appendPlainText(f"[{timestamp}] {message}")
        
        # Keep auto-scroll active
        self.verticalScrollBar().setValue(self.verticalScrollBar().maximum())
