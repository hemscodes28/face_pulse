"""
Vision & ROI Extraction Core with MediaPipe Face Mesh / Face Landmarker and Visual Quality Gates.
Extracts spatial mean RGB values for Forehead, Left Cheek, Right Cheek, and Global Skin ROIs,
and evaluates calibrated head pose, illumination, and frame coverage/alignment quality gates.
"""

import logging
import os
import sys
import time
import urllib.request
import cv2
import numpy as np
import mediapipe as mp
from typing import Dict, Optional, Tuple, List

from schemas import FacialROIs, QualityMetrics, QualityStatus, RawRPPGFrame, ROIValues

logger = logging.getLogger("FaceFeatureExtractor")

MODEL_URL = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
MODEL_FILENAME = "face_landmarker.task"


def ensure_model_file(model_path: str = MODEL_FILENAME) -> str:
    """Ensures face_landmarker.task model is available locally."""
    if not os.path.exists(model_path):
        os.makedirs(os.path.dirname(os.path.abspath(model_path)), exist_ok=True)
        urllib.request.urlretrieve(MODEL_URL, model_path)
    return model_path


class FaceFeatureExtractor:
    """
    MediaPipe Face Landmarker Extractor for rPPG signal acquisition and facial quality validation.
    Supports both MediaPipe Tasks API and legacy solutions API.
    """

    # Calibrated Quality Gate Thresholds for natural webcam positions
    MAX_YAW: float = 25.0         # Maximum allowed yaw angle in degrees (+/-)
    MAX_PITCH: float = 25.0       # Maximum allowed pitch angle in degrees (+/-)
    MAX_ROLL: float = 20.0        # Maximum allowed roll angle in degrees (+/-)

    # Calibrated Alignment & Coverage Gate Thresholds
    MIN_COVERAGE_RATIO: float = 0.03  # Minimum face bbox area / frame area (calibrated for standard desk sitting distance)
    MAX_COVERAGE_RATIO: float = 0.70  # Maximum face bbox area / frame area
    MAX_CENTER_OFFSET_X: float = 0.30 # Maximum allowed horizontal center offset (+/- 30% of frame width)
    MAX_CENTER_OFFSET_Y: float = 0.30 # Maximum allowed vertical center offset (+/- 30% of frame height)

    # Defined Landmark Indices for ROIs (Full Forehead & Anatomical Malar Cheek Patches)
    FOREHEAD_LANDMARKS = [
        10, 338, 297, 332, 284, 251, 389, 356, 139, 71, 68, 104, 69, 108, 
        151, 337, 299, 333, 298, 301, 368, 9, 8, 107, 336, 67, 109, 103, 54, 21, 162
    ]
    LEFT_CHEEK_LANDMARKS = [
        116, 117, 118, 101, 205, 207, 214, 192, 138, 135, 
        210, 211, 34, 143, 226, 31, 50, 186, 92, 165, 206
    ]
    RIGHT_CHEEK_LANDMARKS = [
        345, 346, 347, 330, 425, 427, 434, 416, 367, 364, 
        430, 431, 264, 372, 446, 261, 280, 410, 322, 391, 426
    ]
    FACE_OVAL_LANDMARKS = [
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 
        397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,  
        172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109
    ]

    # Canonical 3D Facial Reference Model Points for solvePnP pose estimation
    # Landmarks: Nose Tip (1), Chin (152), Left Eye Outer (33), Right Eye Outer (263), Left Mouth (61), Right Mouth (291)
    MODEL_POINTS_3D = np.array([
        (0.0, 0.0, 0.0),          # Nose tip (1)
        (0.0, -330.0, -65.0),     # Chin (152)
        (-225.0, 170.0, -135.0),  # Left eye outer corner (33)
        (225.0, 170.0, -135.0),   # Right eye outer corner (263)
        (-150.0, -150.0, -125.0), # Left mouth corner (61)
        (150.0, -150.0, -125.0)   # Right mouth corner (291)
    ], dtype=np.float64)

    POSE_LANDMARK_IDS = [1, 152, 33, 263, 61, 291]

    def __init__(
        self,
        refine_landmarks: bool = True,
        max_num_faces: int = 1,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
        model_path: str = MODEL_FILENAME,
        webcam_pitch_offset: float = 0.0,
    ) -> None:
        """
        Initialize MediaPipe Face Mesh / Face Landmarker.

        :param webcam_pitch_offset: Fixed pitch offset (degrees) for camera elevation calibration.
        """
        self._frame_count: int = 0
        self._use_tasks_api = False
        self.landmarker = None
        self.face_mesh = None
        self.webcam_pitch_offset = webcam_pitch_offset

        # Debug & Visualization State
        self.last_landmarks_2d: Optional[np.ndarray] = None
        self.last_rvec: Optional[np.ndarray] = None
        self.last_tvec: Optional[np.ndarray] = None
        self.last_camera_matrix: Optional[np.ndarray] = None
        self.last_dist_coeffs: Optional[np.ndarray] = None

        # Check if legacy mp.solutions is available
        if hasattr(mp, "solutions") and hasattr(mp.solutions, "face_mesh"):
            self.face_mesh = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=False,
                max_num_faces=max_num_faces,
                refine_landmarks=refine_landmarks,
                min_detection_confidence=min_detection_confidence,
                min_tracking_confidence=min_tracking_confidence,
            )
        else:
            # Use modern MediaPipe Tasks API
            self._use_tasks_api = True
            local_model = ensure_model_file(model_path)
            from mediapipe.tasks.python import vision, BaseOptions

            options = vision.FaceLandmarkerOptions(
                base_options=BaseOptions(model_asset_path=local_model),
                running_mode=vision.RunningMode.IMAGE,
                num_faces=max_num_faces,
                min_face_detection_confidence=min_detection_confidence,
                min_face_presence_confidence=min_tracking_confidence,
            )
            self.landmarker = vision.FaceLandmarker.create_from_options(options)

    def close(self) -> None:
        """Release MediaPipe resources."""
        if self.face_mesh is not None:
            self.face_mesh.close()
        if self.landmarker is not None:
            self.landmarker.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def process_frame(self, frame_bgr: np.ndarray, timestamp: Optional[float] = None) -> RawRPPGFrame:
        """
        Process a single BGR video frame, evaluate quality gates, and extract spatial mean RGBs.

        :param frame_bgr: Input BGR image frame from OpenCV.
        :param timestamp: Optional Unix timestamp for the frame.
        :return: RawRPPGFrame Pydantic object containing status, ROIs, and quality metrics.
        """
        if timestamp is None:
            timestamp = time.time()

        self._frame_count += 1
        h, w, _ = frame_bgr.shape
        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)

        landmarks_list = None

        if self._use_tasks_api:
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
            detection_result = self.landmarker.detect(mp_image)
            if detection_result.face_landmarks and len(detection_result.face_landmarks) > 0:
                landmarks_list = detection_result.face_landmarks[0]
        else:
            results = self.face_mesh.process(frame_rgb)
            if results.multi_face_landmarks and len(results.multi_face_landmarks) > 0:
                landmarks_list = results.multi_face_landmarks[0].landmark

        # 1. Quality Check: NO_FACE
        if landmarks_list is None:
            logger.warning(f"[Frame #{self._frame_count}] No face detected in frame.")
            self.last_landmarks_2d = None
            self.last_rvec = None
            self.last_tvec = None
            self.last_camera_matrix = None
            self.last_dist_coeffs = None
            dummy_roi = ROIValues(red=0.0, green=0.0, blue=0.0)
            return RawRPPGFrame(
                timestamp=timestamp,
                frame_id=self._frame_count,
                status=QualityStatus.NO_FACE,
                rois=FacialROIs(
                    forehead=dummy_roi,
                    left_cheek=dummy_roi,
                    right_cheek=dummy_roi,
                    global_skin=dummy_roi,
                ),
                quality=QualityMetrics(
                    coverage_ratio=0.0,
                    yaw=0.0,
                    pitch=0.0,
                    roll=0.0,
                    luminance_y=0.0,
                ),
            )

        # Extract 2D Landmark Array in pixels
        landmarks_2d = np.array(
            [(int(lm.x * w), int(lm.y * h)) for lm in landmarks_list], dtype=np.int32
        )
        self.last_landmarks_2d = landmarks_2d

        # 2. Quality Check: Head Pose (Yaw, Pitch, Roll) in degrees
        yaw, pitch, roll = self._estimate_head_pose(landmarks_list, w, h)

        # 3. Quality Check: Frame Bounding Box Coverage Ratio & Center Offset
        x_min, y_min = np.min(landmarks_2d, axis=0)
        x_max, y_max = np.max(landmarks_2d, axis=0)
        bbox_area = max(0, x_max - x_min) * max(0, y_max - y_min)
        frame_area = w * h
        coverage_ratio = float(bbox_area / (frame_area + 1e-7))

        x_center = (x_min + x_max) / 2.0
        y_center = (y_min + y_max) / 2.0
        offset_x = abs(x_center - (w / 2.0)) / float(w)
        offset_y = abs(y_center - (h / 2.0)) / float(h)

        # 4. Quality Check: Illumination / Luminance Y channel
        face_mask_oval = self._create_polygon_mask(landmarks_2d[self.FACE_OVAL_LANDMARKS], w, h)
        luminance_y = self._compute_luminance_y(frame_bgr, face_mask_oval)

        # Apply webcam pitch elevation offset calibration
        calibrated_pitch = pitch - self.webcam_pitch_offset

        # Diagnostic Logging for raw head pose angles and visual metrics
        logger.info(
            f"[Frame #{self._frame_count}] Pose Angles -> Yaw: {yaw:.2f}°, Pitch: {pitch:.2f}° (Calibrated: {calibrated_pitch:.2f}°), Roll: {roll:.2f}° | "
            f"Coverage: {coverage_ratio*100:.1f}% | Center Offset X: {offset_x*100:.1f}%, Y: {offset_y*100:.1f}% | Luminance Y: {luminance_y:.1f}"
        )

        # Evaluate Quality Gate Flags against calibrated thresholds
        status = QualityStatus.OK
        if abs(yaw) > self.MAX_YAW or abs(calibrated_pitch) > self.MAX_PITCH or abs(roll) > self.MAX_ROLL:
            status = QualityStatus.BAD_POSE
            logger.warning(
                f"[Frame #{self._frame_count}] BAD_POSE flagged: Yaw={yaw:.1f}° (max {self.MAX_YAW}°), "
                f"Pitch={calibrated_pitch:.1f}° (max {self.MAX_PITCH}°), Roll={roll:.1f}° (max {self.MAX_ROLL}°)"
            )
        elif (
            coverage_ratio < self.MIN_COVERAGE_RATIO
            or coverage_ratio > self.MAX_COVERAGE_RATIO
            or offset_x > self.MAX_CENTER_OFFSET_X
            or offset_y > self.MAX_CENTER_OFFSET_Y
        ):
            status = QualityStatus.FACE_MISALIGNED
            logger.warning(
                f"[Frame #{self._frame_count}] FACE_MISALIGNED flagged: Coverage={coverage_ratio*100:.1f}% (range [{self.MIN_COVERAGE_RATIO*100:.0f}%, {self.MAX_COVERAGE_RATIO*100:.0f}%]), "
                f"OffsetX={offset_x*100:.1f}% (max {self.MAX_CENTER_OFFSET_X*100:.0f}%), OffsetY={offset_y*100:.1f}% (max {self.MAX_CENTER_OFFSET_Y*100:.0f}%)"
            )
        elif luminance_y < 45.0:
            status = QualityStatus.LOW_LIGHT
            logger.warning(f"[Frame #{self._frame_count}] LOW_LIGHT flagged: Y={luminance_y:.1f} < 45")
        elif luminance_y > 230.0:
            status = QualityStatus.OVER_EXPOSED
            logger.warning(f"[Frame #{self._frame_count}] OVER_EXPOSED flagged: Y={luminance_y:.1f} > 230")

        # 5. Extract Spatial Means across ROIs (BGR -> RGB)
        forehead_mask = self._create_polygon_mask(landmarks_2d[self.FOREHEAD_LANDMARKS], w, h)
        left_cheek_mask = self._create_polygon_mask(landmarks_2d[self.LEFT_CHEEK_LANDMARKS], w, h)
        right_cheek_mask = self._create_polygon_mask(landmarks_2d[self.RIGHT_CHEEK_LANDMARKS], w, h)

        forehead_rgb = self._extract_mean_rgb(frame_rgb, forehead_mask)
        left_cheek_rgb = self._extract_mean_rgb(frame_rgb, left_cheek_mask)
        right_cheek_rgb = self._extract_mean_rgb(frame_rgb, right_cheek_mask)
        global_skin_rgb = self._extract_mean_rgb(frame_rgb, face_mask_oval)

        return RawRPPGFrame(
            timestamp=timestamp,
            frame_id=self._frame_count,
            status=status,
            rois=FacialROIs(
                forehead=forehead_rgb,
                left_cheek=left_cheek_rgb,
                right_cheek=right_cheek_rgb,
                global_skin=global_skin_rgb,
            ),
            quality=QualityMetrics(
                coverage_ratio=round(coverage_ratio, 4),
                yaw=round(yaw, 2),
                pitch=round(calibrated_pitch, 2),
                roll=round(roll, 2),
                luminance_y=round(luminance_y, 2),
            ),
        )

    def extract(self, frame_bgr: np.ndarray, timestamp: Optional[float] = None) -> RawRPPGFrame:
        """Alias for process_frame."""
        return self.process_frame(frame_bgr, timestamp)

    def _create_polygon_mask(self, points: np.ndarray, w: int, h: int) -> np.ndarray:
        """Creates a binary mask using convex hull of landmark points."""
        mask = np.zeros((h, w), dtype=np.uint8)
        if len(points) >= 3:
            hull = cv2.convexHull(points)
            cv2.fillConvexPoly(mask, hull, 255)
        return mask

    def _extract_mean_rgb(self, frame_rgb: np.ndarray, mask: np.ndarray) -> ROIValues:
        """Computes the mean R, G, B channel values over non-zero mask pixels."""
        mean_val = cv2.mean(frame_rgb, mask=mask)[:3]
        return ROIValues(
            red=float(mean_val[0]),
            green=float(mean_val[1]),
            blue=float(mean_val[2]),
        )

    def _compute_luminance_y(self, frame_bgr: np.ndarray, mask: np.ndarray) -> float:
        """Computes mean luminance Y channel in YUV space across facial mask."""
        frame_yuv = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2YUV)
        y_channel = frame_yuv[:, :, 0]
        mean_y = cv2.mean(y_channel, mask=mask)[0]
        return float(mean_y)

    def _estimate_head_pose(self, face_landmarks, w: int, h: int) -> Tuple[float, float, float]:
        """
        Estimates Yaw, Pitch, Roll head rotation angles in degrees using cv2.solvePnP + cv2.RQDecomp3x3.
        Landmarks mapped: Nose Tip (1), Chin (152), Left Eye Outer (33), Right Eye Outer (263), Left Mouth (61), Right Mouth (291).
        """
        image_points = np.array([
            (face_landmarks[idx].x * w, face_landmarks[idx].y * h)
            for idx in self.POSE_LANDMARK_IDS
        ], dtype=np.float64)

        focal_length = w
        center = (w / 2.0, h / 2.0)
        camera_matrix = np.array([
            [focal_length, 0, center[0]],
            [0, focal_length, center[1]],
            [0, 0, 1]
        ], dtype=np.float64)

        dist_coeffs = np.zeros((4, 1), dtype=np.float64)

        success, rvec, tvec = cv2.solvePnP(
            self.MODEL_POINTS_3D,
            image_points,
            camera_matrix,
            dist_coeffs,
            flags=cv2.SOLVEPNP_ITERATIVE,
        )

        if not success:
            self.last_rvec = None
            self.last_tvec = None
            self.last_camera_matrix = None
            self.last_dist_coeffs = None
            return 0.0, 0.0, 0.0

        self.last_rvec = rvec
        self.last_tvec = tvec
        self.last_camera_matrix = camera_matrix
        self.last_dist_coeffs = dist_coeffs

        # Convert rotation vector to rotation matrix
        rmat, _ = cv2.Rodrigues(rvec)

        # Decompose rotation matrix into Euler angles (pitch, yaw, roll) using cv2.RQDecomp3x3
        angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)
        pitch, yaw, roll = angles[0], angles[1], angles[2]

        # Normalize solvePnP pitch around 0 deg (base solvePnP orientation is ~180 deg)
        if pitch > 90.0:
            pitch -= 180.0
        elif pitch < -90.0:
            pitch += 180.0

        # Normalize roll around 0 deg
        if roll > 90.0:
            roll -= 180.0
        elif roll < -90.0:
            roll += 180.0

        return float(yaw), float(pitch), float(roll)
