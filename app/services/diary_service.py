from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from app.schemas.diary_schema import DiaryRecord, DiaryDateResponse
from app.services.diary_store import diary_records

def add_diary_entry(
    user_id: str, 
    measurement_id: str, 
    recorded_at: Optional[datetime] = None, 
    heart_rate: Optional[float] = None,
    hr: Optional[float] = None, 
    spo2: Optional[float] = 98.0, 
    systolic: Optional[int] = 120,
    diastolic: Optional[int] = 80,
    bp_str: Optional[str] = None,
    hr_series: Optional[List[float]] = None,
    spo2_series: Optional[List[float]] = None,
    bp_series: Optional[List[List[float]]] = None,
    **kwargs
) -> DiaryRecord:
    """
    Creates a DiaryRecord with BPM time-series data and appends it to diary_store.
    Supports flexible keyword arguments.
    """
    final_hr = float(heart_rate if heart_rate is not None else (hr if hr is not None else 72.0))
    final_recorded_at = recorded_at or datetime.now(timezone.utc)
    
    final_systolic = systolic if systolic is not None else 120
    final_diastolic = diastolic if diastolic is not None else 80
    
    if bp_str and "/" in bp_str:
        try:
            parts = bp_str.split("/")
            final_systolic = int(parts[0].strip())
            final_diastolic = int(parts[1].strip())
        except (ValueError, IndexError):
            pass

    record = DiaryRecord(
        user_id=user_id,
        measurement_id=measurement_id,
        recorded_at=final_recorded_at,
        heart_rate=round(final_hr, 1),
        spo2=float(spo2 if spo2 is not None else 98.0),
        systolic=final_systolic,
        diastolic=final_diastolic,
        hr_series=hr_series or [],
        spo2_series=spo2_series or [],
        bp_series=bp_series or []
    )
    
    # Store record
    diary_records.append(record.model_dump())
    return record


def get_user_diary_by_date(user_id: str, date_str: str) -> DiaryDateResponse:
    """
    Retrieves all diary records for the given user_id matching the YYYY-MM-DD date_str.
    """
    user_measurements: List[DiaryRecord] = []
    
    for entry in diary_records:
        if entry["user_id"] != user_id:
            continue
            
        rec_at = entry["recorded_at"]
        if isinstance(rec_at, datetime):
            rec_date_str = rec_at.strftime("%Y-%m-%d")
        elif isinstance(rec_at, str):
            rec_date_str = rec_at[:10]
        else:
            rec_date_str = ""
            
        if rec_date_str == date_str:
            user_measurements.append(DiaryRecord(**entry))
            
    return DiaryDateResponse(
        date=date_str,
        measurements=user_measurements
    )
