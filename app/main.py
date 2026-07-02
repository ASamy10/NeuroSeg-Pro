import sys
import os
import ctypes
import traceback

# Dynamically add the project root to sys.path so 'app.' imports work without PYTHONPATH
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Fix for OMP: Error #15 (Multiple OpenMP runtimes)
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

# Suppress TensorFlow oneDNN logs
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

def show_startup_error(error_msg):
    log_dir = os.path.expanduser("~\\AppData\\Local\\NeuroSegPro\\logs")
    os.makedirs(log_dir, exist_ok=True)
    crash_file = os.path.join(log_dir, "app_crash.log")
    try:
        with open(crash_file, "w", encoding="utf-8") as f:
            f.write("NeuroSeg Pro Fatal Startup Error Traceback:\n" + "="*60 + "\n" + error_msg)
    except Exception:
        pass
    if os.name == 'nt':
        ctypes.windll.user32.MessageBoxW(0, 
            f"NeuroSeg Pro encountered a startup error:\n\n{error_msg[:600]}\n\nFull crash log saved to:\n{crash_file}\n\nPlease run the Repair Tool from your Start Menu.",
            "NeuroSeg Pro Startup Error", 0x10)
    else:
        print(error_msg, file=sys.stderr)

try:
    from PyQt5.QtWidgets import QApplication, QMainWindow
    from PyQt5.QtCore import Qt
    from PyQt5.QtGui import QIcon
    from app.version import __version__
    from app.core.first_launch import initialize_application_environment
except Exception:
    show_startup_error(traceback.format_exc())
    sys.exit(1)

def main():
    try:
        # Execute first-launch verification, directory setup, and migration
        initialize_application_environment()

        # --- High-DPI Scaling (MUST be before QApplication) ---
        QApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
        QApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)

        # Fix for Windows Taskbar Icon
        if os.name == 'nt':
            myappid = f'gradproject.neuroseg.pro.v{__version__}'
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)

        app = QApplication(sys.argv)
        app.setApplicationName("Brain Tumor Segmentation Pro")
        app.setOrganizationName("GraduationProject")
        app.setWindowIcon(QIcon("assets/NeuroSeg_App_Icon.png"))
        
        # Compute DPI scale factor and store it for the whole app
        screen = app.primaryScreen()
        logical_dpi = screen.logicalDotsPerInch() if screen else 96.0
        dpi_scale = max(logical_dpi / 96.0, 1.0)  # 1.0 for 96 DPI, 1.5 for 144, 2.0 for 192
        
        # Apply Rich Theme with DPI scaling
        from app.ui.theme import apply_theme
        apply_theme(app, dpi_scale=dpi_scale)
        
        from app.ui.main_window import MainWindow
        window = MainWindow()
        window.show()
        
        sys.exit(app.exec_())
    except Exception:
        show_startup_error(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    main()
