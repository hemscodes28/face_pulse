from fastapi import APIRouter, Depends, Query
from app.schemas.diary_schema import DiaryDateResponse, DiaryHistoryResponse, DiaryEntryCreateRequest, DiaryRecord
from app.services.diary_service import get_user_diary_by_date, get_all_user_diary_records, add_diary_entry

router = APIRouter(
    prefix="/api/v1/diary",
    tags=["Vitals Diary"]
)

@router.get("", response_model=DiaryDateResponse)
def get_diary(
    date: str = Query("recent", description="Target date in YYYY-MM-DD format")
):
    return get_user_diary_by_date(user_id="user_default", date_str=date)

@router.get("/history", response_model=DiaryHistoryResponse)
def get_diary_history(
    user_id: str = Query("user_default", description="User ID")
):
    return get_all_user_diary_records(user_id=user_id)

@router.post("/entry", response_model=DiaryRecord)
def create_diary_entry(payload: DiaryEntryCreateRequest):
    return add_diary_entry(
        user_id=payload.user_id or "user_default",
        measurement_id=payload.measurement_id,
        recorded_at=payload.recorded_at,
        heart_rate=payload.heart_rate,
        spo2=payload.spo2,
        systolic=payload.systolic,
        diastolic=payload.diastolic,
        hrv=payload.hrv,
        breath=payload.breath,
        respiratory_health=payload.respiratory_health,
        quality_stars=payload.quality_stars,
        quality_label=payload.quality_label,
    )
