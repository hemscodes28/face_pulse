from typing import Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime

class DeviceInfo(BaseModel):
    platform: str = Field(..., description="Device platform (e.g., iOS, Android, Web).")
    camera: str = Field(..., description="Camera being used (e.g., front, back).")

class MeasurementStartRequest(BaseModel):
    user_id: str = Field(..., description="Unique identifier for the user starting the measurement.")
    device: DeviceInfo = Field(..., description="Device information.")

class MeasurementStartResponse(BaseModel):
    measurement_id: str = Field(..., description="Unique UUID for the measurement session.")
    status: str = Field(..., description="Status of the measurement session.")
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
    bp: Optional[Any] = None  # Mock graph points


class MeasurementResult(BaseModel):
    measurement_id: str
    status: str
    duration_sec: float
    vitals: Dict[str, Any]
    quality_summary: Dict[str, Any]
    analysis: str
