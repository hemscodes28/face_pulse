import uuid
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field
from app.models.enums import MeasurementStatus, SignalQualityLevelEnum

class Measurement(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    status: MeasurementStatus = MeasurementStatus.READY
    started_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    completed_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class MeasurementResult(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    measurement_id: str
    
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
    
    # Analysis & Interpretations
    analysis: Optional[Dict[str, Any]] = None
    
    # Model Provenance
    model_name: Optional[str] = "FacePulse-rPPG-Core"
    model_version: Optional[str] = "v1.2.0"
    processed_at: Optional[datetime] = None
    
    # Audit Timestamps
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
