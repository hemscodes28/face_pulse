"""
FacePulseEngine Data Schemas
Defines Pydantic models and Enums for raw ROI streaming and processed rPPG metrics.
"""

from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


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
