import uuid
from datetime import datetime, timezone
from pydantic import BaseModel, Field
from app.models.enums import GuardianRelationshipStatus

class UserGuardian(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str           # The patient / ward who owns the health data
    guardian_user_id: str  # The guardian user who receives access
    status: GuardianRelationshipStatus = GuardianRelationshipStatus.PENDING
    share_results: bool = False
    share_trends: bool = False
    share_alerts: bool = False
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
