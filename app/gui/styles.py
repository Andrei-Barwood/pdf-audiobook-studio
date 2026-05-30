# Custom QSS Stylesheet for PDF Audiobook Studio

DARK_THEME_QSS = """
/* Dark Theme variables */
QMainWindow {
    background-color: #0F172A;
}

QWidget {
    font-family: "Segoe UI", "SF Pro Text", "Outfit", "Inter", sans-serif;
    font-size: 13px;
    color: #F8FAFC;
}

QLabel {
    color: #E2E8F0;
}

QLabel#titleLabel {
    font-size: 20px;
    font-weight: bold;
    color: #FFFFFF;
}

QLabel#sectionTitle {
    font-size: 14px;
    font-weight: bold;
    color: #818CF8;
}

QFrame#cardFrame {
    background-color: #1E293B;
    border: 1px solid #334155;
    border-radius: 8px;
}

/* ScrollBars styling */
QScrollBar:vertical {
    border: none;
    background: #0F172A;
    width: 8px;
    margin: 0px;
    border-radius: 4px;
}

QScrollBar::handle:vertical {
    background: #475569;
    min-height: 20px;
    border-radius: 4px;
}

QScrollBar::handle:vertical:hover {
    background: #6366F1;
}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
    border: none;
    background: none;
    height: 0px;
}

QScrollBar:horizontal {
    border: none;
    background: #0F172A;
    height: 8px;
    margin: 0px;
    border-radius: 4px;
}

QScrollBar::handle:horizontal {
    background: #475569;
    min-width: 20px;
    border-radius: 4px;
}

QScrollBar::handle:horizontal:hover {
    background: #6366F1;
}

QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
    border: none;
    background: none;
    width: 0px;
}

/* Drag and Drop Zone */
QFrame#dropZone {
    background-color: #1E293B;
    border: 2px dashed #4F46E5;
    border-radius: 10px;
}

QFrame#dropZone:hover {
    background-color: #312E81;
    border: 2px dashed #818CF8;
}

/* Inputs and Selectors */
QLineEdit, QComboBox, QSpinBox {
    background-color: #0F172A;
    border: 1px solid #475569;
    border-radius: 6px;
    padding: 6px 10px;
    color: #F8FAFC;
}

QLineEdit:focus, QComboBox:focus, QSpinBox:focus {
    border: 1px solid #6366F1;
}

QComboBox::drop-down {
    subcontrol-origin: padding;
    subcontrol-position: top right;
    width: 25px;
    border-left-width: 0px;
    border-top-right-radius: 6px;
    border-bottom-right-radius: 6px;
}

QComboBox QAbstractItemView {
    background-color: #1E293B;
    border: 1px solid #334155;
    selection-background-color: #4F46E5;
    selection-color: #FFFFFF;
}

/* Buttons styling */
QPushButton {
    background-color: #334155;
    border: 1px solid #475569;
    border-radius: 6px;
    padding: 8px 16px;
    font-weight: 500;
    color: #F8FAFC;
}

QPushButton:hover {
    background-color: #475569;
}

QPushButton:pressed {
    background-color: #1E293B;
}

QPushButton#primaryButton {
    background-color: #4F46E5;
    border: 1px solid #6366F1;
    color: #FFFFFF;
    font-weight: 600;
}

QPushButton#primaryButton:hover {
    background-color: #6366F1;
}

QPushButton#primaryButton:pressed {
    background-color: #3730A3;
}

QPushButton#dangerButton {
    background-color: #991B1B;
    border: 1px solid #B91C1C;
    color: #FFFFFF;
}

QPushButton#dangerButton:hover {
    background-color: #DC2626;
}

QPushButton#dangerButton:pressed {
    background-color: #7F1D1D;
}

QPushButton#textButton {
    background: transparent;
    border: none;
    color: #818CF8;
    text-decoration: underline;
    padding: 4px;
}

QPushButton#textButton:hover {
    color: #A5B4FC;
}

/* Progress Bar styling */
QProgressBar {
    background-color: #0F172A;
    border: 1px solid #334155;
    border-radius: 6px;
    text-align: center;
    font-weight: bold;
    height: 16px;
}

QProgressBar::chunk {
    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                      stop:0 #4F46E5, stop:1 #818CF8);
    border-radius: 5px;
}

/* Text Previews and Logs */
QPlainTextEdit {
    background-color: #0F172A;
    border: 1px solid #334155;
    border-radius: 8px;
    padding: 10px;
    font-family: "Courier New", monospace;
    font-size: 12px;
    color: #E2E8F0;
}
"""

LIGHT_THEME_QSS = """
/* Light Theme variables */
QMainWindow {
    background-color: #F8FAFC;
}

QWidget {
    font-family: "Segoe UI", "SF Pro Text", "Outfit", "Inter", sans-serif;
    font-size: 13px;
    color: #0F172A;
}

QLabel {
    color: #1E293B;
}

QLabel#titleLabel {
    font-size: 20px;
    font-weight: bold;
    color: #0F172A;
}

QLabel#sectionTitle {
    font-size: 14px;
    font-weight: bold;
    color: #4F46E5;
}

QFrame#cardFrame {
    background-color: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 8px;
}

/* ScrollBars styling */
QScrollBar:vertical {
    border: none;
    background: #F1F5F9;
    width: 8px;
    margin: 0px;
    border-radius: 4px;
}

QScrollBar::handle:vertical {
    background: #CBD5E1;
    min-height: 20px;
    border-radius: 4px;
}

QScrollBar::handle:vertical:hover {
    background: #6366F1;
}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
    border: none;
    background: none;
    height: 0px;
}

QScrollBar:horizontal {
    border: none;
    background: #F1F5F9;
    height: 8px;
    margin: 0px;
    border-radius: 4px;
}

QScrollBar::handle:horizontal {
    background: #CBD5E1;
    min-width: 20px;
    border-radius: 4px;
}

QScrollBar::handle:horizontal:hover {
    background: #6366F1;
}

QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
    border: none;
    background: none;
    width: 0px;
}

/* Drag and Drop Zone */
QFrame#dropZone {
    background-color: #FFFFFF;
    border: 2px dashed #4F46E5;
    border-radius: 10px;
}

QFrame#dropZone:hover {
    background-color: #EEF2F6;
    border: 2px dashed #6366F1;
}

/* Inputs and Selectors */
QLineEdit, QComboBox, QSpinBox {
    background-color: #FFFFFF;
    border: 1px solid #CBD5E1;
    border-radius: 6px;
    padding: 6px 10px;
    color: #0F172A;
}

QLineEdit:focus, QComboBox:focus, QSpinBox:focus {
    border: 1px solid #4F46E5;
}

QComboBox::drop-down {
    subcontrol-origin: padding;
    subcontrol-position: top right;
    width: 25px;
    border-left-width: 0px;
    border-top-right-radius: 6px;
    border-bottom-right-radius: 6px;
}

QComboBox QAbstractItemView {
    background-color: #FFFFFF;
    border: 1px solid #E2E8F0;
    selection-background-color: #4F46E5;
    selection-color: #FFFFFF;
}

/* Buttons styling */
QPushButton {
    background-color: #E2E8F0;
    border: 1px solid #CBD5E1;
    border-radius: 6px;
    padding: 8px 16px;
    font-weight: 500;
    color: #0F172A;
}

QPushButton:hover {
    background-color: #CBD5E1;
}

QPushButton:pressed {
    background-color: #E2E8F0;
}

QPushButton#primaryButton {
    background-color: #4F46E5;
    border: 1px solid #4F46E5;
    color: #FFFFFF;
    font-weight: 600;
}

QPushButton#primaryButton:hover {
    background-color: #6366F1;
}

QPushButton#primaryButton:pressed {
    background-color: #3730A3;
}

QPushButton#dangerButton {
    background-color: #DC2626;
    border: 1px solid #DC2626;
    color: #FFFFFF;
}

QPushButton#dangerButton:hover {
    background-color: #EF4444;
}

QPushButton#dangerButton:pressed {
    background-color: #991B1B;
}

QPushButton#textButton {
    background: transparent;
    border: none;
    color: #4F46E5;
    text-decoration: underline;
    padding: 4px;
}

QPushButton#textButton:hover {
    color: #6366F1;
}

/* Progress Bar styling */
QProgressBar {
    background-color: #E2E8F0;
    border: 1px solid #CBD5E1;
    border-radius: 6px;
    text-align: center;
    font-weight: bold;
    height: 16px;
}

QProgressBar::chunk {
    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                      stop:0 #4F46E5, stop:1 #818CF8);
    border-radius: 5px;
}

/* Text Previews and Logs */
QPlainTextEdit {
    background-color: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 8px;
    padding: 10px;
    font-family: "Courier New", monospace;
    font-size: 12px;
    color: #0F172A;
}
"""
