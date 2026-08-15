from datetime import datetime, timezone
import uuid
from typing import List, Dict, Any, Optional
from app.schemas.diary_schema import DiaryRecord, DiaryDateResponse, DiaryHistoryResponse
from app.services.diary_store import diary_records

def add_diary_entry(
    user_id: str, 
    measurement_id: Optional[str] = None, 
    recorded_at: Optional[datetime] = None, 
    heart_rate: Optional[float] = None,
    hr: Optional[float] = None, 
    spo2: Optional[float] = 98.0, 
    systolic: Optional[int] = 120,
    diastolic: Optional[int] = 80,
    hrv: Optional[int] = 48,
    breath: Optional[int] = 16,
    respiratory_health: Optional[int] = 95,
    quality_stars: Optional[int] = 5,
    quality_label: Optional[str] = "Good Video Quality",
    **kwargs
) -> DiaryRecord:
    final_hr = float(heart_rate if heart_rate is not None else (hr if hr is not None else 72.0))
    final_recorded_at = recorded_at or datetime.now(timezone.utc)
    
    record = DiaryRecord(
        user_id=user_id,
        measurement_id=measurement_id or str(uuid.uuid4()),
        recorded_at=final_recorded_at,
        heart_rate=round(final_hr, 1),
        spo2=float(spo2 if spo2 is not None else 98.0),
        systolic=systolic or 120,
        diastolic=diastolic or 80,
        hrv=hrv or 48,
        breath=breath or 16,
        respiratory_health=respiratory_health or 95,
        quality_stars=quality_stars or 5,
        quality_label=quality_label or "Good Video Quality",
    )
    
    diary_records.append(record.model_dump())
    return record


def get_all_user_diary_records(user_id: str) -> DiaryHistoryResponse:
    user_measurements: List[DiaryRecord] = []
    
    for entry in diary_records:
        user_measurements.append(DiaryRecord(**entry))
            
    user_measurements.sort(key=lambda x: x.recorded_at)
    return DiaryHistoryResponse(
        count=len(user_measurements),
        measurements=user_measurements
    )


def get_user_diary_by_date(user_id: str, date_str: str) -> DiaryDateResponse:
    user_measurements: List[DiaryRecord] = []
    
    for entry in diary_records:
        rec_at = entry["recorded_at"]
        if isinstance(rec_at, datetime):
            rec_date_str = rec_at.strftime("%Y-%m-%d")
        elif isinstance(rec_at, str):
            rec_date_str = rec_at[:10]
        else:
            rec_date_str = ""
            
        if rec_date_str == date_str or date_str in ["all", "recent"]:
            user_measurements.append(DiaryRecord(**entry))
            
    return DiaryDateResponse(
        date=date_str,
        measurements=user_measurements
    )
