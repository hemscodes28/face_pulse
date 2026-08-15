import uuid
from datetime import datetime, timezone
from typing import Optional, TYPE_CHECKING
from pydantic import BaseModel, Field
from app.models.enums import UserRole

if TYPE_CHECKING:
    from app.models.profile_model import UserProfile

class User(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    full_name: str
    email: str
    password_hash: str
    role: UserRole = UserRole.USER
    is_active: bool = True
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
