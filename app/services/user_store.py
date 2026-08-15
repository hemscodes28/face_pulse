import hashlib
from datetime import datetime, timezone
from typing import Dict, Any


def _hash_password(password: str) -> str:
    """Computes SHA-256 hash matching auth_service format."""
    return hashlib.sha256(("facepulse_salt:" + password).encode()).hexdigest()


# In-memory store: user_id -> dict(UserRecord)
users: Dict[str, Any] = {}

# In-memory lookup: email -> user_id
user_emails: Dict[str, str] = {}

# Seed Dummy User Login in Database
_dummy_user_id = "user_hemkumar"
_now = datetime.now(timezone.utc)

_dummy_user_record = {
    "user_id": _dummy_user_id,
    "full_name": "HemKumar",
    "email": "hemkumarr2803@gmail.com",
    "password_hash": _hash_password("hem@1234"),
    "role": "USER",
    "date_of_birth": "2004-12-12",
    "gender": "MALE",
    "height_cm": 170.0,
    "weight_kg": 60.0,
    "bmi": 20.76,
    "bmi_classification": "Normal",
    "blood_group": "O+",
    "onboarding_completed": True,
    "created_at": _now,
    "updated_at": _now,
}

users[_dummy_user_id] = _dummy_user_record
users["user_default"] = _dummy_user_record
user_emails["hemkumarr2803@gmail.com"] = _dummy_user_id
