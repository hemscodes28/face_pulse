from datetime import datetime, timezone
from typing import List, Dict, Any
from app.schemas.diary_schema import DiaryRecord, DiaryDateResponse
from app.services.diary_store import diary_records

def add_diary_entry(
    user_id: str, 
    measurement_id: str, 
    recorded_at: datetime, 
    hr: float, 
    spo2: float, 
    bp_str: str,
    hr_series: List[float] = None,
    spo2_series: List[float] = None,
    bp_series: List[List[float]] = None
) -> DiaryRecord:
    """
    Parses blood pressure string (e.g. "120/80"), creates a DiaryRecord with
    time-series graph data, and saves it to the in-memory diary_store.
    """
    systolic = 120
    diastolic = 80
    
    if bp_str and "/" in bp_str:
        try:
            parts = bp_str.split("/")
            systolic = int(parts[0].strip())
            diastolic = int(parts[1].strip())
        except (ValueError, IndexError):
            pass

    record = DiaryRecord(
        user_id=user_id,
        measurement_id=measurement_id,
        recorded_at=recorded_at,
        heart_rate=float(hr),
        spo2=float(spo2),
        systolic=systolic,
        diastolic=diastolic,
        hr_series=hr_series or [],
        spo2_series=spo2_series or [],
        bp_series=bp_series or []
    )
    
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
