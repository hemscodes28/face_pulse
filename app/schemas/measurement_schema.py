from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field
from datetime import datetime
from app.models.enums import MeasurementStatus, SignalQualityLevelEnum

class DeviceInfo(BaseModel):
    platform: str = Field(..., description="Device platform (e.g., iOS, Android, Web).")
    camera: str = Field(..., description="Camera being used (e.g., front, back).")

class MeasurementStartRequest(BaseModel):
    user_id: str = Field(..., description="Unique identifier for the user starting the measurement.")
    device: DeviceInfo = Field(..., description="Device information.")

class MeasurementStartResponse(BaseModel):
    measurement_id: str = Field(..., description="Unique UUID for the measurement session.")
    status: MeasurementStatus = Field(..., description="Status of the measurement session.")
    message: str = Field(..., description="Human-readable message.")
    started_at: datetime = Field(..., description="UTC timestamp of when the session was created.")

# ── Model Ingestion Payload (Simple format) ────────────────────
class ModelIngestPayload(BaseModel):
    type: str = "measurement"
    session_id: str
    frame: Optional[int] = None
    status: str = "OK"
    bpm: float
    snr_db: float
    luminance: float

# ── Structured Ingestion Models (from face_pulse-Model/schemas.py)
class MeasurementRGB(BaseModel):
    r: float = Field(..., description="Mean Red channel value")
    g: float = Field(..., description="Mean Green channel value")
    b: float = Field(..., description="Mean Blue channel value")

class MeasurementSignal(BaseModel):
    bpm: float = Field(..., description="Heart rate in Beats Per Minute (BPM)")
    snr_db: float = Field(..., description="Signal-to-Noise Ratio in dB")
    rgb_mean: Optional[MeasurementRGB] = None
    luminance: float = Field(..., description="Calculated luminance Y channel")

class MeasurementRequest(BaseModel):
    session_id: str = Field(..., description="Unique scan session ID")
    timestamp: Optional[datetime] = None
    frame_number: Optional[int] = 0
    status: str = Field(default="OK", description="Frame quality status")
    signal: MeasurementSignal = Field(..., description="Measurement signal metrics")

class MeasurementDataEcho(BaseModel):
    frame_number: int
    status: str
    bpm: float
    snr_db: float
    rgb_mean: Optional[MeasurementRGB] = None
    luminance: float
    timestamp: Optional[datetime] = None

class MeasurementResponse(BaseModel):
    success: bool = True
    measurement_id: str
    session_id: str
    measurement: MeasurementDataEcho
    vitals: Optional[Dict[str, Any]] = None

# ── WebSocket Live Telemetry Output ────────────────────────────
class LiveQualityInfo(BaseModel):
    snr_db: float
    signal_quality: str   # EXCELLENT | GOOD | FAIR | POOR
    luminance: float
    video_quality: str    # TOO_DARK | GOOD | TOO_BRIGHT

class LiveMeasurementData(BaseModel):
    type: str = "live_measurement"
    measurement_id: str
    bpm: float
    quality: LiveQualityInfo
    recommendation: str
    elapsed_time_sec: Optional[float] = None
    status: Optional[str] = "MEASURING"

# ── Detailed Interpretations Schema ───────────────────────────
class MeasurementInterpretations(BaseModel):
    luminance_suggestion: str
    snr_suggestion: str
    frame_suggestion: str
    rescan_recommended: bool
    rescan_reason: Optional[str] = None
    cardiac_status: str

# ── Final Measurement Result Schema ────────────────────────────
class MeasurementResult(BaseModel):
    id: Optional[str] = None
    measurement_id: str
    status: MeasurementStatus = MeasurementStatus.COMPLETED
    duration_sec: Optional[float] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    
    # Real rPPG Core Outputs
    bpm: Optional[float] = None
    average_bpm: Optional[float] = None
    min_bpm: Optional[float] = None
    max_bpm: Optional[float] = None
    hr_range: Optional[float] = None
    hrv_ms: Optional[float] = None
    hr_zone: Optional[str] = None
    stress_index: Optional[str] = None
    bpm_trend: List[float] = Field(default_factory=list)
    
    # Quality & Environmental Metrics
    avg_snr_db: Optional[float] = None
    signal_quality: Optional[str] = None
    avg_luminance: Optional[float] = None
    video_quality: Optional[str] = None
    recommendation: Optional[str] = None
    
    # Granular Interpretations & Rescan Flag
    interpretations: Optional[MeasurementInterpretations] = None
    
    # Backward/UI Compatibility Fields
    heart_rate_bpm: Optional[float] = None
    signal_quality_score: Optional[float] = None
    signal_quality_level: Optional[SignalQualityLevelEnum] = None
    analysis: Optional[Any] = None
    vitals: Optional[Dict[str, Any]] = None
    quality_summary: Optional[Dict[str, Any]] = None


# ── Visual Debugger / Measurement Runtime Schemas ──────────────────────────

class DebuggerStartResponse(BaseModel):
    """Response for POST /api/measurements/start"""
    measurement_id: str = Field(..., description="Unique ID for this measurement run")
    status: str = Field(default="started", description="Always 'started'")


class DebuggerLatestResult(BaseModel):
    """Response for GET /api/measurements/{measurement_id}/latest"""
    measurement_id: str
    frame: Optional[int] = Field(None, description="Latest processed frame index")
    status: Optional[str] = Field(None, description="'OK', 'NO_FACE', 'WAITING', etc.")
    bpm: Optional[float] = Field(None, description="Heart rate in BPM (null during warmup)")
    luminance: Optional[float] = Field(None, description="Luminance Y (null during warmup)")
    snr: Optional[float] = Field(None, description="Signal-to-Noise Ratio in dB (null during warmup)")
    timestamp: Optional[str] = Field(None, description="ISO-8601 UTC timestamp of last update")


class DebuggerStopResponse(BaseModel):
    """Response for POST /api/measurements/{measurement_id}/stop"""
    measurement_id: str
    status: str = Field(default="completed")
    bpm: Optional[float] = None
    luminance: Optional[float] = None
    snr: Optional[float] = None
