from pydantic import BaseModel, Field
from typing import List
from datetime import datetime

class DiaryRecord(BaseModel):
    user_id: str
    measurement_id: str
    recorded_at: datetime
    heart_rate: float
    spo2: float
    systolic: int
    diastolic: int
    # Time-series data accumulated during the measurement (one entry per ~1s update)
    hr_series: List[float] = Field(default_factory=list, description="Heart rate values over time")
    spo2_series: List[float] = Field(default_factory=list, description="SpO2 values over time")
    bp_series: List[List[float]] = Field(default_factory=list, description="BP waveform points per update")

class DiaryDateResponse(BaseModel):
    date: str = Field(..., description="Date string in YYYY-MM-DD format")
    measurements: List[DiaryRecord]
