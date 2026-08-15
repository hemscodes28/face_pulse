import uuid
from datetime import date, datetime, timezone
from pydantic import BaseModel, Field
from app.models.enums import GenderEnum, BloodGroupEnum

class UserProfile(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    date_of_birth: str  # YYYY-MM-DD
    gender: GenderEnum
    height_cm: float = Field(..., gt=0, description="Height in centimeters")
    weight_kg: float = Field(..., gt=0, description="Weight in kilograms")
    blood_group: BloodGroupEnum
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
