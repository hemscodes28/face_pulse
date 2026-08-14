from datetime import datetime, timezone
from fastapi import HTTPException
from app.services.user_store import users
from app.schemas.user_schema import ProfileBasicUpdateRequest, ProfileBodyUpdateRequest, ProfileMedicalUpdateRequest

def calculate_bmi_and_classification(height_cm: float, weight_kg: float):
    if height_cm <= 0 or weight_kg <= 0:
        return None, None
        
    height_m = height_cm / 100.0
    bmi = round(weight_kg / (height_m ** 2), 2)
    
    if bmi < 18.5:
        classification = "Underweight"
    elif bmi < 25.0:
        classification = "Normal"
    elif bmi < 30.0:
        classification = "Overweight"
    else:
        classification = "Obese"
        
    return bmi, classification

def update_basic_profile(user_id: str, request: ProfileBasicUpdateRequest):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    users[user_id]["date_of_birth"] = request.date_of_birth
    users[user_id]["gender"] = request.gender.value if hasattr(request.gender, "value") else request.gender
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]

def update_body_profile(user_id: str, request: ProfileBodyUpdateRequest):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    height_cm = request.height_cm
    weight_kg = request.weight_kg
    
    bmi, classification = calculate_bmi_and_classification(height_cm, weight_kg)
    
    users[user_id]["height_cm"] = height_cm
    users[user_id]["weight_kg"] = weight_kg
    users[user_id]["bmi"] = bmi
    users[user_id]["bmi_classification"] = classification
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]

def update_medical_profile(user_id: str, request: ProfileMedicalUpdateRequest):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    bg_val = request.blood_group.value if hasattr(request.blood_group, "value") else request.blood_group
    users[user_id]["blood_group"] = bg_val
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]

def complete_onboarding(user_id: str):
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
        
    users[user_id]["onboarding_completed"] = True
    users[user_id]["updated_at"] = datetime.now(timezone.utc)
    return users[user_id]
