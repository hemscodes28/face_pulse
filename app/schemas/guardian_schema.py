from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field, EmailStr
from datetime import datetime
from app.models.enums import GuardianRelationshipStatus

class GuardianInviteRequest(BaseModel):
    guardian_email: str = Field(..., description="Email address of the registered user to invite as guardian")
    share_results: bool = Field(True, description="Allow guardian to view finalized measurement results")
    share_trends: bool = Field(True, description="Allow guardian to view diary and historical vitals trends")
    share_alerts: bool = Field(True, description="Allow guardian to receive vital anomaly alerts")

class GuardianPermissionUpdateRequest(BaseModel):
    share_results: bool = Field(..., description="Allow guardian to view finalized measurement results")
    share_trends: bool = Field(..., description="Allow guardian to view diary and historical vitals trends")
    share_alerts: bool = Field(..., description="Allow guardian to receive vital anomaly alerts")

class GuardianResponseRequest(BaseModel):
    action: str = Field(..., description="ACCEPT or REJECT")

class GuardianRelationshipResponse(BaseModel):
    id: str
    user_id: str
    guardian_user_id: str
    status: GuardianRelationshipStatus
    share_results: bool
    share_trends: bool
    share_alerts: bool
    created_at: datetime
    updated_at: datetime
    
    # Metadata for display
    guardian_name: Optional[str] = None
    guardian_email: Optional[str] = None
    ward_name: Optional[str] = None
    ward_email: Optional[str] = None

class WardSummaryResponse(BaseModel):
    relationship_id: str
    ward_id: str
    ward_name: str
    ward_email: str
    status: GuardianRelationshipStatus
    permissions: Dict[str, bool]
    created_at: datetime
