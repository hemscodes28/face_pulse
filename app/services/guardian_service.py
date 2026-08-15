import uuid
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status

from app.models.enums import GuardianRelationshipStatus
from app.models.guardian_model import UserGuardian
from app.schemas.guardian_schema import (
    GuardianInviteRequest,
    GuardianPermissionUpdateRequest,
    GuardianRelationshipResponse,
    WardSummaryResponse
)
from app.services.guardian_store import guardians_store
from app.services.user_store import users, user_emails
from app.services.measurement_service import get_measurement_result
from app.services.diary_service import get_user_diary_by_date
from app.services.session_store import sessions


def invite_guardian(user_id: str, request: GuardianInviteRequest) -> GuardianRelationshipResponse:
    """
    Ward invites a registered user as their guardian.
    Validates:
    - Guardian exists by email
    - Cannot invite oneself
    - Unique active relationship between user and guardian
    """
    guardian_email = request.guardian_email.lower().strip()
    guardian_user_id = user_emails.get(guardian_email)
    
    if not guardian_user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with email '{guardian_email}' not found."
        )
        
    if guardian_user_id == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot assign yourself as your own guardian."
        )
        
    # Check existing relationship
    for rel in guardians_store.values():
        if rel["user_id"] == user_id and rel["guardian_user_id"] == guardian_user_id:
            if rel["status"] in [GuardianRelationshipStatus.PENDING, GuardianRelationshipStatus.ACCEPTED]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"A relationship with status '{rel['status']}' already exists."
                )
            elif rel["status"] in [GuardianRelationshipStatus.REJECTED, GuardianRelationshipStatus.REVOKED]:
                # Re-activate to PENDING
                now = datetime.now(timezone.utc)
                rel["status"] = GuardianRelationshipStatus.PENDING
                rel["share_results"] = request.share_results
                rel["share_trends"] = request.share_trends
                rel["share_alerts"] = request.share_alerts
                rel["updated_at"] = now
                return _format_relationship_response(rel)
                
    rel_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    
    record = UserGuardian(
        id=rel_id,
        user_id=user_id,
        guardian_user_id=guardian_user_id,
        status=GuardianRelationshipStatus.PENDING,
        share_results=request.share_results,
        share_trends=request.share_trends,
        share_alerts=request.share_alerts,
        created_at=now,
        updated_at=now
    )
    
    guardians_store[rel_id] = record.model_dump()
    return _format_relationship_response(guardians_store[rel_id])


def get_my_guardians(user_id: str) -> List[GuardianRelationshipResponse]:
    """
    Returns all guardians linked to current user (Ward's view).
    """
    res = []
    for rel in guardians_store.values():
        if rel["user_id"] == user_id:
            res.append(_format_relationship_response(rel))
    return res


def update_guardian_permissions(
    user_id: str, 
    relationship_id: str, 
    request: GuardianPermissionUpdateRequest
) -> GuardianRelationshipResponse:
    """
    Ward updates sharing permissions for an active guardian.
    """
    rel = guardians_store.get(relationship_id)
    if not rel or rel["user_id"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian relationship not found or unauthorized."
        )
        
    rel["share_results"] = request.share_results
    rel["share_trends"] = request.share_trends
    rel["share_alerts"] = request.share_alerts
    rel["updated_at"] = datetime.now(timezone.utc)
    
    return _format_relationship_response(rel)


def revoke_guardian_access(user_id: str, relationship_id: str) -> GuardianRelationshipResponse:
    """
    Ward revokes a guardian's access.
    """
    rel = guardians_store.get(relationship_id)
    if not rel or rel["user_id"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian relationship not found or unauthorized."
        )
        
    rel["status"] = GuardianRelationshipStatus.REVOKED
    rel["updated_at"] = datetime.now(timezone.utc)
    return _format_relationship_response(rel)


def get_pending_guardian_requests(guardian_user_id: str) -> List[GuardianRelationshipResponse]:
    """
    Returns pending invitations received by current user (Guardian's view).
    """
    res = []
    for rel in guardians_store.values():
        if rel["guardian_user_id"] == guardian_user_id and rel["status"] == GuardianRelationshipStatus.PENDING:
            res.append(_format_relationship_response(rel))
    return res


def respond_to_guardian_request(
    guardian_user_id: str, 
    relationship_id: str, 
    action: str
) -> GuardianRelationshipResponse:
    """
    Guardian accepts or rejects an invite.
    """
    rel = guardians_store.get(relationship_id)
    if not rel or rel["guardian_user_id"] != guardian_user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian invitation not found."
        )
        
    act = action.upper().strip()
    if act == "ACCEPT":
        rel["status"] = GuardianRelationshipStatus.ACCEPTED
    elif act == "REJECT":
        rel["status"] = GuardianRelationshipStatus.REJECTED
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid action. Allowed values: ACCEPT, REJECT"
        )
        
    rel["updated_at"] = datetime.now(timezone.utc)
    return _format_relationship_response(rel)


def get_my_wards(guardian_user_id: str) -> List[WardSummaryResponse]:
    """
    Returns list of wards who have accepted the current user as a guardian.
    """
    res = []
    for rel in guardians_store.values():
        if rel["guardian_user_id"] == guardian_user_id and rel["status"] == GuardianRelationshipStatus.ACCEPTED:
            ward = users.get(rel["user_id"], {})
            res.append(WardSummaryResponse(
                relationship_id=rel["id"],
                ward_id=rel["user_id"],
                ward_name=ward.get("full_name", "Unknown Ward"),
                ward_email=ward.get("email", ""),
                status=rel["status"],
                permissions={
                    "share_results": rel["share_results"],
                    "share_trends": rel["share_trends"],
                    "share_alerts": rel["share_alerts"]
                },
                created_at=rel["created_at"]
            ))
    return res


def get_ward_profile(guardian_user_id: str, ward_id: str) -> Dict[str, Any]:
    """
    Returns demographic & health profile of a ward to their authorized guardian.
    """
    rel = _verify_guardian_relationship(guardian_user_id, ward_id)
    ward = users.get(ward_id)
    if not ward:
        raise HTTPException(status_code=404, detail="Ward profile not found.")
        
    return {
        "ward_id": ward_id,
        "full_name": ward.get("full_name"),
        "email": ward.get("email"),
        "date_of_birth": ward.get("date_of_birth"),
        "gender": ward.get("gender"),
        "height_cm": ward.get("height_cm"),
        "weight_kg": ward.get("weight_kg"),
        "bmi": ward.get("bmi"),
        "bmi_classification": ward.get("bmi_classification"),
        "blood_group": ward.get("blood_group"),
        "permissions": {
            "share_results": rel["share_results"],
            "share_trends": rel["share_trends"],
            "share_alerts": rel["share_alerts"]
        }
    }


def get_ward_latest_result(guardian_user_id: str, ward_id: str):
    """
    Retrieves a ward's most recent measurement report.
    Enforces share_results == True.
    """
    _verify_guardian_permission(guardian_user_id, ward_id, required_permission="share_results")
    
    latest_meas_id = None
    latest_time = ""
    for m_id, sess in sessions.items():
        if sess.get("user_id") == ward_id and str(sess.get("status")) in ["COMPLETED", "MeasurementStatus.COMPLETED"] and sess.get("results"):
            t = sess.get("completed_at") or sess.get("started_at") or ""
            if t >= latest_time:
                latest_time = t
                latest_meas_id = m_id
                
    if not latest_meas_id:
        return None
    return get_measurement_result(latest_meas_id)


def get_ward_measurement_result(guardian_user_id: str, ward_id: str, measurement_id: str):
    """
    Retrieves a ward's measurement result.
    Enforces:
    - Relationship is ACCEPTED
    - share_results == True
    """
    _verify_guardian_permission(guardian_user_id, ward_id, required_permission="share_results")
    result = get_measurement_result(measurement_id)
    if not result:
        raise HTTPException(status_code=404, detail="Measurement result not found or not completed.")
    return result


def get_ward_diary(guardian_user_id: str, ward_id: str, date_str: str):
    """
    Retrieves a ward's diary records for a date.
    Enforces:
    - Relationship is ACCEPTED
    - share_trends == True
    """
    _verify_guardian_permission(guardian_user_id, ward_id, required_permission="share_trends")
    return get_user_diary_by_date(user_id=ward_id, date_str=date_str)


def _verify_guardian_relationship(guardian_user_id: str, ward_id: str) -> dict:
    for rel in guardians_store.values():
        if (
            rel["guardian_user_id"] == guardian_user_id 
            and rel["user_id"] == ward_id 
            and rel["status"] == GuardianRelationshipStatus.ACCEPTED
        ):
            return rel
            
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Active guardian relationship not found for this ward."
    )


def _verify_guardian_permission(guardian_user_id: str, ward_id: str, required_permission: str) -> dict:
    rel = _verify_guardian_relationship(guardian_user_id, ward_id)
    if not rel.get(required_permission, False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Ward has not granted '{required_permission}' permission to you."
        )
    return rel


def _format_relationship_response(rel: dict) -> GuardianRelationshipResponse:
    ward = users.get(rel["user_id"], {})
    guardian = users.get(rel["guardian_user_id"], {})
    
    return GuardianRelationshipResponse(
        id=rel["id"],
        user_id=rel["user_id"],
        guardian_user_id=rel["guardian_user_id"],
        status=rel["status"],
        share_results=rel["share_results"],
        share_trends=rel["share_trends"],
        share_alerts=rel["share_alerts"],
        created_at=rel["created_at"],
        updated_at=rel["updated_at"],
        guardian_name=guardian.get("full_name"),
        guardian_email=guardian.get("email"),
        ward_name=ward.get("full_name"),
        ward_email=ward.get("email")
    )
