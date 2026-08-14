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

class MeasurementQuality(BaseModel):
    overall_score: float
    status: str
    lighting: float
    face_position: Dict[str, float]
    face_detected: bool

class LiveMeasurementData(BaseModel):
    measurement_id: str
    elapsed_time_sec: float
    quality: MeasurementQuality
    instruction: str
    hr: Optional[float] = None
    spo2: Optional[float] = None
    bp: Optional[Any] = None  # Live points

class MeasurementResult(BaseModel):
    id: Optional[str] = None
    measurement_id: str
    status: MeasurementStatus = MeasurementStatus.COMPLETED
    duration_sec: Optional[float] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    
    # Cardiovascular Metrics
    heart_rate_bpm: Optional[float] = None
    systolic_bp_mmhg: Optional[float] = None
    diastolic_bp_mmhg: Optional[float] = None
    hrv_ms: Optional[float] = None
    
    # Respiratory & ANS
    breathing_rate_bpm: Optional[float] = None
    stress_index: Optional[float] = None
    cardiac_workload: Optional[float] = None
    parasympathetic_activity_percent: Optional[float] = None
    
    # Body Composition
    bmi: Optional[float] = None
    bmi_classification: Optional[str] = None
    
    # Signal Quality
    signal_quality_score: Optional[float] = None
    signal_quality_level: Optional[SignalQualityLevelEnum] = None
    rescan_recommended: bool = False
    quality_message: Optional[str] = None
    
    # Structured Interpretation
    analysis: Optional[Any] = None
    
    # Model Provenance
    model_name: Optional[str] = None
    model_version: Optional[str] = None
    processed_at: Optional[datetime] = None
    
    # UI Compatibility Fields
    vitals: Optional[Dict[str, Any]] = None
    quality_summary: Optional[Dict[str, Any]] = None
