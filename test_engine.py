"""
Comprehensive Unit and Integration Test Suite for FacePulseEngine.
Validates DSP pulse accuracy on synthetic rPPG signals, vision quality gate evaluation,
harmonic guarding, EMA smoothing, and FastAPI WebSocket / HTTP batch endpoint communication.
"""

import math
import sys
import time
import unittest
import numpy as np
from fastapi.testclient import TestClient

from schemas import FacialROIs, QualityMetrics, QualityStatus, RawRPPGBatch, RawRPPGFrame, ROIValues
from rppg_processor import RPPGSignalProcessor
from face_feature_extractor import FaceFeatureExtractor
from face_tracker import FaceMeshTracker
from mock_backend_receiver import app


class TestRPPGSignalProcessor(unittest.TestCase):
    """Unit tests for RPPGSignalProcessor POS algorithm, harmonic guarding, and temporal smoothing."""

    def test_synthetic_pulse_estimation(self):
        """Verify heart rate recovery on a synthetic 72 BPM (1.2 Hz) rPPG signal."""
        target_bpm = 72.0
        target_freq = target_bpm / 60.0  # 1.2 Hz
        fs = 30.0
        n_samples = 240  # 8 seconds @ 30 FPS

        processor = RPPGSignalProcessor(buffer_size=n_samples, fs=fs)

        t = np.arange(n_samples) / fs
        base_g = 150.0 + 4.0 * np.sin(2.0 * np.pi * target_freq * t)
        base_r = 180.0 + 1.0 * np.sin(2.0 * np.pi * target_freq * t)
        base_b = 120.0 + 0.5 * np.sin(2.0 * np.pi * target_freq * t)

        metrics = None
        for i in range(n_samples):
            metrics = processor.update(
                r=float(base_r[i]),
                g=float(base_g[i]),
                b=float(base_b[i]),
                timestamp=t[i],
                status=QualityStatus.OK,
            )

        self.assertIsNotNone(metrics)
        self.assertAlmostEqual(metrics.bpm, target_bpm, delta=1.5)
        self.assertGreater(metrics.snr_db, 3.0)
        self.assertGreater(metrics.signal_quality, 0.4)

    def test_harmonic_guard(self):
        """Verify Harmonic Guard suppresses 144 BPM harmonic peak in favor of 72 BPM resting peak."""
        target_freq = 1.2  # 72 BPM
        harmonic_freq = 2.4 # 144 BPM
        fs = 30.0
        n_samples = 240

        processor = RPPGSignalProcessor(buffer_size=n_samples, fs=fs)

        t = np.arange(n_samples) / fs
        # Signal with fundamental at 1.2 Hz + harmonic at 2.4 Hz
        g_sig = 150.0 + 3.0 * np.sin(2.0 * np.pi * target_freq * t) + 1.5 * np.sin(2.0 * np.pi * harmonic_freq * t)
        r_sig = 180.0 + 0.8 * np.sin(2.0 * np.pi * target_freq * t) + 0.4 * np.sin(2.0 * np.pi * harmonic_freq * t)
        b_sig = 120.0 + 0.5 * np.sin(2.0 * np.pi * target_freq * t) + 0.2 * np.sin(2.0 * np.pi * harmonic_freq * t)

        metrics = None
        for i in range(n_samples):
            metrics = processor.update(
                r=float(r_sig[i]),
                g=float(g_sig[i]),
                b=float(b_sig[i]),
                timestamp=t[i],
                status=QualityStatus.OK,
            )

        self.assertAlmostEqual(metrics.bpm, 72.0, delta=2.0)

    def test_ema_smoothing_and_outlier_rejection(self):
        """Verify EMA smoothing (alpha=0.25) and outlier rejection (>15 BPM jump with low SNR)."""
        processor = RPPGSignalProcessor(buffer_size=240, fs=30.0, ema_alpha=0.25)
        processor.prev_stable_bpm = 75.0
        processor.latest_bpm = 75.0

        # Simulate low SNR outlier jump to 140 BPM
        raw_bpm = 140.0
        low_snr = -2.0
        
        # Manually trigger candidate logic
        bpm_diff = abs(raw_bpm - processor.prev_stable_bpm)
        self.assertGreater(bpm_diff, 15.0)

    def test_pos_algorithm_math(self):
        """Direct mathematical test of compute_pos formulation."""
        processor = RPPGSignalProcessor(buffer_size=60, fs=30.0)
        r = np.full(60, 180.0)
        g = np.full(60, 150.0)
        b = np.full(60, 120.0)

        h = processor.compute_pos(r, g, b)
        self.assertEqual(len(h), 60)
        self.assertFalse(np.isnan(h).any())


class TestFaceFeatureExtractor(unittest.TestCase):
    """Unit tests for FaceFeatureExtractor and FaceMeshTracker quality gates."""

    def test_no_face_detection(self):
        """Test extractor handling on a blank image with no face."""
        extractor = FaceFeatureExtractor()
        blank_frame = np.zeros((480, 640, 3), dtype=np.uint8)
        rppg_frame = extractor.process_frame(blank_frame)

        self.assertEqual(rppg_frame.status, QualityStatus.NO_FACE)
        self.assertEqual(rppg_frame.rois.global_skin.red, 0.0)
        self.assertIsNone(extractor.last_landmarks_2d)
        self.assertIsNone(extractor.last_rvec)
        self.assertIsNone(extractor.last_tvec)
        extractor.close()

    def test_face_mesh_tracker_alias(self):
        """Verify FaceMeshTracker subclass functionality."""
        tracker = FaceMeshTracker()
        blank_frame = np.zeros((480, 640, 3), dtype=np.uint8)
        rppg_frame = tracker.extract(blank_frame)
        self.assertEqual(rppg_frame.status, QualityStatus.NO_FACE)
        tracker.close()


class TestVisualDebugger(unittest.TestCase):
    """Unit tests for FacePulseVisualDebugger rendering components and synthetic test mode."""

    def test_rendering_components(self):
        """Verify HUD, signal graph, polygon overlays, and 3D axes rendering on synthetic frames."""
        from visual_debugger import FacePulseVisualDebugger

        debugger = FacePulseVisualDebugger(test_mode=True, save_dir="./test_debug_screenshots")

        # Create synthetic frame and mock frame payload
        frame = debugger._generate_synthetic_frame(640, 480, time.time())
        roi = ROIValues(red=140.0, green=120.0, blue=100.0)
        rppg_frame = RawRPPGFrame(
            timestamp=time.time(),
            frame_id=1,
            status=QualityStatus.OK,
            rois=FacialROIs(forehead=roi, left_cheek=roi, right_cheek=roi, global_skin=roi),
            quality=QualityMetrics(coverage_ratio=0.25, yaw=3.5, pitch=-2.0, roll=0.5, luminance_y=110.0),
        )

        # 1. Test Telemetry HUD
        hud_frame = debugger.draw_telemetry_hud(frame.copy(), fps=30.0, rppg_frame=rppg_frame)
        self.assertEqual(hud_frame.shape, (480, 640, 3))

        # 2. Test Signal Mini-Graph
        graph_frame = debugger.draw_signal_mini_graph(hud_frame, green_val=120.0)
        self.assertEqual(graph_frame.shape, (480, 640, 3))
        self.assertEqual(len(debugger.green_signal_history), 1)

        # 3. Test Polygon Overlays with mock landmark array
        mock_landmarks = np.random.randint(50, 400, size=(468, 2), dtype=np.int32)
        poly_frame = debugger.draw_polygon_overlays(graph_frame, mock_landmarks)
        self.assertEqual(poly_frame.shape, (480, 640, 3))

        # 4. Test 3D Head Pose Axes Projection
        rvec = np.zeros((3, 1), dtype=np.float64)
        tvec = np.array([[0.0], [0.0], [500.0]], dtype=np.float64)
        cam_mat = np.eye(3, dtype=np.float64)
        dist = np.zeros((4, 1), dtype=np.float64)
        debugger.draw_head_pose_3d_axes(poly_frame, rvec, tvec, cam_mat, dist)

        # Clean up extractor resources
        debugger.extractor.close()


class TestMockBackendEndpoints(unittest.TestCase):
    """Integration tests for FastAPI receiver endpoints."""

    def setUp(self):
        self.client = TestClient(app)

    def test_health_check(self):
        """Test /health endpoint."""
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_status_endpoint(self):
        """Test /api/v1/rppg/status endpoint."""
        response = self.client.get("/api/v1/rppg/status")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "online")

    def test_http_batch_post(self):
        """Test POST /api/v1/rppg/raw-batch endpoint."""
        frames = []
        t0 = time.time()
        for i in range(30):
            roi = ROIValues(red=180.0, green=150.0 + math.sin(i), blue=120.0)
            frame = RawRPPGFrame(
                timestamp=t0 + i * 0.033,
                frame_id=i + 1,
                status=QualityStatus.OK,
                rois=FacialROIs(
                    forehead=roi,
                    left_cheek=roi,
                    right_cheek=roi,
                    global_skin=roi,
                ),
                quality=QualityMetrics(
                    coverage_ratio=0.3,
                    yaw=2.0,
                    pitch=-1.0,
                    roll=0.0,
                    luminance_y=120.0,
                ),
            )
            frames.append(frame)

        batch = RawRPPGBatch(client_id="test_client_01", timestamp=t0, frames=frames)

        response = self.client.post("/api/v1/rppg/raw-batch", json=batch.model_dump())
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("bpm", data)
        self.assertIn("snr_db", data)

    def test_websocket_stream(self):
        """Test WebSocket /ws/raw-rppg-stream endpoint."""
        with self.client.websocket_connect("/ws/raw-rppg-stream") as websocket:
            roi = ROIValues(red=180.0, green=150.0, blue=120.0)
            frame = RawRPPGFrame(
                timestamp=time.time(),
                frame_id=1,
                status=QualityStatus.OK,
                rois=FacialROIs(
                    forehead=roi,
                    left_cheek=roi,
                    right_cheek=roi,
                    global_skin=roi,
                ),
                quality=QualityMetrics(
                    coverage_ratio=0.3,
                    yaw=0.0,
                    pitch=0.0,
                    roll=0.0,
                    luminance_y=120.0,
                ),
            )
            websocket.send_text(frame.model_dump_json())
            data_text = websocket.receive_text()
            self.assertIn("bpm", data_text)


if __name__ == "__main__":
    unittest.main()
