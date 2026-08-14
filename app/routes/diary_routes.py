from fastapi import APIRouter, Depends, Query
from app.schemas.diary_schema import DiaryDateResponse
from app.services.auth_service import get_current_user
from app.services.diary_service import get_user_diary_by_date

router = APIRouter(
    prefix="/api/v1/diary",
    tags=["Vitals Diary"]
)

@router.get("", response_model=DiaryDateResponse)
def get_diary(
    date: str = Query(..., description="Target date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user["user_id"]
    return get_user_diary_by_date(user_id=user_id, date_str=date)
