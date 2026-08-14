from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from app.models.enums import GenderEnum, BloodGroupEnum, UserRole

class UserRecord(BaseModel):
    user_id: str
    full_name: str
    email: str
    password_hash: str
    role: UserRole = UserRole.USER
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    bmi: Optional[float] = None
    bmi_classification: Optional[str] = None
    blood_group: Optional[str] = None
    onboarding_completed: bool = False
    created_at: datetime
    updated_at: datetime

class ProfileBasicUpdateRequest(BaseModel):
    date_of_birth: str = Field(..., description="YYYY-MM-DD format")
    gender: GenderEnum = Field(..., description="MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY")

class ProfileBodyUpdateRequest(BaseModel):
    height_cm: float = Field(..., gt=0, description="Height in centimeters (e.g. 175.0)")
    weight_kg: float = Field(..., gt=0, description="Weight in kg (e.g. 70.5)")

class ProfileMedicalUpdateRequest(BaseModel):
    blood_group: BloodGroupEnum = Field(..., description="A+, A-, B+, B-, AB+, AB-, O+, O-")

class FullProfileUpdateRequest(BaseModel):
    date_of_birth: str = Field(..., description="YYYY-MM-DD format")
    gender: GenderEnum
    height_cm: float = Field(..., gt=0)
    weight_kg: float = Field(..., gt=0)
    blood_group: BloodGroupEnum

class UserProfileResponse(BaseModel):
    user_id: str
    full_name: str
    email: str
    role: UserRole = UserRole.USER
    date_of_birth: Optional[str] = None
    gender: Optional[GenderEnum] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    bmi: Optional[float] = None
    bmi_classification: Optional[str] = None
    blood_group: Optional[BloodGroupEnum] = None
    onboarding_completed: bool = False
    created_at: datetime
    updated_at: datetime
