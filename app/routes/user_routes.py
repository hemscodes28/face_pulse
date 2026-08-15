from fastapi import APIRouter, Depends, HTTPException
from typing import Any

router = APIRouter(
    prefix="/api/v1/users",
    tags=["User & Onboarding"]
)

from app.schemas.user_schema import ProfileBasicUpdateRequest, ProfileBodyUpdateRequest, ProfileMedicalUpdateRequest, UserProfileResponse
from app.services.auth_service import get_current_user
import app.services.onboarding_service as onboarding_service

def verify_user_access(user_id: str, current_user: dict = Depends(get_current_user)):
    if current_user["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this user's profile")
    return current_user

@router.put("/{user_id}/profile/basic", response_model=UserProfileResponse)
def update_basic(user_id: str, request: ProfileBasicUpdateRequest, current_user: dict = Depends(verify_user_access)):
    return onboarding_service.update_basic_profile(user_id, request)

@router.put("/{user_id}/profile/body", response_model=UserProfileResponse)
def update_body(user_id: str, request: ProfileBodyUpdateRequest, current_user: dict = Depends(verify_user_access)):
    return onboarding_service.update_body_profile(user_id, request)

@router.put("/{user_id}/profile/medical", response_model=UserProfileResponse)
def update_medical(user_id: str, request: ProfileMedicalUpdateRequest, current_user: dict = Depends(verify_user_access)):
    return onboarding_service.update_medical_profile(user_id, request)

@router.post("/{user_id}/onboarding/complete", response_model=UserProfileResponse)
def complete_onboarding(user_id: str, current_user: dict = Depends(verify_user_access)):
    return onboarding_service.complete_onboarding(user_id)

@router.get("/{user_id}/profile", response_model=UserProfileResponse)
def get_profile(user_id: str, current_user: dict = Depends(verify_user_access)):
    return current_user
