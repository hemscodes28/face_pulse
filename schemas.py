"""
FacePulseEngine Data Schemas
Defines Pydantic models and Enums for raw ROI streaming, processed rPPG metrics,
and JSON measurement push endpoints.
"""

from datetime import datetime
from enum import Enum
import math
from typing import Dict, List, Optional
from pydantic import BaseModel, Field, field_validator


class QualityStatus(str, Enum):
    OK = "OK"
    NO_FACE = "NO_FACE"
    BAD_POSE = "BAD_POSE"
    FACE_MISALIGNED = "FACE_MISALIGNED"
    LOW_LIGHT = "LOW_LIGHT"
    OVER_EXPOSED = "OVER_EXPOSED"


class ROIValues(BaseModel):
    red: float = Field(..., description="Mean Red channel value")
    green: float = Field(..., description="Mean Green channel value")
    blue: float = Field(..., description="Mean Blue channel value")


class FacialROIs(BaseModel):
    forehead: ROIValues
    left_cheek: ROIValues
    right_cheek: ROIValues
    global_skin: ROIValues


class QualityMetrics(BaseModel):
    coverage_ratio: float = Field(..., description="Face bounding box area relative to frame area")
    yaw: float = Field(..., description="Estimated head yaw angle in degrees")
    pitch: float = Field(..., description="Estimated head pitch angle in degrees")
    roll: float = Field(..., description="Estimated head roll angle in degrees")
    luminance_y: float = Field(..., description="Mean luminance Y channel in YUV space")


class RawRPPGFrame(BaseModel):
    timestamp: float = Field(..., description="Unix timestamp of frame capture")
    frame_id: int = Field(..., description="Sequential frame index")
    status: QualityStatus = Field(..., description="Frame quality gate status")
    rois: FacialROIs = Field(..., description="Extracted facial ROI spatial RGB means")
    quality: QualityMetrics = Field(..., description="Detailed visual quality metrics")


class RawRPPGBatch(BaseModel):
    client_id: str = Field(default="default_client", description="Unique client stream ID")
    timestamp: float = Field(..., description="Batch creation timestamp")
    frames: List[RawRPPGFrame] = Field(..., description="List of raw frame payloads")


class ProcessedRPPGMetrics(BaseModel):
    timestamp: float = Field(..., description="Timestamp of metric calculation")
    bpm: float = Field(..., description="Estimated Heart Rate in Beats Per Minute (BPM)")
    snr_db: float = Field(..., description="Signal-to-Noise Ratio in dB")
    signal_quality: float = Field(..., description="Normalized quality score between 0.0 and 1.0")
    status: QualityStatus = Field(..., description="Current frame/buffer quality status")
    pulse_waveform: List[float] = Field(default_factory=list, description="Recent filtered pulse signal values")


# ==================================================
# MEASUREMENT PUSH SCHEMAS
# ==================================================


class MeasurementRGB(BaseModel):
    r: float = Field(..., description="Mean Red channel value")
    g: float = Field(..., description="Mean Green channel value")
    b: float = Field(..., description="Mean Blue channel value")

    @field_validator("r", "g", "b")
    @classmethod
    def check_finite(cls, v: float) -> float:
        if not math.isfinite(v):
            raise ValueError("RGB values must be finite numbers")
        return v


class MeasurementSignal(BaseModel):
    bpm: float = Field(..., description="Heart rate in Beats Per Minute (BPM)")
    snr_db: float = Field(..., description="Signal-to-Noise Ratio in dB")
    rgb_mean: MeasurementRGB = Field(..., description="Mean RGB color channels")
    luminance: float = Field(..., description="Calculated luminance Y channel")

    @field_validator("bpm")
    @classmethod
    def check_bpm(cls, v: float) -> float:
        if not math.isfinite(v) or v < 0:
            raise ValueError("bpm must be >= 0 and finite")
        return v

    @field_validator("snr_db")
    @classmethod
    def check_snr(cls, v: float) -> float:
        if not math.isfinite(v):
            raise ValueError("snr_db must be a finite number")
        return v

    @field_validator("luminance")
    @classmethod
    def check_luminance(cls, v: float) -> float:
        if not math.isfinite(v):
            raise ValueError("luminance must be a finite number")
        return v


class MeasurementRequest(BaseModel):
    session_id: str = Field(..., description="Unique scan session ID")
    timestamp: datetime = Field(..., description="Measurement ISO timestamp")
    frame_number: int = Field(..., description="Sequential frame index")
    status: str = Field(..., description="Frame quality status (normally OK)")
    signal: MeasurementSignal = Field(..., description="Measurement signal metrics")

    @field_validator("session_id")
    @classmethod
    def check_session_id(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("session_id must not be empty")
        return v

    @field_validator("frame_number")
    @classmethod
    def check_frame_number(cls, v: int) -> int:
        if v < 0:
            raise ValueError("frame_number must be >= 0")
        return v


class MeasurementDataEcho(BaseModel):
    frame_number: int
    status: str
    bpm: float
    snr_db: float
    rgb_mean: MeasurementRGB
    luminance: float
    timestamp: datetime


class MeasurementResponse(BaseModel):
    success: bool = True
    measurement_id: str
    session_id: str
    measurement: MeasurementDataEcho
    vitals: Optional[Dict] = None
