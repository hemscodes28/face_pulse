from typing import List
from fastapi import APIRouter, Depends, Query, HTTPException, status
from app.schemas.guardian_schema import (
    GuardianInviteRequest,
    GuardianPermissionUpdateRequest,
    GuardianResponseRequest,
    GuardianRelationshipResponse,
    WardSummaryResponse
)
from app.schemas.measurement_schema import MeasurementResult
from app.schemas.diary_schema import DiaryDateResponse
from app.services.auth_service import get_current_user
import app.services.guardian_service as guardian_service

router = APIRouter(
    prefix="/api/v1/guardians",
    tags=["Guardians & Health Sharing"]
)

# ── Ward Operations (Managing My Guardians) ───────────────────

@router.post("/invite", response_model=GuardianRelationshipResponse, status_code=status.HTTP_201_CREATED)
def invite_guardian(
    request: GuardianInviteRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Ward invites a registered user as a guardian with specific initial permissions.
    """
    return guardian_service.invite_guardian(current_user["user_id"], request)


@router.get("", response_model=List[GuardianRelationshipResponse])
def get_my_guardians(
    current_user: dict = Depends(get_current_user)
):
    """
    Returns all guardian relationships configured by the current user (Ward's view).
    """
    return guardian_service.get_my_guardians(current_user["user_id"])


@router.put("/{relationship_id}/permissions", response_model=GuardianRelationshipResponse)
def update_guardian_permissions(
    relationship_id: str,
    request: GuardianPermissionUpdateRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Ward modifies sharing permissions (share_results, share_trends, share_alerts).
    """
    return guardian_service.update_guardian_permissions(current_user["user_id"], relationship_id, request)


@router.delete("/{relationship_id}", response_model=GuardianRelationshipResponse)
def revoke_guardian_access(
    relationship_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Ward revokes a guardian's access.
    """
    return guardian_service.revoke_guardian_access(current_user["user_id"], relationship_id)


# ── Guardian Operations (Monitoring Wards) ────────────────────

@router.get("/requests", response_model=List[GuardianRelationshipResponse])
def get_pending_requests(
    current_user: dict = Depends(get_current_user)
):
    """
    Returns pending invitations received by the current user to act as a guardian.
    """
    return guardian_service.get_pending_guardian_requests(current_user["user_id"])


@router.post("/requests/{relationship_id}/respond", response_model=GuardianRelationshipResponse)
def respond_to_request(
    relationship_id: str,
    request: GuardianResponseRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Guardian responds to an invitation with ACCEPT or REJECT.
    """
    return guardian_service.respond_to_guardian_request(current_user["user_id"], relationship_id, request.action)


@router.get("/wards", response_model=List[WardSummaryResponse])
def get_my_wards(
    current_user: dict = Depends(get_current_user)
):
    """
    Returns all wards currently monitored by the guardian.
    """
    return guardian_service.get_my_wards(current_user["user_id"])


@router.get("/wards/{ward_id}/results/{measurement_id}", response_model=MeasurementResult)
def get_ward_measurement_result(
    ward_id: str,
    measurement_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Guardian views a ward's measurement result (requires active relationship & share_results=true).
    """
    return guardian_service.get_ward_measurement_result(current_user["user_id"], ward_id, measurement_id)


@router.get("/wards/{ward_id}/diary", response_model=DiaryDateResponse)
def get_ward_diary(
    ward_id: str,
    date: str = Query(..., description="Target date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user)
):
    """
    Guardian views a ward's daily vitals history (requires active relationship & share_trends=true).
    """
    return guardian_service.get_ward_diary(current_user["user_id"], ward_id, date)
