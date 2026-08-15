import sqlite3
import os
import hashlib
from datetime import datetime, timezone
from typing import Dict, Any

from app.services.diary_store import diary_records

DB_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "face_pulse_users.db")


def _hash_password(password: str) -> str:
    """Computes SHA-256 hash matching auth_service format."""
    return hashlib.sha256(("facepulse_salt:" + password).encode()).hexdigest()


# In-memory store: user_id -> dict(UserRecord)
users: Dict[str, Any] = {}

# In-memory lookup: email -> user_id
user_emails: Dict[str, str] = {}


def get_db_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


def init_sqlite_db():
    """Initializes local SQLite database for user accounts, credentials, and scan history."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS local_users (
            user_id TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT DEFAULT 'USER',
            date_of_birth TEXT,
            gender TEXT,
            height_cm REAL,
            weight_kg REAL,
            bmi REAL,
            bmi_classification TEXT,
            blood_group TEXT,
            onboarding_completed INTEGER DEFAULT 1,
            created_at TEXT,
            updated_at TEXT
        )
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS local_diary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            measurement_id TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            heart_rate REAL,
            spo2 REAL,
            systolic INTEGER,
            diastolic INTEGER,
            hrv INTEGER,
            breath INTEGER,
            respiratory_health INTEGER,
            quality_stars INTEGER,
            quality_label TEXT
        )
    """)
    conn.commit()

    # Seed HemKumar User if not already present
    cursor.execute("SELECT user_id FROM local_users WHERE email = ?", ("hemkumarr2803@gmail.com",))
    row = cursor.fetchone()
    _now_str = datetime.now(timezone.utc).isoformat()

    if not row:
        cursor.execute("""
            INSERT INTO local_users (
                user_id, full_name, email, password_hash, role,
                date_of_birth, gender, height_cm, weight_kg, bmi,
                bmi_classification, blood_group, onboarding_completed,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            "user_hemkumar",
            "HemKumar",
            "hemkumarr2803@gmail.com",
            _hash_password("hem@1234"),
            "USER",
            "2004-12-12",
            "MALE",
            170.0,
            60.0,
            20.76,
            "Normal",
            "O+",
            1,
            _now_str,
            _now_str
        ))
        conn.commit()

    # Load all user records into memory store
    cursor.execute("SELECT * FROM local_users")
    rows = cursor.fetchall()
    for r in rows:
        u_dict = {
            "user_id": r["user_id"],
            "full_name": r["full_name"],
            "email": r["email"],
            "password_hash": r["password_hash"],
            "role": r["role"],
            "date_of_birth": r["date_of_birth"],
            "gender": r["gender"],
            "height_cm": r["height_cm"],
            "weight_kg": r["weight_kg"],
            "bmi": r["bmi"],
            "bmi_classification": r["bmi_classification"],
            "blood_group": r["blood_group"],
            "onboarding_completed": bool(r["onboarding_completed"]),
            "created_at": r["created_at"],
            "updated_at": r["updated_at"],
        }
        users[r["user_id"]] = u_dict
        user_emails[r["email"].lower()] = r["user_id"]

    if "user_hemkumar" in users:
        users["user_default"] = users["user_hemkumar"]

    # Load all local diary entries into memory store
    cursor.execute("SELECT * FROM local_diary ORDER BY id ASC")
    diary_rows = cursor.fetchall()
    diary_records.clear()
    for d in diary_rows:
        try:
            dt = datetime.fromisoformat(d["recorded_at"])
        except Exception:
            dt = datetime.now(timezone.utc)
        diary_records.append({
            "user_id": d["user_id"],
            "measurement_id": d["measurement_id"],
            "recorded_at": dt,
            "heart_rate": d["heart_rate"],
            "spo2": d["spo2"],
            "systolic": d["systolic"],
            "diastolic": d["diastolic"],
            "hrv": d["hrv"],
            "breath": d["breath"],
            "respiratory_health": d["respiratory_health"],
            "quality_stars": d["quality_stars"],
            "quality_label": d["quality_label"],
        })

    conn.close()


def save_user_to_db(u: Dict[str, Any]):
    """Persists a user dictionary to local SQLite DB."""
    conn = get_db_connection()
    cursor = conn.cursor()
    _now_str = datetime.now(timezone.utc).isoformat()
    cursor.execute("""
        INSERT INTO local_users (
            user_id, full_name, email, password_hash, role,
            date_of_birth, gender, height_cm, weight_kg, bmi,
            bmi_classification, blood_group, onboarding_completed,
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            full_name=excluded.full_name,
            email=excluded.email,
            password_hash=excluded.password_hash,
            role=excluded.role,
            date_of_birth=excluded.date_of_birth,
            gender=excluded.gender,
            height_cm=excluded.height_cm,
            weight_kg=excluded.weight_kg,
            bmi=excluded.bmi,
            bmi_classification=excluded.bmi_classification,
            blood_group=excluded.blood_group,
            onboarding_completed=excluded.onboarding_completed,
            updated_at=?
    """, (
        u["user_id"],
        u.get("full_name", "HemKumar"),
        u["email"],
        u.get("password_hash", ""),
        u.get("role", "USER"),
        u.get("date_of_birth", "2004-12-12"),
        u.get("gender", "MALE"),
        u.get("height_cm", 170.0),
        u.get("weight_kg", 60.0),
        u.get("bmi", 20.76),
        u.get("bmi_classification", "Normal"),
        u.get("blood_group", "O+"),
        1 if u.get("onboarding_completed", True) else 0,
        str(u.get("created_at", _now_str)),
        _now_str,
        _now_str
    ))
    conn.commit()
    conn.close()


# Initialize SQLite DB on module import
init_sqlite_db()
