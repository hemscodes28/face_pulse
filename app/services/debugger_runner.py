"""
app/services/debugger_runner.py

Thin adapter that runs the existing FacePulseVisualDebugger in a background
daemon thread and feeds its per-frame output into MeasurementRuntime.

Design constraints:
  - visual_debugger.py is NOT modified.
  - rppg_processor.py is NOT modified.
  - face_feature_extractor.py is NOT modified.
  - No video frames are sent to FastAPI — only scalar measurement results.

How BPM/SNR are produced:
  The existing RPPGSignalProcessor (rppg_processor.py at project root) is
  instantiated here. On every valid webcam frame, the green channel from the
  forehead + cheek ROIs is fed into it to obtain real BPM and SNR values using
  the same POS + Welch PSD pipeline used by the rest of the codebase.

  Luminance is derived from the global_skin ROI RGB means using the BT.601
  formula:  Y = 0.299*R + 0.587*G + 0.114*B
"""

import logging
import os
import sys
import threading
import time
from typing import Optional

logger = logging.getLogger("DebuggerRunner")

# ── Path setup ────────────────────────────────────────────────────────────────
# visual_debugger.py and rppg_processor.py live at the project root, not inside
# the `app/` package.  Insert the project root into sys.path so they can be
# imported from any working directory.
_PROJECT_ROOT = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "..")
)
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)

from rppg_processor import RPPGSignalProcessor           # noqa: E402
from schemas import QualityStatus                        # noqa: E402
from face_feature_extractor import FaceFeatureExtractor  # noqa: E402

from app.services.measurement_runtime import runtime     # noqa: E402


# ── DebuggerThread ────────────────────────────────────────────────────────────

class DebuggerThread(threading.Thread):
    """
    Background daemon thread that:
      1. Opens the webcam (cv2.VideoCapture).
      2. Runs FaceFeatureExtractor per frame (same as the visual debugger).
      3. Feeds RGB means into RPPGSignalProcessor.
      4. Pushes results into MeasurementRuntime every frame.
      5. Optionally opens an OpenCV display window (can be suppressed).

    This thread is intentionally kept separate from FacePulseVisualDebugger so
    that we do NOT touch visual_debugger.py at all.  The visual logic (HUD,
    overlays, etc.) is irrelevant for the JSON API; we only need the numerical
    outputs.
    """

    def __init__(
        self,
        camera_id: int = 0,
        width: int = 1280,
        height: int = 720,
        target_fps: float = 30.0,
        webcam_pitch_offset: float = 0.0,
        headless: bool = False,
    ) -> None:
        super().__init__(daemon=True, name="DebuggerRunner")
        self.camera_id = camera_id
        self.width = width
        self.height = height
        self.target_fps = target_fps
        self.frame_interval = 1.0 / target_fps
        self.webcam_pitch_offset = webcam_pitch_offset
        self.headless = headless  # If True, suppress OpenCV window

    def run(self) -> None:
        """Main loop — runs until runtime.stop_requested() is True."""
        import cv2
        import numpy as np

        logger.info(
            f"DebuggerRunner starting (camera={self.camera_id}, "
            f"headless={self.headless})"
        )

        # ── Initialise sub-components ─────────────────────────────────────────
        extractor = FaceFeatureExtractor(webcam_pitch_offset=self.webcam_pitch_offset)
        processor = RPPGSignalProcessor(fs=self.target_fps)

        # ── Open webcam ───────────────────────────────────────────────────────
        cap = cv2.VideoCapture(self.camera_id, cv2.CAP_DSHOW)
        if not cap.isOpened():
            logger.info(f"CAP_DSHOW default failed for index {self.camera_id}, trying default driver...")
            cap = cv2.VideoCapture(self.camera_id)
        if not cap.isOpened():
            logger.info("Trying secondary camera index 1 with CAP_DSHOW...")
            cap = cv2.VideoCapture(1, cv2.CAP_DSHOW)

        if not cap.isOpened():
            logger.error(
                f"Cannot open camera {self.camera_id} or fallback camera. "
                "Check that no other process (Zoom/OBS/Browser) is using it."
            )
            runtime.mark_stopped()
            return

        cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)

        # ── Optional display window ───────────────────────────────────────────
        window_name = "Face Pulse - Debugger Runner"
        if not self.headless:
            try:
                cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
                cv2.resizeWindow(window_name, 800, 480)
            except Exception:
                self.headless = True  # Fall back silently

        frame_idx = 0

        try:
            while not runtime.stop_requested():
                t_start = time.time()

                ret, frame = cap.read()
                if not ret:
                    logger.warning("Frame read failed — skipping.")
                    time.sleep(0.05)
                    continue

                frame_idx += 1

                # ── FaceFeatureExtractor ──────────────────────────────────────
                rppg_frame = extractor.extract(frame, timestamp=t_start)

                status_str = rppg_frame.status.value  # e.g. "OK", "NO_FACE"

                # ── Compute luminance from global_skin ROI (BT.601) ───────────
                gs = rppg_frame.rois.global_skin
                luminance: Optional[float] = (
                    0.299 * gs.red + 0.587 * gs.green + 0.114 * gs.blue
                    if rppg_frame.status == QualityStatus.OK
                    else None
                )

                # ── Feed into rPPG processor ──────────────────────────────────
                # Average the green channels across forehead + two cheeks as
                # the primary photoplethysmography signal (matches existing HUD).
                bpm_val: Optional[float] = None
                snr_val: Optional[float] = None

                if rppg_frame.status == QualityStatus.OK:
                    fh = rppg_frame.rois.forehead
                    lc = rppg_frame.rois.left_cheek
                    rc = rppg_frame.rois.right_cheek

                    # Use per-ROI means weighted equally
                    r_mean = (fh.red + lc.red + rc.red) / 3.0
                    g_mean = (fh.green + lc.green + rc.green) / 3.0
                    b_mean = (fh.blue + lc.blue + rc.blue) / 3.0

                    metrics = processor.update(
                        r=r_mean,
                        g=g_mean,
                        b=b_mean,
                        timestamp=t_start,
                        status=rppg_frame.status,
                    )

                    # Only expose BPM/SNR once the processor has warmed up
                    # (processor returns bpm=0.0 during buffer fill)
                    if metrics.bpm > 0.0:
                        bpm_val = metrics.bpm
                        snr_val = metrics.snr_db
                else:
                    # Pass the bad-status frame through so the processor can
                    # manage its own buffer integrity.
                    processor.update(
                        r=0.0,
                        g=0.0,
                        b=0.0,
                        timestamp=t_start,
                        status=rppg_frame.status,
                    )

                # ── Push to runtime ───────────────────────────────────────────
                runtime.update(
                    frame=frame_idx,
                    status=status_str,
                    bpm=bpm_val,
                    luminance=luminance,
                    snr=snr_val,
                )

                if bpm_val is not None:
                    logger.info(
                        f"[rPPG PULSE ENGINE] Frame #{frame_idx}: Live Heart Rate = {bpm_val:.1f} BPM | SNR = {snr_val:+.1f} dB | Luminance = {luminance:.1f} Y | Status: {status_str}"
                    )

                # ── Optional display ──────────────────────────────────────────
                if not self.headless:
                    try:
                        # Annotate frame with minimal overlay for debugging
                        import numpy as np  # already imported above
                        h, w, _ = frame.shape
                        bpm_text = (
                            f"BPM: {bpm_val:.1f}" if bpm_val else "BPM: warming up..."
                        )
                        snr_text = (
                            f"SNR: {snr_val:+.1f} dB" if snr_val else "SNR: --"
                        )
                        lum_text = (
                            f"Lum: {luminance:.1f}" if luminance else "Lum: --"
                        )
                        cv2.putText(
                            frame, f"Frame #{frame_idx} | {status_str}",
                            (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (0, 255, 200), 2, cv2.LINE_AA,
                        )
                        cv2.putText(
                            frame, bpm_text,
                            (10, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (255, 230, 0), 2, cv2.LINE_AA,
                        )
                        cv2.putText(
                            frame, snr_text,
                            (10, 100), cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (200, 240, 255), 2, cv2.LINE_AA,
                        )
                        cv2.putText(
                            frame, lum_text,
                            (10, 135), cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                            (200, 240, 255), 2, cv2.LINE_AA,
                        )
                        cv2.imshow(window_name, frame)

                        key = cv2.waitKey(1) & 0xFF
                        if key == ord("q") or key == 27:
                            logger.info("Manual quit via keypress.")
                            runtime.request_stop()
                            break
                    except Exception:
                        self.headless = True  # Suppress further window errors

                # ── FPS pacing ────────────────────────────────────────────────
                elapsed = time.time() - t_start
                sleep_time = max(0.001, self.frame_interval - elapsed)
                time.sleep(sleep_time)

        except Exception as exc:
            logger.exception(f"DebuggerRunner crashed: {exc}")
        finally:
            cap.release()
            if not self.headless:
                try:
                    cv2.destroyWindow(window_name)
                except Exception:
                    pass
            extractor.close()
            runtime.mark_stopped()
            logger.info("DebuggerRunner shut down — camera released.")


# ── Module-level thread handle ────────────────────────────────────────────────
_active_thread: Optional[DebuggerThread] = None


def start_debugger(
    measurement_id: str,
    camera_id: int = 0,
    headless: bool = False,
) -> None:
    """
    Start the DebuggerThread for a new measurement session.
    Stops any previously running thread first.
    """
    global _active_thread

    # Stop previous session if still alive
    if _active_thread is not None and _active_thread.is_alive():
        logger.info("Stopping previous DebuggerThread before starting new session.")
        runtime.request_stop()
        _active_thread.join(timeout=6.0)

    # Prepare runtime state
    runtime.reset(measurement_id)

    # Launch background thread
    _active_thread = DebuggerThread(camera_id=camera_id, headless=headless)
    _active_thread.start()
    logger.info(
        f"DebuggerThread started for measurement_id={measurement_id}"
    )


def stop_debugger(timeout: float = 5.0) -> None:
    """
    Signal the DebuggerThread to stop and wait for it to exit.
    """
    global _active_thread

    runtime.request_stop()

    if _active_thread is not None and _active_thread.is_alive():
        _active_thread.join(timeout=timeout)

    logger.info("DebuggerThread stopped.")
