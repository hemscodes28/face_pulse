from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class UserRecord(BaseModel):
    user_id: str
    full_name: str
    email: str
    password_hash: str
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    bmi: Optional[float] = None
    blood_group: Optional[str] = None
    onboarding_completed: bool = False
    created_at: datetime
    updated_at: datetime

class ProfileBasicUpdateRequest(BaseModel):
    date_of_birth: str = Field(..., description="YYYY-MM-DD format")
    gender: str = Field(..., description="e.g., Male, Female, Other")

class ProfileBodyUpdateRequest(BaseModel):
    height: float = Field(..., description="Height in meters (e.g. 1.75)")
    weight: float = Field(..., description="Weight in kg (e.g. 70.5)")

class ProfileMedicalUpdateRequest(BaseModel):
    blood_group: str = Field(..., description="Allowed: A+, A-, B+, B-, AB+, AB-, O+, O-")

class UserProfileResponse(BaseModel):
    user_id: str
    full_name: str
    email: str
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    bmi: Optional[float] = None
    blood_group: Optional[str] = None
    onboarding_completed: bool
    created_at: datetime
    updated_at: datetime
