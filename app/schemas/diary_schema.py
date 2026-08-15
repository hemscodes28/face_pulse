from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class DiaryRecord(BaseModel):
    user_id: str = "user_default"
    measurement_id: str
    recorded_at: datetime
    heart_rate: float
    spo2: float = 98.0
    systolic: int = 120
    diastolic: int = 80
    hrv: int = 48
    breath: int = 16
    respiratory_health: int = 95
    quality_stars: int = 5
    quality_label: str = "Good Video Quality"
    hr_series: List[float] = Field(default_factory=list, description="Heart rate values over time")
    spo2_series: List[float] = Field(default_factory=list, description="SpO2 values over time")

class DiaryDateResponse(BaseModel):
    date: str = Field(..., description="Date string in YYYY-MM-DD format")
    measurements: List[DiaryRecord]

class DiaryHistoryResponse(BaseModel):
    count: int
    measurements: List[DiaryRecord]

class DiaryEntryCreateRequest(BaseModel):
    user_id: Optional[str] = "user_default"
    measurement_id: Optional[str] = None
    heart_rate: float
    spo2: Optional[float] = 98.0
    systolic: Optional[int] = 120
    diastolic: Optional[int] = 80
    hrv: Optional[int] = 48
    breath: Optional[int] = 16
    respiratory_health: Optional[int] = 95
    quality_stars: Optional[int] = 5
    quality_label: Optional[str] = "Good Video Quality"
    recorded_at: Optional[datetime] = None
