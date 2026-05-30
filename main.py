import sys
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt
from app.gui.main_window import MainWindow
from app.utils.logger import logger

def main():
    # 1. Enable modern High-DPI scaling features for Retina and 4K screens
    # (Attributes set before QApplication instantiation)
    QApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )
    
    app = QApplication(sys.argv)
    app.setApplicationName("PDF Audiobook Studio")
    app.setApplicationVersion("1.0.0")
    
    logger.info("Starting QApplication...")
    
    try:
        window = MainWindow()
        window.show()
        sys.exit(app.exec())
    except Exception as e:
        logger.critical(f"Unhandled exception during app execution: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
