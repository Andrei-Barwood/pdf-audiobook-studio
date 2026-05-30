import os
import logging
from logging.handlers import RotatingFileHandler

def setup_logger(log_name: str = "pdf_audiobook_studio", log_level: int = logging.INFO) -> logging.Logger:
    """Sets up a rotating file logger and console logger."""
    logger = logging.getLogger(log_name)
    logger.setLevel(log_level)
    
    # If handlers already configured, do not add them again
    if logger.handlers:
        return logger
        
    formatter = logging.Formatter(
        "[%(asctime)s] %(levelname)s [%(name)s.%(funcName)s:%(lineno)d] - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # Console Handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # File Handler - Saved in the user's home folder or local scratch
    try:
        log_dir = os.path.expanduser("~/.pdf_audiobook_studio/logs")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "app.log")
        
        file_handler = RotatingFileHandler(log_file, maxBytes=5*1024*1024, backupCount=3, encoding="utf-8")
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    except Exception as e:
        # Fallback to current folder if home directory is not writable
        try:
            os.makedirs("logs", exist_ok=True)
            file_handler = RotatingFileHandler("logs/app.log", maxBytes=5*1024*1024, backupCount=3, encoding="utf-8")
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
        except Exception:
            # If we cannot create logs directory anywhere, rely only on console
            pass
            
    return logger

# Shared global logger
logger = setup_logger()
