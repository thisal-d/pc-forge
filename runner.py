#!/usr/bin/env python3
"""
PCForge Development Multi-Service Runner
========================================
Runs ASP.NET Core Backend, React/Vite Web, and Flutter Mobile concurrently.
Provides auto-reload on file change, keyboard shortcuts (r/R/b/w/m/q),
colored log streams, and clean process termination on Windows.

Usage:
    python runner.py
    python runner.py --no-mobile
    python runner.py --only backend,web
    python runner.py --device emulator-5554
"""

import os
import sys
import time
import json
import shutil
import signal
import threading
import subprocess
from pathlib import Path
from typing import Dict, List, Optional

# Enable VT100 ANSI escape codes on Windows console
def enable_windows_ansi():
    if sys.platform == "win32":
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
            mode = ctypes.c_ulong()
            if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                kernel32.SetConsoleMode(handle, mode.value | 0x0004)  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
        except Exception:
            os.system("")

enable_windows_ansi()

# Reconfigure stdout/stderr to UTF-8 on Windows
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Color Codes
RESET = "\033[0m"
BOLD = "\033[1m"
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
MAGENTA = "\033[95m"
CYAN = "\033[96m"
WHITE = "\033[97m"
GRAY = "\033[90m"

PRINT_LOCK = threading.Lock()

def log(tag: str, color: str, message: str):
    """Thread-safe tagged logging with Unicode encoding fallback."""
    with PRINT_LOCK:
        line = f"{color}{BOLD}[{tag:<8}]{RESET} {message}"
        try:
            print(line, flush=True)
        except UnicodeEncodeError:
            enc = getattr(sys.stdout, "encoding", None) or "ascii"
            safe_line = line.encode(enc, errors="replace").decode(enc)
            print(safe_line, flush=True)

def kill_process_tree(pid: int):
    """Forcefully kill process and all descendants to prevent orphaned ports."""
    if not pid:
        return
    if sys.platform == "win32":
        try:
            subprocess.run(
                ["taskkill", "/F", "/T", "/PID", str(pid)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False
            )
        except Exception:
            pass
    else:
        try:
            import signal
            os.killpg(os.getpgid(pid), signal.SIGKILL)
        except Exception:
            pass

class Service:
    """Manages the lifecycle and I/O of a background service."""
    def __init__(
        self,
        name: str,
        tag: str,
        color: str,
        cwd: Path,
        cmd: List[str],
        env: Optional[Dict[str, str]] = None,
        supports_stdin: bool = False
    ):
        self.name = name
        self.tag = tag
        self.color = color
        self.cwd = cwd
        self.cmd = cmd
        self.env = {**os.environ, **(env or {})}
        self.supports_stdin = supports_stdin
        self.process: Optional[subprocess.Popen] = None
        self.reader_thread: Optional[threading.Thread] = None
        self.is_running = False
        self._lock = threading.Lock()

    def start(self):
        with self._lock:
            if self.is_running and self.process and self.process.poll() is None:
                return

            log(self.tag, self.color, f"Starting {self.name} in {self.cwd.name}/...")
            try:
                self.process = subprocess.Popen(
                    self.cmd,
                    cwd=str(self.cwd),
                    env=self.env,
                    stdin=subprocess.PIPE if self.supports_stdin else subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    encoding="utf-8",
                    errors="replace"
                )
                self.is_running = True
            except Exception as e:
                log(self.tag, RED, f"Failed to start {self.name}: {e}")
                self.is_running = False
                return

            self.reader_thread = threading.Thread(
                target=self._stream_output,
                daemon=True,
                name=f"{self.name}-OutputReader"
            )
            self.reader_thread.start()

    def _stream_output(self):
        proc = self.process
        if not proc or not proc.stdout:
            return

        while self.is_running:
            line = proc.stdout.readline()
            if not line:
                if proc.poll() is not None:
                    break
                time.sleep(0.05)
                continue

            cleaned = line.rstrip("\r\n")
            if cleaned.strip():
                log(self.tag, self.color, cleaned)

        exit_code = proc.poll()
        if self.is_running:
            self.is_running = False
            log(self.tag, YELLOW, f"{self.name} process exited (code {exit_code}).")

    def send_stdin(self, text: str):
        """Sends input line to process stdin (e.g. 'r\\n' for Flutter reload)."""
        with self._lock:
            if self.process and self.process.stdin and self.process.poll() is None:
                try:
                    self.process.stdin.write(text)
                    self.process.stdin.flush()
                    return True
                except Exception as e:
                    log(self.tag, RED, f"Failed sending stdin to {self.name}: {e}")
            return False

    def stop(self):
        with self._lock:
            self.is_running = False
            if self.process:
                pid = self.process.pid
                kill_process_tree(pid)
                try:
                    self.process.wait(timeout=2)
                except Exception:
                    pass
                self.process = None

    def restart(self):
        log(self.tag, YELLOW, f"Restarting {self.name}...")
        self.stop()
        time.sleep(0.5)
        self.start()

class FileWatcher:
    """Zero-dependency background file watcher with debouncing."""
    def __init__(self, root_dir: Path, debounce_sec: float = 0.5):
        self.root_dir = root_dir
        self.debounce_sec = debounce_sec
        self.callbacks = []
        self.file_mtimes: Dict[str, float] = {}
        self.running = False
        self.thread: Optional[threading.Thread] = None

    def add_watch(self, directory: Path, extensions: List[str], ignored_dirs: List[str], callback):
        self.callbacks.append({
            "dir": directory,
            "exts": set(ext.lower() for ext in extensions),
            "ignored": set(ignored_dirs),
            "callback": callback,
            "last_trigger": 0.0,
            "pending_file": None
        })

    def start(self):
        self._scan_all(initial=True)
        self.running = True
        self.thread = threading.Thread(target=self._watch_loop, daemon=True, name="FileWatcher")
        self.thread.start()

    def stop(self):
        self.running = False

    def _scan_all(self, initial: bool = False):
        now = time.time()
        for watch in self.callbacks:
            watch_dir = watch["dir"]
            if not watch_dir.exists():
                continue

            for root, dirs, files in os.walk(watch_dir):
                dirs[:] = [d for d in dirs if d not in watch["ignored"] and not d.startswith(".")]

                for f in files:
                    ext = Path(f).suffix.lower()
                    if ext in watch["exts"] or f in watch["exts"]:
                        full_path = os.path.join(root, f)
                        try:
                            mtime = os.stat(full_path).st_mtime
                        except OSError:
                            continue

                        prev_mtime = self.file_mtimes.get(full_path)
                        self.file_mtimes[full_path] = mtime

                        if not initial and prev_mtime is not None and mtime > prev_mtime:
                            watch["pending_file"] = full_path
                            watch["last_trigger"] = now

    def _watch_loop(self):
        while self.running:
            time.sleep(0.4)
            self._scan_all(initial=False)

            now = time.time()
            for watch in self.callbacks:
                if watch["pending_file"] and (now - watch["last_trigger"]) >= self.debounce_sec:
                    changed_file = watch["pending_file"]
                    watch["pending_file"] = None
                    try:
                        watch["callback"](changed_file)
                    except Exception as e:
                        log("WATCHER", RED, f"Error in watch callback: {e}")

def detect_flutter_device() -> Optional[str]:
    """Detects available Flutter device (prefers running mobile emulator/device)."""
    flutter_bin = shutil.which("flutter") or "flutter"
    try:
        res = subprocess.run(
            [flutter_bin, "devices", "--machine"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=8,
            check=False
        )
        if res.returncode == 0 and res.stdout.strip():
            devices = json.loads(res.stdout)
            # 1. Prefer running emulator
            for d in devices:
                if d.get("isSupported") and d.get("emulator"):
                    return d.get("id")
            # 2. Prefer Android / iOS physical mobile
            for d in devices:
                if d.get("isSupported") and d.get("targetPlatform") in ("android-arm64", "android-x64", "ios"):
                    return d.get("id")
            # 3. Desktop windows
            for d in devices:
                if d.get("isSupported") and d.get("id") == "windows":
                    return "windows"
            # 4. Any supported device
            for d in devices:
                if d.get("isSupported"):
                    return d.get("id")
    except Exception:
        pass
    return None

def setup_adb_reverse(port: int = 5000, device: Optional[str] = None):
    """Configures adb reverse tcp:port tcp:port so Android devices can reach host localhost."""
    adb_bin = shutil.which("adb") or "adb"
    try:
        check = subprocess.run(
            [adb_bin, "version"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False
        )
        if check.returncode != 0:
            return

        cmd = [adb_bin]
        if device and not device.startswith("windows"):
            cmd.extend(["-s", device])
        cmd.extend(["reverse", f"tcp:{port}", f"tcp:{port}"])

        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=5,
            check=False
        )
        if res.returncode == 0:
            log("ADB", GREEN, f"Reverse tunnel established: device localhost:{port} -> host port {port}")
    except Exception:
        pass

class RunnerOrchestrator:
    def __init__(
        self,
        root_dir: Path,
        run_backend: bool = True,
        run_web: bool = True,
        run_mobile: bool = True,
        run_ai: bool = True,
        flutter_device: Optional[str] = None,
        backend_mode: str = "watch"
    ):
        self.root_dir = root_dir
        self.run_backend = run_backend
        self.run_web = run_web
        self.run_mobile = run_mobile
        self.run_ai = run_ai
        self.flutter_device = flutter_device
        self.backend_mode = backend_mode
        self.running = False

        self.services: Dict[str, Service] = {}
        self.watcher = FileWatcher(root_dir)

        self._setup_services()
        self._setup_watcher()

    def _setup_services(self):
        # 0. Agentic AI Service (FastAPI)
        if self.run_ai:
            python_bin = sys.executable or "python"
            self.services["ai"] = Service(
                name="AI Agent Service (FastAPI)",
                tag="AGENT_AI",
                color=BLUE,
                cwd=self.root_dir / "ai_service",
                cmd=[python_bin, "-m", "uvicorn", "main:app", "--port", "5050", "--reload"],
                env={"PYTHONPATH": f"{self.root_dir / 'ai_service'}{os.pathsep}{self.root_dir}"},
                supports_stdin=False
            )

        # 1. Backend Service
        if self.run_backend:
            dotnet_bin = shutil.which("dotnet") or "dotnet"
            if self.backend_mode == "watch":
                backend_cmd = [
                    dotnet_bin, "watch", "run",
                    "--non-interactive",
                    "--no-launch-profile"
                ]
            else:
                backend_cmd = [dotnet_bin, "run", "--no-launch-profile"]

            backend_env = {
                "ASPNETCORE_ENVIRONMENT": "Development",
                "DOTNET_ENVIRONMENT": "Development"
            }

            self.services["backend"] = Service(
                name="Backend API (.NET 8)",
                tag="BACKEND",
                color=MAGENTA,
                cwd=self.root_dir / "backend",
                cmd=backend_cmd,
                env=backend_env,
                supports_stdin=False
            )

        # 2. Web Service
        if self.run_web:
            npm_bin = shutil.which("npm") or "npm"
            if sys.platform == "win32" and not npm_bin.lower().endswith((".cmd", ".bat", ".exe")):
                npm_bin = "npm.cmd"

            self.services["web"] = Service(
                name="Frontend Web (React/Vite)",
                tag="WEB",
                color=CYAN,
                cwd=self.root_dir / "web",
                cmd=[npm_bin, "run", "dev"],
                supports_stdin=False
            )

        # 3. Mobile Service (Flutter)
        if self.run_mobile:
            flutter_bin = shutil.which("flutter") or "flutter"
            if sys.platform == "win32" and not flutter_bin.lower().endswith((".bat", ".exe")):
                flutter_bin = "flutter.bat"

            device = self.flutter_device or detect_flutter_device()
            self.flutter_device = device

            mobile_cmd = [flutter_bin, "run"]
            if device:
                mobile_cmd.extend(["-d", device])

            self.services["mobile"] = Service(
                name=f"Mobile Client (Flutter {f'[{device}]' if device else ''})",
                tag="MOBILE",
                color=GREEN,
                cwd=self.root_dir / "app",
                cmd=mobile_cmd,
                supports_stdin=True
            )

    def _setup_watcher(self):
        # Watch Backend files
        backend_dir = self.root_dir / "backend"
        if backend_dir.exists() and self.run_backend:
            def on_backend_change(filepath: str):
                rel = os.path.relpath(filepath, self.root_dir)
                if self.backend_mode == "restart":
                    log("WATCHER", YELLOW, f"File changed: {rel} -> Auto-restarting Backend...")
                    if "backend" in self.services:
                        self.services["backend"].restart()
                else:
                    log("WATCHER", YELLOW, f"File changed: {rel} -> .NET watch recompiling...")

            self.watcher.add_watch(
                directory=backend_dir,
                extensions=[".cs", ".json", ".csproj"],
                ignored_dirs=["bin", "obj", ".vs", ".git"],
                callback=on_backend_change
            )

        # Watch Mobile Flutter lib files
        app_lib_dir = self.root_dir / "app" / "lib"
        if app_lib_dir.exists() and self.run_mobile:
            def on_flutter_change(filepath: str):
                rel = os.path.relpath(filepath, self.root_dir)
                log("WATCHER", GREEN, f"File changed: {rel} -> Triggering Flutter Hot Reload...")
                if "mobile" in self.services:
                    sent = self.services["mobile"].send_stdin("r\n")
                    if not sent:
                        log("WATCHER", YELLOW, "Flutter process not ready or stdin unavailable.")

            self.watcher.add_watch(
                directory=app_lib_dir,
                extensions=[".dart"],
                ignored_dirs=[".dart_tool", "build", ".git"],
                callback=on_flutter_change
            )

        # Watch Mobile pubspec.yaml for Hot Restart
        app_dir = self.root_dir / "app"
        if app_dir.exists() and self.run_mobile:
            def on_pubspec_change(filepath: str):
                rel = os.path.relpath(filepath, self.root_dir)
                log("WATCHER", GREEN, f"Config changed: {rel} -> Triggering Flutter Hot Restart...")
                if "mobile" in self.services:
                    self.services["mobile"].send_stdin("R\n")

            self.watcher.add_watch(
                directory=app_dir,
                extensions=["pubspec.yaml"],
                ignored_dirs=[".dart_tool", "build", "android", "ios", "windows", "linux", "macos", ".git"],
                callback=on_pubspec_change
            )

        # Watch AI Service files
        ai_dir = self.root_dir / "ai_service"
        if ai_dir.exists() and self.run_ai:
            def on_ai_change(filepath: str):
                rel = os.path.relpath(filepath, self.root_dir)
                log("WATCHER", BLUE, f"AI Service file changed: {rel}")

            self.watcher.add_watch(
                directory=ai_dir,
                extensions=[".py", ".env"],
                ignored_dirs=["__pycache__", ".pytest_cache", ".git"],
                callback=on_ai_change
            )

        # Watch Web config files
        web_dir = self.root_dir / "web"
        if web_dir.exists() and self.run_web:
            def on_web_config_change(filepath: str):
                rel = os.path.relpath(filepath, self.root_dir)
                log("WATCHER", CYAN, f"Web config changed: {rel} -> Restarting Vite Dev Server...")
                if "web" in self.services:
                    self.services["web"].restart()

            self.watcher.add_watch(
                directory=web_dir,
                extensions=["vite.config.js", "package.json", ".env"],
                ignored_dirs=["node_modules", "dist", ".git"],
                callback=on_web_config_change
            )

    def print_banner(self):
        with PRINT_LOCK:
            print(f"\n{CYAN}{BOLD}{'=' * 66}{RESET}")
            print(f"{CYAN}{BOLD}  PCForge Multi-Service Development Runner{RESET}")
            print(f"{CYAN}{BOLD}{'=' * 66}{RESET}")
            if self.run_ai:
                print(f"    {BLUE}* AI Microservice:{RESET} http://localhost:5050 (FastAPI Agentic AI)")
            if self.run_backend:
                mode_str = "dotnet watch" if self.backend_mode == "watch" else "runner file-watch restart"
                print(f"    {MAGENTA}* Backend API:{RESET}   http://localhost:5000 (Swagger: /swagger) [{mode_str}]")
            if self.run_web:
                print(f"    {CYAN}* Frontend Web:{RESET}  http://localhost:5173 [Vite HMR]")
            if self.run_mobile:
                dev_str = f"Device: {self.flutter_device}" if self.flutter_device else "Auto-detecting device"
                print(f"    {GREEN}* Mobile Client:{RESET} Flutter [{dev_str}] (Auto Hot-Reload on save)")
            print(f"\n  {BOLD}Interactive Hotkeys:{RESET}")
            print(f"    [{GREEN}r{RESET}] Hot Reload Flutter        [{GREEN}R{RESET}] Hot Restart Flutter")
            print(f"    [{BLUE}a{RESET}] Restart AI Microservice   [{MAGENTA}b{RESET}] Restart Backend")
            print(f"    [{CYAN}w{RESET}] Restart Web               [{GREEN}m{RESET}] Restart Mobile")
            print(f"    [{WHITE}s{RESET}] Service Status            [{YELLOW}h{RESET}] Show Hotkey Help")
            print(f"    [{RED}q{RESET}] Stop All & Exit")
            print(f"{CYAN}{BOLD}{'=' * 66}{RESET}\n", flush=True)

    def print_status(self):
        with PRINT_LOCK:
            print(f"\n{BOLD}Service Status Overview:{RESET}")
            for key, s in self.services.items():
                running = s.is_running and s.process and s.process.poll() is None
                state = f"{GREEN}RUNNING (PID {s.process.pid}){RESET}" if running else f"{RED}STOPPED{RESET}"
                print(f"  * {s.color}{s.name:<32}{RESET}: {state}")
            print()

    def handle_key(self, ch: str):
        if ch.lower() == "a":
            if "ai" in self.services:
                self.services["ai"].restart()
            else:
                log("RUNNER", YELLOW, "AI service is not running.")
        elif ch == "r":
            if "mobile" in self.services:
                log("RUNNER", GREEN, "Manual Hot Reload triggered (r)...")
                self.services["mobile"].send_stdin("r\n")
            else:
                log("RUNNER", YELLOW, "Mobile service is not running.")
        elif ch == "R":
            if "mobile" in self.services:
                log("RUNNER", GREEN, "Manual Hot Restart triggered (R)...")
                self.services["mobile"].send_stdin("R\n")
            else:
                log("RUNNER", YELLOW, "Mobile service is not running.")
        elif ch.lower() == "b":
            if "backend" in self.services:
                self.services["backend"].restart()
            else:
                log("RUNNER", YELLOW, "Backend service is not running.")
        elif ch.lower() == "w":
            if "web" in self.services:
                self.services["web"].restart()
            else:
                log("RUNNER", YELLOW, "Web service is not running.")
        elif ch.lower() == "m":
            if "mobile" in self.services:
                if self.run_backend:
                    setup_adb_reverse(5000, self.flutter_device)
                self.services["mobile"].restart()
            else:
                log("RUNNER", YELLOW, "Mobile service is not running.")
        elif ch.lower() == "s":
            self.print_status()
        elif ch.lower() == "h":
            self.print_banner()
        elif ch.lower() == "q":
            log("RUNNER", YELLOW, "Quit requested. Shutting down all services...")
            self.stop()

    def start(self):
        self.running = True
        self.print_banner()

        # Start services in order: AI -> Backend -> Web -> Mobile
        if "ai" in self.services:
            self.services["ai"].start()
            time.sleep(1.0)

        if "backend" in self.services:
            self.services["backend"].start()
            time.sleep(1.0)

        if "web" in self.services:
            self.services["web"].start()
            time.sleep(0.5)

        if "mobile" in self.services:
            if self.run_backend:
                setup_adb_reverse(5000, self.flutter_device)
            self.services["mobile"].start()

        # Start File Watcher
        self.watcher.start()
        log("RUNNER", BLUE, "File watcher active. Saving files will auto-reload the respective service.")

    def stop(self):
        if not self.running:
            return
        self.running = False
        log("RUNNER", YELLOW, "Stopping file watcher...")
        self.watcher.stop()

        for name, s in self.services.items():
            s.stop()

        log("RUNNER", GREEN, "All services stopped successfully. Goodbye!")

    def run_forever(self):
        self.start()

        # Windows Keyboard Listener Thread
        if sys.platform == "win32":
            def win_keyboard_listener():
                try:
                    import msvcrt
                    while self.running:
                        if msvcrt.kbhit():
                            ch = msvcrt.getch()
                            try:
                                char_str = ch.decode("utf-8", errors="ignore")
                                self.handle_key(char_str)
                            except Exception:
                                pass
                        time.sleep(0.08)
                except Exception:
                    pass

            kb_thread = threading.Thread(target=win_keyboard_listener, daemon=True, name="KeyboardListener")
            kb_thread.start()

        try:
            while self.running:
                time.sleep(0.5)
                # Keep runner alive while running; exit only on Ctrl+C or 'q' hotkey
        except KeyboardInterrupt:
            log("RUNNER", YELLOW, "\nCtrl+C detected. Gracefully shutting down...")
        finally:
            self.stop()

def parse_args():
    import argparse
    parser = argparse.ArgumentParser(
        description="PCForge Development Runner — Run Backend, Web, and Mobile concurrently with live reload."
    )
    parser.add_argument("--no-backend", action="store_true", help="Do not start the ASP.NET Core API")
    parser.add_argument("--no-web", action="store_true", help="Do not start the React/Vite web portal")
    parser.add_argument("--no-mobile", action="store_true", help="Do not start the Flutter mobile client")
    parser.add_argument("--no-ai", action="store_true", help="Do not start the Python Agentic AI service")
    parser.add_argument(
        "--services",
        type=str,
        default="",
        help="Comma-separated list of services to run (e.g. 'backend,web' or 'mobile')"
    )
    parser.add_argument(
        "-d", "--device",
        type=str,
        default=None,
        help="Flutter device ID to target (e.g. 'emulator-5554', 'windows')"
    )
    parser.add_argument(
        "--backend-mode",
        choices=["watch", "restart"],
        default="watch",
        help="'watch' uses 'dotnet watch run' (built-in hot reload), 'restart' uses runner file-watcher restart"
    )
    return parser.parse_args()

def main():
    args = parse_args()
    root_dir = Path(__file__).resolve().parent

    run_backend = not args.no_backend
    run_web = not args.no_web
    run_mobile = not args.no_mobile
    run_ai = not args.no_ai

    if args.services:
        selected = set(s.strip().lower() for s in args.services.split(","))
        run_backend = "backend" in selected
        run_web = "web" in selected
        run_mobile = "mobile" in selected or "app" in selected
        run_ai = "ai" in selected or "agent" in selected

    orchestrator = RunnerOrchestrator(
        root_dir=root_dir,
        run_backend=run_backend,
        run_web=run_web,
        run_mobile=run_mobile,
        run_ai=run_ai,
        flutter_device=args.device,
        backend_mode=args.backend_mode
    )

    # Register OS signals
    def handle_sig(sig, frame):
        orchestrator.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sig)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, handle_sig)

    orchestrator.run_forever()

if __name__ == "__main__":
    main()
