"""
app/services/measurement_runtime.py

Thread-safe singleton that holds the live measurement state for a single
active visual-debugger session.

The background DebuggerRunner thread calls update() on every processed frame.
FastAPI endpoints call snapshot() to return the latest values as JSON.
"""

import threading
from datetime import datetime, timezone
from typing import Optional


class MeasurementRuntime:
    """
    Singleton live-state container for the active visual-debugger measurement.

    All public methods are thread-safe (protected by an internal Lock).
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._stop_event = threading.Event()

        # Measurement identity
        self.measurement_id: Optional[str] = None
        self.running: bool = False

        # Latest frame result (None = no result yet / WAITING)
        self.latest_frame: Optional[int] = None
        self.status: Optional[str] = None
        self.bpm: Optional[float] = None
        self.luminance: Optional[float] = None
        self.snr: Optional[float] = None
        self.timestamp: Optional[str] = None

    # ── Lifecycle ────────────────────────────────────────────────────────────

    def reset(self, measurement_id: str) -> None:
        """Prepare runtime for a new measurement session."""
        with self._lock:
            self._stop_event.clear()
            self.measurement_id = measurement_id
            self.running = True
            self.latest_frame = None
            self.status = None
            self.bpm = None
            self.luminance = None
            self.snr = None
            self.timestamp = None

    def request_stop(self) -> None:
        """Signal the background thread to stop."""
        with self._lock:
            self.running = False
        self._stop_event.set()

    def mark_stopped(self) -> None:
        """Called by the background thread when it has fully exited."""
        with self._lock:
            self.running = False

    # ── Data ingestion ───────────────────────────────────────────────────────

    def update(
        self,
        frame: int,
        status: str,
        bpm: Optional[float],
        luminance: Optional[float],
        snr: Optional[float],
    ) -> None:
        """
        Push a new frame result into the runtime.
        Called by the DebuggerRunner on every processed frame (or every N frames).
        """
        with self._lock:
            self.latest_frame = frame
            self.status = status
            self.bpm = round(bpm, 1) if bpm is not None else None
            self.luminance = round(luminance, 1) if luminance is not None else None
            self.snr = round(snr, 2) if snr is not None else None
            self.timestamp = datetime.now(timezone.utc).isoformat()

    # ── Data retrieval ───────────────────────────────────────────────────────

    def snapshot(self) -> dict:
        """Return a thread-safe copy of the current runtime state."""
        with self._lock:
            return {
                "measurement_id": self.measurement_id,
                "running": self.running,
                "frame": self.latest_frame,
                "status": self.status,
                "bpm": self.bpm,
                "luminance": self.luminance,
                "snr": self.snr,
                "timestamp": self.timestamp,
            }

    # ── Stop flag ────────────────────────────────────────────────────────────

    def stop_requested(self) -> bool:
        """Returns True if the stop signal has been set."""
        return self._stop_event.is_set()

    def wait_for_stop(self, timeout: float = 5.0) -> None:
        """Block until the stop event fires (or timeout). Used by /stop endpoint."""
        self._stop_event.wait(timeout=timeout)


# Module-level singleton — imported everywhere that needs runtime state.
runtime = MeasurementRuntime()
