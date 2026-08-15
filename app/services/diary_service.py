from datetime import datetime, timezone
import uuid
import sqlite3
from typing import List, Dict, Any, Optional
from app.schemas.diary_schema import DiaryRecord, DiaryDateResponse, DiaryHistoryResponse
from app.services.diary_store import diary_records
from app.services.user_store import users, get_db_connection


def resolve_effective_user_id(requested_user_id: Optional[str]) -> str:
    """Resolves requested_user_id to the active logged-in user ID if user_default or empty."""
    if requested_user_id and requested_user_id != "user_default":
        return requested_user_id
    default_user = users.get("user_default") or users.get("user_hemkumar")
    if default_user:
        return default_user.get("user_id", "user_hemkumar")
    return "user_hemkumar"


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
    final_user_id = resolve_effective_user_id(user_id)
    final_hr = float(heart_rate if heart_rate is not None else (hr if hr is not None else 72.0))
    final_recorded_at = recorded_at or datetime.now(timezone.utc)
    final_meas_id = measurement_id or str(uuid.uuid4())
    
    record = DiaryRecord(
        user_id=final_user_id,
        measurement_id=final_meas_id,
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
    
    dict_record = record.model_dump()
    diary_records.append(dict_record)

    # Persist entry to local SQLite DB
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        rec_at_str = final_recorded_at.isoformat() if isinstance(final_recorded_at, datetime) else str(final_recorded_at)
        cursor.execute("""
            INSERT INTO local_diary (
                user_id, measurement_id, recorded_at, heart_rate, spo2,
                systolic, diastolic, hrv, breath, respiratory_health,
                quality_stars, quality_label
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            final_user_id, final_meas_id, rec_at_str, round(final_hr, 1),
            float(spo2 or 98.0), systolic or 120, diastolic or 80, hrv or 48,
            breath or 16, respiratory_health or 95, quality_stars or 5,
            quality_label or "Good Video Quality"
        ))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Error persisting diary entry to SQLite DB: {e}")

    return record


def get_all_user_diary_records(user_id: str) -> DiaryHistoryResponse:
    target_user_id = resolve_effective_user_id(user_id)
    user_measurements: List[DiaryRecord] = []
    
    for entry in diary_records:
        if entry.get("user_id") == target_user_id:
            user_measurements.append(DiaryRecord(**entry))
            
    user_measurements.sort(key=lambda x: x.recorded_at)
    return DiaryHistoryResponse(
        count=len(user_measurements),
        measurements=user_measurements
    )


def get_user_diary_by_date(user_id: str, date_str: str) -> DiaryDateResponse:
    target_user_id = resolve_effective_user_id(user_id)
    user_measurements: List[DiaryRecord] = []
    
    for entry in diary_records:
        if entry.get("user_id") != target_user_id:
            continue
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
