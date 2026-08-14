from datetime import datetime, timezone
from fastapi import HTTPException
from app.services.user_store import users
from app.schemas.user_schema import ProfileBasicUpdateRequest, ProfileBodyUpdateRequest, ProfileMedicalUpdateRequest

def update_basic_profile(user_id: str, request: ProfileBasicUpdateRequest):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    users[user_id]["date_of_birth"] = request.date_of_birth
    users[user_id]["gender"] = request.gender
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]

def update_body_profile(user_id: str, request: ProfileBodyUpdateRequest):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    users[user_id]["height"] = request.height
    users[user_id]["weight"] = request.weight
    
    # Calculate BMI
    if request.height > 0:
        bmi = request.weight / (request.height ** 2)
        users[user_id]["bmi"] = round(bmi, 2)
        
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]

def update_medical_profile(user_id: str, request: ProfileMedicalUpdateRequest):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    valid_groups = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
    if request.blood_group not in valid_groups:
        raise HTTPException(status_code=400, detail="Invalid blood group")
        
    users[user_id]["blood_group"] = request.blood_group
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]

def complete_onboarding(user_id: str):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    users[user_id]["onboarding_completed"] = True
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]
