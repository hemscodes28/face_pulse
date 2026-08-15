from pydantic import BaseModel, Field, model_validator
from typing import Optional, Any
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

    @model_validator(mode="before")
    @classmethod
    def normalize_gender(cls, data: Any):
        if isinstance(data, dict) and "gender" in data and isinstance(data["gender"], str):
            val = data["gender"].upper().strip()
            if val in [e.value for e in GenderEnum]:
                data["gender"] = val
            elif val in GenderEnum.__members__:
                data["gender"] = GenderEnum[val].value
        return data

class ProfileBodyUpdateRequest(BaseModel):
    height_cm: Optional[float] = None
    height: Optional[float] = None
    weight_kg: Optional[float] = None
    weight: Optional[float] = None

    @model_validator(mode="after")
    def compute_fields(self):
        # Resolve height
        if self.height_cm is None:
            if self.height is not None:
                # If height was entered in meters (e.g. 1.75m), convert to 175.0cm
                self.height_cm = round(self.height * 100.0, 2) if self.height < 3.0 else float(self.height)
            else:
                raise ValueError("height_cm or height is required")
        # Resolve weight
        if self.weight_kg is None:
            if self.weight is not None:
                self.weight_kg = float(self.weight)
            else:
                raise ValueError("weight_kg or weight is required")
        return self

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
