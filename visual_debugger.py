"""
Real-Time Computer Vision Visualizer for Face Pulse (visual_debugger.py)

Connects to the webcam (or test mode synthetic feed), runs FaceFeatureExtractor,
renders full-coverage facial tracking ROI polygons, 3D head pose orientation vectors,
ultra-modern glassmorphic telemetry HUD dashboard, scrolling live pulse waveform graph,
and streams raw frame payloads to FastAPI backend API over WebSocket / HTTP.
"""

import argparse
from collections import deque
from datetime import datetime
import logging
import os
import queue
import sys
import threading
import time
from typing import Deque, Optional, Tuple

import asyncio
import cv2
import httpx
import numpy as np
import websockets

from face_feature_extractor import FaceFeatureExtractor
from schemas import ProcessedRPPGMetrics, QualityStatus, RawRPPGBatch, RawRPPGFrame

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("VisualDebugger")


class BackendStreamer:
    """
    Asynchronous background thread for streaming RawRPPGFrame payloads to FastAPI backend API
    over WebSocket or HTTP batching and capturing returned ProcessedRPPGMetrics (BPM & SNR).
    """

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 8000,
        mode: str = "websocket",
        enabled: bool = True,
    ) -> None:
        self.host = host
        self.port = port
        self.mode = mode.lower()
        self.enabled = enabled

        self.ws_url = f"ws://{self.host}:{self.port}/ws/raw-rppg-stream"
        self.http_url = f"http://{self.host}:{self.port}/api/v1/rppg/raw-batch"

        self.send_queue: queue.Queue = queue.Queue(maxsize=60)
        self.connected: bool = False
        self.latest_metrics: Optional[ProcessedRPPGMetrics] = None
        self._running: bool = False
        self._thread: Optional[threading.Thread] = None

    def start(self) -> None:
        if not self.enabled:
            return
        self._running = True
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False

    def send_frame(self, frame: RawRPPGFrame) -> None:
        if not self.enabled:
            return
        if not self.send_queue.full():
            self.send_queue.put_nowait(frame)

    def _run_loop(self) -> None:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(self._main_task())
        finally:
            loop.close()

    async def _main_task(self) -> None:
        if self.mode == "websocket":
            await self._websocket_worker()
        else:
            await self._http_worker()

    async def _websocket_worker(self) -> None:
        while self._running:
            try:
                async with websockets.connect(self.ws_url, open_timeout=2.0) as ws:
                    self.connected = True
                    logger.info(f"Backend Streamer connected to FastAPI WebSocket at {self.ws_url}")

                    while self._running:
                        try:
                            frame: RawRPPGFrame = self.send_queue.get_nowait()
                            payload_json = frame.model_dump_json()
                            await ws.send(payload_json)

                            # Listen for server metrics response with a small timeout
                            try:
                                resp_text = await asyncio.wait_for(ws.recv(), timeout=0.01)
                                self.latest_metrics = ProcessedRPPGMetrics.model_validate_json(resp_text)
                            except (asyncio.TimeoutError, Exception):
                                pass
                        except queue.Empty:
                            await asyncio.sleep(0.01)
            except Exception:
                self.connected = False
                await asyncio.sleep(1.0)

    async def _http_worker(self) -> None:
        batch_buffer = []
        async with httpx.AsyncClient(timeout=3.0) as http_client:
            while self._running:
                try:
                    frame: RawRPPGFrame = self.send_queue.get_nowait()
                    batch_buffer.append(frame)

                    if len(batch_buffer) >= 30:
                        batch = RawRPPGBatch(
                            client_id="visual_debugger",
                            timestamp=time.time(),
                            frames=batch_buffer,
                        )
                        batch_buffer = []
                        res = await http_client.post(self.http_url, json=batch.model_dump())
                        if res.status_code == 200:
                            self.connected = True
                            self.latest_metrics = ProcessedRPPGMetrics.model_validate_json(res.text)
                        else:
                            self.connected = False
                except queue.Empty:
                    await asyncio.sleep(0.02)
                except Exception:
                    self.connected = False
                    await asyncio.sleep(1.0)


class FacePulseVisualDebugger:
    """
    Real-Time Computer Vision Visualizer for Face Pulse.
    Visualizes full-coverage ROI polygons, ultra-modern glassmorphic telemetry HUD,
    scrolling pulse signal graphs, and streams frame payloads to backend API.
    """

    def __init__(
        self,
        camera_id: int = 0,
        width: int = 1280,
        height: int = 720,
        target_fps: float = 30.0,
        webcam_pitch_offset: float = 0.0,
        save_dir: str = "./debug_screenshots",
        test_mode: bool = False,
        backend_host: str = "127.0.0.1",
        backend_port: int = 8000,
        stream_mode: str = "websocket",
        enable_stream: bool = True,
    ) -> None:
        self.camera_id = camera_id
        self.width = width
        self.height = height
        self.target_fps = target_fps
        self.frame_interval = 1.0 / target_fps
        self.webcam_pitch_offset = webcam_pitch_offset
        self.save_dir = save_dir
        self.test_mode = test_mode

        os.makedirs(self.save_dir, exist_ok=True)

        self.extractor = FaceFeatureExtractor(webcam_pitch_offset=self.webcam_pitch_offset)
        self.streamer = BackendStreamer(
            host=backend_host,
            port=backend_port,
            mode=stream_mode,
            enabled=enable_stream,
        )
        self.green_signal_history: Deque[float] = deque(maxlen=100)
        self.notification_msg: str = ""
        self.notification_counter: int = 0
        self.smoothed_landmarks: Optional[np.ndarray] = None
        self.smoothing_alpha: float = 0.65

    def _draw_bio_wireframe(self, frame: np.ndarray, pts: np.ndarray, color: Tuple[int, int, int]) -> None:
        """Renders subtle cybernetic wireframe grid lines across tracked facial landmark vertices."""
        if len(pts) < 3:
            return
        centroid = np.mean(pts, axis=0).astype(int)
        for i in range(len(pts)):
            pt1 = (int(pts[i][0]), int(pts[i][1]))
            pt2 = (int(pts[(i + 1) % len(pts)][0]), int(pts[(i + 1) % len(pts)][1]))
            cv2.line(frame, pt1, pt2, color, 1, cv2.LINE_AA)
            if i % 3 == 0:
                cv2.line(frame, pt1, (centroid[0], centroid[1]), color, 1, cv2.LINE_AA)

    def _draw_corner_brackets(
        self, frame: np.ndarray, x1: int, y1: int, x2: int, y2: int, color: Tuple[int, int, int], length: int = 14, thickness: int = 2
    ) -> None:
        """Renders high-tech target reticle corner brackets around a bounding box."""
        # Top-Left Corner
        cv2.line(frame, (x1, y1), (x1 + length, y1), color, thickness, lineType=cv2.LINE_AA)
        cv2.line(frame, (x1, y1), (x1, y1 + length), color, thickness, lineType=cv2.LINE_AA)
        # Top-Right Corner
        cv2.line(frame, (x2, y1), (x2 - length, y1), color, thickness, lineType=cv2.LINE_AA)
        cv2.line(frame, (x2, y1), (x2, y1 + length), color, thickness, lineType=cv2.LINE_AA)
        # Bottom-Left Corner
        cv2.line(frame, (x1, y2), (x1 + length, y2), color, thickness, lineType=cv2.LINE_AA)
        cv2.line(frame, (x1, y2), (x1, y2 - length), color, thickness, lineType=cv2.LINE_AA)
        # Bottom-Right Corner
        cv2.line(frame, (x2, y2), (x2 - length, y2), color, thickness, lineType=cv2.LINE_AA)
        cv2.line(frame, (x2, y2), (x2, y2 - length), color, thickness, lineType=cv2.LINE_AA)

    def draw_polygon_overlays(self, frame: np.ndarray, landmarks_2d: np.ndarray) -> np.ndarray:
        """
        Renders high-tech visual face HUD overlay covering forehead and cheeks while camera is active:
        - Full Forehead ROI: Semi-transparent pulsing Emerald Green fill, glowing neon boundary,
          landmark node points, reticle corner brackets, dynamic scanning laser bar, and HUD label.
        - Full Left & Right Cheek ROIs: Semi-transparent pulsing Cyan fills, glowing neon boundaries,
          landmark node points, reticle corner brackets, dynamic scanning laser bar, and HUD labels.
        - Face Lock Reticle: Futuristic face oval target lock frame with alignment crosshairs.
        """
        h, w, _ = frame.shape
        if len(landmarks_2d) < 3:
            return frame

        t = time.time()
        pulse = (np.sin(t * 3.5) + 1.0) / 2.0  # 0.0 to 1.0
        pulse_alpha = 0.22 + 0.08 * pulse

        overlay = frame.copy()

        # Extract ROI points
        fh_pts = landmarks_2d[FaceFeatureExtractor.FOREHEAD_LANDMARKS]
        lc_pts = landmarks_2d[FaceFeatureExtractor.LEFT_CHEEK_LANDMARKS]
        rc_pts = landmarks_2d[FaceFeatureExtractor.RIGHT_CHEEK_LANDMARKS]
        oval_pts = landmarks_2d[FaceFeatureExtractor.FACE_OVAL_LANDMARKS]

        # 1. Fill Forehead ROI (Emerald Green: BGR=(0, 230, 100))
        if len(fh_pts) >= 3:
            hull_fh = cv2.convexHull(fh_pts)
            cv2.fillConvexPoly(overlay, hull_fh, (0, 230, 100))

        # 2. Fill Left Cheek ROI (Cyan: BGR=(255, 200, 0))
        if len(lc_pts) >= 3:
            hull_lc = cv2.convexHull(lc_pts)
            cv2.fillConvexPoly(overlay, hull_lc, (255, 200, 0))

        # 3. Fill Right Cheek ROI (Cyan: BGR=(255, 200, 0))
        if len(rc_pts) >= 3:
            hull_rc = cv2.convexHull(rc_pts)
            cv2.fillConvexPoly(overlay, hull_rc, (255, 200, 0))

        # 4. Blend semi-transparent filled polygons with dynamic pulse alpha
        frame = cv2.addWeighted(overlay, pulse_alpha, frame, 1.0 - pulse_alpha, 0)

        # 5. Render Glowing Neon Boundary Outlines, Bio-Wireframes & Node Dots
        # Forehead Outline & Micro Node Dots (Emerald: BGR=(0, 255, 180))
        if len(fh_pts) >= 3:
            hull_fh = cv2.convexHull(fh_pts)
            cv2.polylines(frame, [hull_fh], isClosed=True, color=(0, 255, 180), thickness=2, lineType=cv2.LINE_AA)
            self._draw_bio_wireframe(frame, fh_pts, (0, 180, 120))
            for pt in fh_pts:
                cv2.circle(frame, (int(pt[0]), int(pt[1])), 2, (0, 255, 220), -1, lineType=cv2.LINE_AA)

            # Forehead Corner Brackets & Laser Scan Line
            x_min, y_min = np.min(fh_pts, axis=0)
            x_max, y_max = np.max(fh_pts, axis=0)
            self._draw_corner_brackets(frame, x_min - 4, y_min - 4, x_max + 4, y_max + 4, (0, 255, 180), length=12, thickness=2)
            scan_y = int(y_min + ((np.sin(t * 4.0) + 1.0) / 2.0) * (y_max - y_min))
            cv2.line(frame, (x_min, scan_y), (x_max, scan_y), (100, 255, 220), 1, lineType=cv2.LINE_AA)

            # Forehead HUD Tag
            centroid_fh = np.mean(fh_pts, axis=0).astype(int)
            tag_fh = "[ FOREHEAD ROI // 31 PTS ]"
            cv2.putText(frame, tag_fh, (centroid_fh[0] - 80, centroid_fh[1] - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (0, 255, 200), 1, cv2.LINE_AA)

        # Left Cheek Outline & Micro Node Dots (Cyan: BGR=(255, 230, 80))
        if len(lc_pts) >= 3:
            hull_lc = cv2.convexHull(lc_pts)
            cv2.polylines(frame, [hull_lc], isClosed=True, color=(255, 230, 80), thickness=2, lineType=cv2.LINE_AA)
            self._draw_bio_wireframe(frame, lc_pts, (200, 180, 40))
            for pt in lc_pts:
                cv2.circle(frame, (int(pt[0]), int(pt[1])), 2, (255, 245, 130), -1, lineType=cv2.LINE_AA)

            # Left Cheek Corner Brackets & Laser Scan Line
            x_min, y_min = np.min(lc_pts, axis=0)
            x_max, y_max = np.max(lc_pts, axis=0)
            self._draw_corner_brackets(frame, x_min - 4, y_min - 4, x_max + 4, y_max + 4, (255, 230, 80), length=10, thickness=2)
            scan_y = int(y_min + ((np.sin(t * 4.5 + 1.0) + 1.0) / 2.0) * (y_max - y_min))
            cv2.line(frame, (x_min, scan_y), (x_max, scan_y), (255, 255, 180), 1, lineType=cv2.LINE_AA)

            # Left Cheek HUD Tag
            centroid_lc = np.mean(lc_pts, axis=0).astype(int)
            cv2.putText(frame, "[ LEFT CHEEK // 21 PTS ]", (centroid_lc[0] - 65, centroid_lc[1] + 4), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (255, 240, 150), 1, cv2.LINE_AA)

        # Right Cheek Outline & Micro Node Dots (Cyan: BGR=(255, 230, 80))
        if len(rc_pts) >= 3:
            hull_rc = cv2.convexHull(rc_pts)
            cv2.polylines(frame, [hull_rc], isClosed=True, color=(255, 230, 80), thickness=2, lineType=cv2.LINE_AA)
            self._draw_bio_wireframe(frame, rc_pts, (200, 180, 40))
            for pt in rc_pts:
                cv2.circle(frame, (int(pt[0]), int(pt[1])), 2, (255, 245, 130), -1, lineType=cv2.LINE_AA)

            # Right Cheek Corner Brackets & Laser Scan Line
            x_min, y_min = np.min(rc_pts, axis=0)
            x_max, y_max = np.max(rc_pts, axis=0)
            self._draw_corner_brackets(frame, x_min - 4, y_min - 4, x_max + 4, y_max + 4, (255, 230, 80), length=10, thickness=2)
            scan_y = int(y_min + ((np.sin(t * 4.5 + 2.0) + 1.0) / 2.0) * (y_max - y_min))
            cv2.line(frame, (x_min, scan_y), (x_max, scan_y), (255, 255, 180), 1, lineType=cv2.LINE_AA)

            # Right Cheek HUD Tag
            centroid_rc = np.mean(rc_pts, axis=0).astype(int)
            cv2.putText(frame, "[ RIGHT CHEEK // 21 PTS ]", (centroid_rc[0] - 70, centroid_rc[1] + 4), cv2.FONT_HERSHEY_SIMPLEX, 0.40, (255, 240, 150), 1, cv2.LINE_AA)

        # 6. Face Target Lock Reticle Frame around Face Oval
        if len(oval_pts) >= 3:
            x_min, y_min = np.min(oval_pts, axis=0)
            x_max, y_max = np.max(oval_pts, axis=0)
            padding = 16
            self._draw_corner_brackets(
                frame,
                max(0, x_min - padding),
                max(0, y_min - padding),
                min(w, x_max + padding),
                min(h, y_max + padding),
                color=(0, 255, 255),
                length=22,
                thickness=2,
            )

        return frame

    def draw_head_pose_3d_axes(
        self,
        frame: np.ndarray,
        rvec: np.ndarray,
        tvec: np.ndarray,
        camera_matrix: np.ndarray,
        dist_coeffs: np.ndarray,
    ) -> None:
        """
        Projects estimated 3D head pose axes (X=Red/Pitch, Y=Green/Yaw, Z=Blue/Roll)
        originating from the nose tip using cv2.projectPoints.
        """
        axis_length = 130.0
        axis_3d = np.float64([
            [0.0, 0.0, 0.0],            # Origin (Nose tip)
            [axis_length, 0.0, 0.0],    # X axis (Pitch / Red)
            [0.0, axis_length, 0.0],    # Y axis (Yaw / Green)
            [0.0, 0.0, axis_length],    # Z axis (Roll / Blue)
        ])

        try:
            imgpts, _ = cv2.projectPoints(axis_3d, rvec, tvec, camera_matrix, dist_coeffs)
            imgpts = imgpts.reshape(-1, 2).astype(int)

            origin = tuple(imgpts[0])
            x_end = tuple(imgpts[1])
            y_end = tuple(imgpts[2])
            z_end = tuple(imgpts[3])

            # Pitch (X-axis): Red
            cv2.line(frame, origin, x_end, (0, 0, 255), 3, cv2.LINE_AA)
            cv2.putText(frame, "X (Pitch)", x_end, cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 0, 255), 1, cv2.LINE_AA)

            # Yaw (Y-axis): Green
            cv2.line(frame, origin, y_end, (0, 255, 0), 3, cv2.LINE_AA)
            cv2.putText(frame, "Y (Yaw)", y_end, cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 255, 0), 1, cv2.LINE_AA)

            # Roll (Z-axis): Blue
            cv2.line(frame, origin, z_end, (255, 0, 0), 3, cv2.LINE_AA)
            cv2.putText(frame, "Z (Roll)", z_end, cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 0, 0), 1, cv2.LINE_AA)

            # Origin dot
            cv2.circle(frame, origin, 4, (255, 255, 255), -1)
        except Exception as e:
            logger.debug(f"3D axis projection error: {e}")

    def draw_telemetry_hud(self, frame: np.ndarray, fps: float, rppg_frame: RawRPPGFrame) -> np.ndarray:
        """
        Renders low-opacity semi-transparent top-bar dashboard without outlines:
        - Light dark glass background (alpha = 0.40)
        - Clean status indicators without outlines
        - Prominent Live BPM & SNR
        - Telemetry metrics
        """
        h, w, _ = frame.shape
        hud_height = 105

        # 1. Low Opacity Dark Glass Panel (Alpha = 0.40)
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, hud_height), (12, 14, 18), -1)
        frame = cv2.addWeighted(overlay, 0.40, frame, 0.60, 0)

        # 2. Quality Status Badge with Status Dot (No Outline)
        status = rppg_frame.status
        status_text = f"STATUS: {status.value}"

        if status == QualityStatus.OK:
            badge_bg = (15, 45, 25)
            dot_color = (0, 255, 120)  # Bright Emerald
            text_color = (240, 255, 240)
        elif status in (QualityStatus.BAD_POSE, QualityStatus.FACE_MISALIGNED):
            badge_bg = (15, 45, 55)
            dot_color = (0, 220, 255)  # Bright Amber/Yellow
            text_color = (255, 255, 220)
        else:
            badge_bg = (15, 15, 50)
            dot_color = (50, 50, 255)  # Bright Crimson Red
            text_color = (255, 230, 230)

        pill_x1, pill_y1 = 20, 15
        (tw, th), _ = cv2.getTextSize(status_text, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 1)
        pill_x2, pill_y2 = pill_x1 + tw + 34, pill_y1 + th + 14
        cv2.rectangle(frame, (pill_x1, pill_y1), (pill_x2, pill_y2), badge_bg, -1, lineType=cv2.LINE_AA)
        cv2.circle(frame, (pill_x1 + 14, pill_y1 + th // 2 + 5), 4, dot_color, -1, lineType=cv2.LINE_AA)
        cv2.putText(
            frame,
            status_text,
            (pill_x1 + 25, pill_y1 + th + 4),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            text_color,
            1,
            lineType=cv2.LINE_AA,
        )

        # 3. Live FPS Badge
        fps_str = f"FPS  {fps:4.1f}"
        cv2.putText(frame, fps_str, (pill_x2 + 20, 36), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 1, cv2.LINE_AA)

        # 4. Face Coverage Badge
        cov_pct = rppg_frame.quality.coverage_ratio * 100.0
        cov_str = f"COVERAGE  {cov_pct:4.1f}%"
        cv2.putText(frame, cov_str, (pill_x2 + 130, 36), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (220, 220, 220), 1, cv2.LINE_AA)

        # 5. Backend API Streaming Status Badge (No Outline)
        if self.streamer and self.streamer.connected:
            api_text = "WS API  CONNECTED"
            api_bg = (15, 45, 25)
            api_dot = (0, 255, 120)
        else:
            api_text = "WS API  OFFLINE"
            api_bg = (30, 30, 35)
            api_dot = (140, 140, 140)

        api_x1 = pill_x2 + 300
        (atw, ath), _ = cv2.getTextSize(api_text, cv2.FONT_HERSHEY_SIMPLEX, 0.52, 1)
        api_x2 = api_x1 + atw + 30
        cv2.rectangle(frame, (api_x1, pill_y1), (api_x2, pill_y2), api_bg, -1, lineType=cv2.LINE_AA)
        cv2.circle(frame, (api_x1 + 12, pill_y1 + ath // 2 + 5), 4, api_dot, -1, lineType=cv2.LINE_AA)
        cv2.putText(
            frame,
            api_text,
            (api_x1 + 22, pill_y1 + ath + 4),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.52,
            (255, 255, 255),
            1,
            lineType=cv2.LINE_AA,
        )

        # 6. Prominent Vitals Card: Live BPM & SNR
        if self.streamer and self.streamer.latest_metrics and self.streamer.latest_metrics.bpm > 0:
            bpm_val = self.streamer.latest_metrics.bpm
            snr_val = self.streamer.latest_metrics.snr_db
            bpm_str = f"BPM  {bpm_val:5.1f}"
            snr_str = f"SNR  {snr_val:+4.1f} dB"
            bpm_color = (255, 235, 0)
        else:
            bpm_str = "BPM  --"
            snr_str = "SNR  --"
            bpm_color = (150, 150, 150)

        cv2.putText(frame, "v", (w - 380, 36), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (80, 80, 255), 2, cv2.LINE_AA)
        cv2.putText(frame, bpm_str, (w - 360, 38), cv2.FONT_HERSHEY_SIMPLEX, 0.75, bpm_color, 2, cv2.LINE_AA)
        cv2.putText(frame, snr_str, (w - 180, 36), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 240, 255), 1, cv2.LINE_AA)

        # 7. Head Pose Telemetry & Raw RGB Means
        yaw = rppg_frame.quality.yaw
        pitch = rppg_frame.quality.pitch
        roll = rppg_frame.quality.roll
        pose_str = f"YAW {yaw:+5.1f}°   PITCH {pitch:+5.1f}°   ROLL {roll:+5.1f}°"
        cv2.putText(frame, pose_str, (20, 82), cv2.FONT_HERSHEY_SIMPLEX, 0.52, (200, 240, 255), 1, cv2.LINE_AA)

        fh = rppg_frame.rois.forehead
        lc = rppg_frame.rois.left_cheek
        rc = rppg_frame.rois.right_cheek
        rgb_str = f"RGB -> Forehead [{fh.red:.0f},{fh.green:.0f},{fh.blue:.0f}]  Cheeks L:[{lc.red:.0f},{lc.green:.0f},{lc.blue:.0f}] R:[{rc.red:.0f},{lc.green:.0f},{rc.blue:.0f}]"
        cv2.putText(frame, rgb_str, (w - 590, 82), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (255, 230, 180), 1, cv2.LINE_AA)

        return frame

    def draw_signal_mini_graph(self, frame: np.ndarray, green_val: float) -> np.ndarray:
        """
        Renders low-opacity scrolling waveform graph at bottom-right without outlines.
        """
        self.green_signal_history.append(green_val)

        h, w, _ = frame.shape
        gw, gh = 340, 125
        gx, gy = w - gw - 20, h - gh - 20

        # Background Low-Opacity Glass Panel (Alpha = 0.40, No Outline)
        overlay = frame.copy()
        cv2.rectangle(overlay, (gx, gy), (gx + gw, gy + gh), (12, 14, 18), -1)
        frame = cv2.addWeighted(overlay, 0.40, frame, 0.60, 0)

        # Graph Header Title & Current Value Badge
        title_str = f"PULSE WAVEFORM (100f)"
        val_str = f"G: {green_val:.1f}"
        cv2.putText(frame, title_str, (gx + 12, gy + 22), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 255, 180), 1, cv2.LINE_AA)
        cv2.putText(frame, val_str, (gx + gw - 80, gy + 22), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0, 255, 255), 1, cv2.LINE_AA)

        # Draw Subtle Grid Lines
        mid_y = gy + 25 + (gh - 35) // 2
        cv2.line(frame, (gx + 10, mid_y), (gx + gw - 10, mid_y), (35, 42, 52), 1, cv2.LINE_AA)

        # Render Scrolling Waveform with Gradient Fill
        vals = list(self.green_signal_history)
        if len(vals) >= 2:
            min_v = min(vals)
            max_v = max(vals)
            span = max_v - min_v
            if span < 1.0:
                min_v -= 0.5
                max_v += 0.5
                span = 1.0

            pts = []
            plot_h = gh - 42
            plot_y_base = gy + gh - 12

            for i, v in enumerate(vals):
                x = gx + 12 + int(i * (gw - 24) / 99.0)
                norm_v = (v - min_v) / span
                y = plot_y_base - int(norm_v * plot_h)
                pts.append((x, y))

            # 1. Fill Area Under Curve (Semi-transparent Green Gradient Fill)
            poly_pts = [(gx + 12, plot_y_base)] + pts + [(pts[-1][0], plot_y_base)]
            poly_arr = np.array(poly_pts, dtype=np.int32).reshape((-1, 1, 2))

            fill_overlay = frame.copy()
            cv2.fillPoly(fill_overlay, [poly_arr], (0, 60, 30))
            frame = cv2.addWeighted(fill_overlay, 0.40, frame, 0.60, 0)

            # 2. Waveform Line (No bounding box outline)
            pts_arr = np.array(pts, dtype=np.int32).reshape((-1, 1, 2))
            cv2.polylines(frame, [pts_arr], isClosed=False, color=(0, 255, 140), thickness=2, lineType=cv2.LINE_AA)

            # 3. Pulse Tip Marker
            cv2.circle(frame, pts[-1], 4, (0, 255, 255), -1, lineType=cv2.LINE_AA)

        return frame

    def draw_notifications(self, frame: np.ndarray) -> None:
        """Draws temporary HUD notifications (e.g. screenshot saved confirmation)."""
        if self.notification_counter > 0 and self.notification_msg:
            h, w, _ = frame.shape
            (tw, th), _ = cv2.getTextSize(self.notification_msg, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
            cx, cy = w // 2, h - 50

            overlay = frame.copy()
            cv2.rectangle(overlay, (cx - tw // 2 - 15, cy - th - 10), (cx + tw // 2 + 15, cy + 10), (0, 100, 0), -1)
            frame = cv2.addWeighted(overlay, 0.8, frame, 0.2, 0)
            cv2.rectangle(frame, (cx - tw // 2 - 15, cy - th - 10), (cx + tw // 2 + 15, cy + 10), (0, 255, 0), 1)

            cv2.putText(
                frame,
                self.notification_msg,
                (cx - tw // 2, cy),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (255, 255, 255),
                2,
                cv2.LINE_AA,
            )
            self.notification_counter -= 1

    def run(self) -> None:
        """Main execution loop connecting camera feed, driving real-time visualization, and streaming to backend."""
        logger.info(f"Launching FacePulse Visual Debugger (Camera ID: {self.camera_id})...")

        # Start background backend streamer
        self.streamer.start()

        cap = None
        if not self.test_mode:
            cap = cv2.VideoCapture(self.camera_id)
            if not cap.isOpened():
                logger.error(f"Failed to open video capture device index {self.camera_id}.")
                logger.info("Switching to Test Mode synthetic feed for validation...")
                self.test_mode = True

        if not self.test_mode and cap is not None:
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)

        prev_time = time.time()
        fps = self.target_fps

        window_name = "Face Pulse - Live Vision Debugger"
        cv2.namedWindow(window_name, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(window_name, self.width, self.height)

        logger.info("Controls: Press 's' to capture screenshot | Press 'q' or ESC to quit.")

        try:
            while True:
                t_start = time.time()

                if self.test_mode:
                    # Synthetic test frame generation
                    frame = self._generate_synthetic_frame(self.width, self.height, t_start)
                    self.extractor.last_landmarks_2d = self._generate_synthetic_landmarks(self.width, self.height, t_start)
                else:
                    ret, frame = cap.read()
                    if not ret:
                        logger.warning("Frame read failed from camera feed.")
                        time.sleep(0.05)
                        continue

                # Run FaceFeatureExtractor processing
                rppg_frame: RawRPPGFrame = self.extractor.extract(frame, timestamp=t_start)
                if self.test_mode and rppg_frame.status == QualityStatus.NO_FACE:
                    rppg_frame.status = QualityStatus.OK
                    rppg_frame.quality.coverage_ratio = 0.35
                    rppg_frame.quality.luminance_y = 120.0

                # Send RawRPPGFrame payload to FastAPI backend API
                self.streamer.send_frame(rppg_frame)

                # Calculate live FPS
                now = time.time()
                dt = now - prev_time
                prev_time = now
                if dt > 0.001:
                    fps = 0.9 * fps + 0.1 * (1.0 / dt)

                # 1. Render Full-Coverage ROI Polygons & Nodes with Smoothed Tracking
                if self.extractor.last_landmarks_2d is not None:
                    raw_landmarks = self.extractor.last_landmarks_2d
                    if self.smoothed_landmarks is None or len(self.smoothed_landmarks) != len(raw_landmarks):
                        self.smoothed_landmarks = raw_landmarks.astype(np.float32)
                    else:
                        self.smoothed_landmarks = self.smoothing_alpha * raw_landmarks.astype(np.float32) + (1.0 - self.smoothing_alpha) * self.smoothed_landmarks
                    tracked_landmarks = self.smoothed_landmarks.astype(np.int32)

                    frame = self.draw_polygon_overlays(frame, tracked_landmarks)

                # 2. Render Telemetry & Ultra-Modern Glassmorphic Top-Bar HUD Dashboard
                frame = self.draw_telemetry_hud(frame, fps, rppg_frame)

                # 3. Render Live Waveform Scrolling Mini-Graph
                g_fh = rppg_frame.rois.forehead.green
                g_lc = rppg_frame.rois.left_cheek.green
                g_rc = rppg_frame.rois.right_cheek.green
                g_mean = (g_fh + g_lc + g_rc) / 3.0 if rppg_frame.status != QualityStatus.NO_FACE else 0.0
                frame = self.draw_signal_mini_graph(frame, g_mean)

                # 4. Render Notifications
                self.draw_notifications(frame)

                # Display in OpenCV Window
                cv2.imshow(window_name, frame)

                # Keyboard Controls
                key = cv2.waitKey(1) & 0xFF
                if key == ord("q") or key == 27:  # 'q' or ESC
                    logger.info("Exit signal received. Quitting visual debugger.")
                    break
                elif key == ord("s") or key == ord("S"):  # 's' for screenshot
                    ts_str = datetime.now().strftime("%Y%m%d_%H%M%S")
                    filepath = os.path.join(self.save_dir, f"screenshot_{ts_str}.png")
                    cv2.imwrite(filepath, frame)
                    logger.info(f"Saved annotated debug snapshot to: {filepath}")
                    self.notification_msg = f"Screenshot Saved: {os.path.basename(filepath)}"
                    self.notification_counter = 60  # Display for ~2 seconds at 30 FPS

                # Target FPS timing
                elapsed = time.time() - t_start
                sleep_time = max(0.001, self.frame_interval - elapsed)
                time.sleep(sleep_time)

        finally:
            if cap is not None and cap.isOpened():
                cap.release()
            cv2.destroyAllWindows()
            self.streamer.stop()
            self.extractor.close()
            logger.info("FacePulse Visual Debugger shutdown complete.")

    def _generate_synthetic_frame(self, w: int, h: int, t: float) -> np.ndarray:
        """Generates a synthetic test frame with a simulated face for headless validation."""
        frame = np.zeros((h, w, 3), dtype=np.uint8)
        frame[:, :] = (40, 40, 40)

        # Draw a synthetic face oval and facial features
        center = (w // 2, h // 2)
        cv2.ellipse(frame, center, (150, 200), 0, 0, 360, (180, 190, 220), -1)

        # Eyes & Mouth
        cv2.circle(frame, (center[0] - 50, center[1] - 40), 15, (50, 50, 50), -1)
        cv2.circle(frame, (center[0] + 50, center[1] - 40), 15, (50, 50, 50), -1)
        cv2.ellipse(frame, (center[0], center[1] + 60), (40, 15), 0, 0, 360, (80, 80, 180), -1)

        # Subtle pulsing green background overlay simulating rPPG pulse
        pulse = np.sin(2 * np.pi * 1.2 * t) * 8.0
        frame[:, :, 1] = np.clip(frame[:, :, 1].astype(float) + pulse, 0, 255).astype(np.uint8)

        return frame

    def _generate_synthetic_landmarks(self, w: int, h: int, t: float) -> np.ndarray:
        """Generates realistic synthetic 2D face mesh landmarks (468, 2) for test mode visual HUD display."""
        cx, cy = w // 2, h // 2
        landmarks = np.zeros((468, 2), dtype=np.int32)

        # Default all points around face center
        landmarks[:, 0] = cx
        landmarks[:, 1] = cy

        # Forehead region landmarks around (cx, cy - 90)
        fh_indices = FaceFeatureExtractor.FOREHEAD_LANDMARKS
        n_fh = len(fh_indices)
        for i, idx in enumerate(fh_indices):
            angle = np.pi * (0.1 + 0.8 * (i / max(1, n_fh - 1)))
            rx, ry = 100, 35
            x = int(cx + rx * np.cos(angle))
            y = int(cy - 95 + ry * np.sin(angle))
            landmarks[idx] = [x, y]

        # Left cheek region landmarks around (cx - 65, cy + 25)
        lc_indices = FaceFeatureExtractor.LEFT_CHEEK_LANDMARKS
        n_lc = len(lc_indices)
        for i, idx in enumerate(lc_indices):
            angle = 2 * np.pi * (i / max(1, n_lc))
            rx, ry = 32, 28
            x = int(cx - 65 + rx * np.cos(angle))
            y = int(cy + 25 + ry * np.sin(angle))
            landmarks[idx] = [x, y]

        # Right cheek region landmarks around (cx + 65, cy + 25)
        rc_indices = FaceFeatureExtractor.RIGHT_CHEEK_LANDMARKS
        n_rc = len(rc_indices)
        for i, idx in enumerate(rc_indices):
            angle = 2 * np.pi * (i / max(1, n_rc))
            rx, ry = 32, 28
            x = int(cx + 65 + rx * np.cos(angle))
            y = int(cy + 25 + ry * np.sin(angle))
            landmarks[idx] = [x, y]

        # Face oval landmarks around (cx, cy)
        oval_indices = FaceFeatureExtractor.FACE_OVAL_LANDMARKS
        n_oval = len(oval_indices)
        for i, idx in enumerate(oval_indices):
            angle = 2 * np.pi * (i / max(1, n_oval))
            rx, ry = 145, 195
            x = int(cx + rx * np.cos(angle))
            y = int(cy + ry * np.sin(angle))
            landmarks[idx] = [x, y]

        return landmarks


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FacePulse Real-Time Computer Vision Visualizer")
    parser.add_argument("--camera", type=int, default=0, help="Webcam device index (default: 0)")
    parser.add_argument("--width", type=int, default=1280, help="Camera resolution width")
    parser.add_argument("--height", type=int, default=720, help="Camera resolution height")
    parser.add_argument("--fps", type=float, default=30.0, help="Target playback FPS")
    parser.add_argument("--pitch-offset", type=float, default=0.0, help="Camera pitch elevation offset calibration (degrees)")
    parser.add_argument("--save-dir", type=str, default="./debug_screenshots", help="Directory to save screenshots")
    parser.add_argument("--test-mode", action="store_true", help="Run with synthetic camera feed for testing")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="FastAPI backend host")
    parser.add_argument("--port", type=int, default=8000, help="FastAPI backend port")
    parser.add_argument("--mode", type=str, default="websocket", choices=["websocket", "http"], help="Backend streaming transport mode")
    parser.add_argument("--no-stream", action="store_true", help="Disable backend API streaming")
    args = parser.parse_args()

    debugger = FacePulseVisualDebugger(
        camera_id=args.camera,
        width=args.width,
        height=args.height,
        target_fps=args.fps,
        webcam_pitch_offset=args.pitch_offset,
        save_dir=args.save_dir,
        test_mode=args.test_mode,
        backend_host=args.host,
        backend_port=args.port,
        stream_mode=args.mode,
        enable_stream=not args.no_stream,
    )

    try:
        debugger.run()
    except KeyboardInterrupt:
        logger.info("Visual Debugger interrupted by user.")
