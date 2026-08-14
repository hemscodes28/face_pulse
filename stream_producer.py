"""
Stream Producer Client for FacePulseEngine.
Captures live camera feed at 30 FPS, runs FaceFeatureExtractor quality gates and ROI spatial mean extractions,
and streams raw payloads to FastAPI backend via Mode A (WebSocket @ 30 Hz) or Mode B (HTTP Batching @ 1 Hz).
"""

import argparse
import asyncio
import json
import logging
import sys
import time
from typing import Optional

import cv2
import httpx
import websockets

from face_feature_extractor import FaceFeatureExtractor
from schemas import RawRPPGBatch, RawRPPGFrame

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("StreamProducer")


class RPPGStreamProducer:
    """
    Asynchronous camera stream producer delivering raw rPPG ROI metrics to backend server.
    """

    def __init__(
        self,
        camera_id: int = 0,
        fps: float = 30.0,
        mode: str = "websocket",
        backend_host: str = "127.0.0.1",
        backend_port: int = 8000,
        client_id: str = "producer_01",
    ) -> None:
        self.camera_id = camera_id
        self.target_fps = fps
        self.frame_interval = 1.0 / fps
        self.mode = mode.lower()
        self.backend_host = backend_host
        self.backend_port = backend_port
        self.client_id = client_id

        self.ws_url = f"ws://{self.backend_host}:{self.backend_port}/ws/raw-rppg-stream"
        self.http_url = f"http://{self.backend_host}:{self.backend_port}/api/v1/rppg/raw-batch"

        self.extractor = FaceFeatureExtractor()
        self._running = False
        self._batch_buffer: list[RawRPPGFrame] = []

    async def start(self, display_preview: bool = False) -> None:
        """
        Starts the video capture loop and streaming pipeline.
        """
        self._running = True
        logger.info(f"Starting StreamProducer in Mode '{self.mode}'...")

        if self.mode == "websocket":
            await self._run_websocket_mode(display_preview)
        elif self.mode == "http" or self.mode == "batch":
            await self._run_http_batch_mode(display_preview)
        else:
            logger.error(f"Unknown transport mode: {self.mode}. Choose 'websocket' or 'http'.")

    def stop() -> None:
        """Stops the streaming loop."""
        self._running = False

    async def _run_websocket_mode(self, display_preview: bool) -> None:
        """
        Mode A: Continuously streams raw frame payloads to backend over WebSocket at 30 Hz.
        Includes automatic reconnection with exponential backoff on disconnect.
        """
        reconnect_delay = 1.0
        cap = cv2.VideoCapture(self.camera_id)

        if not cap.isOpened():
            logger.error(f"Failed to open video capture device ID {self.camera_id}")
            return

        try:
            while self._running:
                logger.info(f"Connecting to WebSocket endpoint: {self.ws_url}")
                try:
                    async with websockets.connect(self.ws_url) as websocket:
                        logger.info("WebSocket connection established with backend server.")
                        reconnect_delay = 1.0  # Reset delay on successful connection

                        while self._running:
                            t_start = time.time()
                            ret, frame = cap.read()

                            if not ret:
                                logger.warning("Camera frame read failed. Retrying...")
                                await asyncio.sleep(0.1)
                                continue

                            # Process frame via FaceFeatureExtractor
                            rppg_frame: RawRPPGFrame = self.extractor.extract(frame, timestamp=t_start)

                            # Send JSON payload over WebSocket
                            payload_json = rppg_frame.model_dump_json()
                            await websocket.send(payload_json)

                            # Optionally listen for processed metrics response from server
                            try:
                                response = await asyncio.wait_for(websocket.recv(), timeout=0.005)
                                logger.debug(f"Received server metrics: {response[:100]}...")
                            except asyncio.TimeoutError:
                                pass

                            if display_preview:
                                self._show_preview(frame, rppg_frame)
                                if cv2.waitKey(1) & 0xFF == ord('q'):
                                    self._running = False
                                    break

                            # Maintain target FPS rate timing
                            elapsed = time.time() - t_start
                            sleep_time = max(0.0, self.frame_interval - elapsed)
                            await asyncio.sleep(sleep_time)

                except (websockets.ConnectionClosed, OSError, Exception) as e:
                    logger.warning(f"WebSocket connection lost ({e}). Reconnecting in {reconnect_delay:.1f}s...")
                    await asyncio.sleep(reconnect_delay)
                    reconnect_delay = min(reconnect_delay * 2.0, 15.0)

        finally:
            cap.release()
            cv2.destroyAllWindows()
            self.extractor.close()
            logger.info("StreamProducer stopped.")

    async def _run_http_batch_mode(self, display_preview: bool) -> None:
        """
        Mode B: Buffers 30 frames (1s of data) and posts a single batched payload via HTTP POST.
        """
        cap = cv2.VideoCapture(self.camera_id)

        if not cap.isOpened():
            logger.error(f"Failed to open video capture device ID {self.camera_id}")
            return

        async with httpx.AsyncClient(timeout=5.0) as http_client:
            try:
                while self._running:
                    t_start = time.time()
                    ret, frame = cap.read()

                    if not ret:
                        logger.warning("Camera frame read failed.")
                        await asyncio.sleep(0.1)
                        continue

                    # Extract rPPG frame metrics
                    rppg_frame = self.extractor.extract(frame, timestamp=t_start)
                    self._batch_buffer.append(rppg_frame)

                    # Flush batch when buffer reaches 30 frames
                    if len(self._batch_buffer) >= 30:
                        batch_payload = RawRPPGBatch(
                            client_id=self.client_id,
                            timestamp=time.time(),
                            frames=self._batch_buffer,
                        )
                        self._batch_buffer = []

                        # Fire HTTP POST in background task so capture loop doesn't stall
                        asyncio.create_task(self._send_http_batch(http_client, batch_payload))

                    if display_preview:
                        self._show_preview(frame, rppg_frame)
                        if cv2.waitKey(1) & 0xFF == ord('q'):
                            self._running = False
                            break

                    elapsed = time.time() - t_start
                    sleep_time = max(0.0, self.frame_interval - elapsed)
                    await asyncio.sleep(sleep_time)

            finally:
                cap.release()
                cv2.destroyAllWindows()
                self.extractor.close()

    async def _send_http_batch(self, http_client: httpx.AsyncClient, batch: RawRPPGBatch) -> None:
        """Helper to post batch payload to HTTP backend."""
        try:
            res = await http_client.post(self.http_url, json=batch.model_dump())
            if res.status_code == 200:
                logger.info(f"Successfully posted batch of 30 frames to {self.http_url}")
            else:
                logger.warning(f"HTTP batch post returned status {res.status_code}: {res.text}")
        except Exception as e:
            logger.error(f"Failed to post HTTP batch: {e}")

    def _show_preview(self, frame: cv2.Mat, rppg_frame: RawRPPGFrame) -> None:
        """Helper to render live OpenCV preview window with visual face HUD covering forehead & cheeks."""
        overlay = frame.copy()

        # Render Forehead and Cheek ROI Overlays if landmarks are present
        if self.extractor.last_landmarks_2d is not None and len(self.extractor.last_landmarks_2d) >= 3:
            landmarks_2d = self.extractor.last_landmarks_2d
            fh_pts = landmarks_2d[FaceFeatureExtractor.FOREHEAD_LANDMARKS]
            lc_pts = landmarks_2d[FaceFeatureExtractor.LEFT_CHEEK_LANDMARKS]
            rc_pts = landmarks_2d[FaceFeatureExtractor.RIGHT_CHEEK_LANDMARKS]
            oval_pts = landmarks_2d[FaceFeatureExtractor.FACE_OVAL_LANDMARKS]

            poly_overlay = overlay.copy()
            if len(fh_pts) >= 3:
                cv2.fillConvexPoly(poly_overlay, cv2.convexHull(fh_pts), (0, 230, 100))
            if len(lc_pts) >= 3:
                cv2.fillConvexPoly(poly_overlay, cv2.convexHull(lc_pts), (255, 200, 0))
            if len(rc_pts) >= 3:
                cv2.fillConvexPoly(poly_overlay, cv2.convexHull(rc_pts), (255, 200, 0))
            overlay = cv2.addWeighted(poly_overlay, 0.25, overlay, 0.75, 0)

            # Draw Neon Outlines & Node Dots
            if len(fh_pts) >= 3:
                cv2.polylines(overlay, [cv2.convexHull(fh_pts)], isClosed=True, color=(0, 255, 180), thickness=2, lineType=cv2.LINE_AA)
            if len(lc_pts) >= 3:
                cv2.polylines(overlay, [cv2.convexHull(lc_pts)], isClosed=True, color=(255, 230, 80), thickness=2, lineType=cv2.LINE_AA)
            if len(rc_pts) >= 3:
                cv2.polylines(overlay, [cv2.convexHull(rc_pts)], isClosed=True, color=(255, 230, 80), thickness=2, lineType=cv2.LINE_AA)

            if len(oval_pts) >= 3:
                x_min, y_min = np.min(oval_pts, axis=0)
                x_max, y_max = np.max(oval_pts, axis=0)
                cv2.rectangle(overlay, (x_min - 10, y_min - 10), (x_max + 10, y_max + 10), (0, 255, 255), 1, lineType=cv2.LINE_AA)

        status_str = f"Status: {rppg_frame.status.value}"
        cov_str = f"Coverage: {rppg_frame.quality.coverage_ratio * 100:.1f}%"
        pose_str = f"Yaw: {rppg_frame.quality.yaw:.1f} Pitch: {rppg_frame.quality.pitch:.1f}"
        lum_str = f"Y-Luma: {rppg_frame.quality.luminance_y:.1f}"

        color = (0, 255, 0) if rppg_frame.status == "OK" else (0, 0, 255)

        cv2.putText(overlay, status_str, (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2, lineType=cv2.LINE_AA)
        cv2.putText(overlay, cov_str, (20, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, lineType=cv2.LINE_AA)
        cv2.putText(overlay, pose_str, (20, 95), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, lineType=cv2.LINE_AA)
        cv2.putText(overlay, lum_str, (20, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, lineType=cv2.LINE_AA)

        cv2.imshow("FacePulseEngine Stream Producer", overlay)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FacePulseEngine Real-Time Stream Producer")
    parser.add_argument("--mode", type=str, default="websocket", choices=["websocket", "http"], help="Transport mode")
    parser.add_argument("--camera", type=int, default=0, help="Camera device index")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Backend server host")
    parser.add_argument("--port", type=int, default=8000, help="Backend server port")
    parser.add_argument("--preview", action="store_true", help="Display OpenCV preview window")
    args = parser.parse_args()

    producer = RPPGStreamProducer(
        camera_id=args.camera,
        mode=args.mode,
        backend_host=args.host,
        backend_port=args.port,
    )

    try:
        asyncio.run(producer.start(display_preview=args.preview))
    except KeyboardInterrupt:
        producer.stop()
        logger.info("Producer terminated by user.")
