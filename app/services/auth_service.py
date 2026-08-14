import uuid
import hashlib
import hmac
from datetime import datetime, timezone, timedelta
import jwt
from fastapi import HTTPException, status, Depends
from fastapi.security import OAuth2PasswordBearer

from app.schemas.auth_schema import SignupRequest, LoginRequest, TokenResponse, GoogleLoginRequest
from app.schemas.user_schema import UserRecord
from app.services.user_store import users, user_emails

SECRET_KEY = "facepulse-super-secret-key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def _hash_password(password: str) -> str:
    """Simple SHA-256 hash with a fixed salt (dev only — use bcrypt in production)."""
    return hashlib.sha256(("facepulse_salt:" + password).encode()).hexdigest()


def _verify_password(plain: str, hashed: str) -> bool:
    return hmac.compare_digest(_hash_password(plain), hashed)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def signup(request: SignupRequest) -> TokenResponse:
    if request.password != request.confirm_password:
        raise HTTPException(status_code=400, detail="Passwords do not match")

    email_lower = request.email.lower()
    if email_lower in user_emails:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    user_record = UserRecord(
        user_id=user_id,
        full_name=request.full_name,
        email=email_lower,
        password_hash=_hash_password(request.password),
        created_at=now,
        updated_at=now,
    )

    users[user_id] = user_record.model_dump()
    user_emails[email_lower] = user_id

    access_token = create_access_token(data={"sub": user_id})
    return TokenResponse(access_token=access_token, token_type="bearer", user_id=user_id)


def login(request: LoginRequest) -> TokenResponse:
    email_lower = request.email.lower()
    user_id = user_emails.get(email_lower)

    if not user_id or not _verify_password(request.password, users[user_id]["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": user_id})
    return TokenResponse(access_token=access_token, token_type="bearer", user_id=user_id)


def google_login(request: GoogleLoginRequest) -> TokenResponse:
    """Mock Google login — creates a dummy user from the token string."""
    email_lower = f"google_{request.token[:8]}@mock.facepulse"

    if email_lower not in user_emails:
        user_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)
        user_record = UserRecord(
            user_id=user_id,
            full_name=f"Google User {request.token[:5]}",
            email=email_lower,
            password_hash=_hash_password(request.token),
            created_at=now,
            updated_at=now,
        )
        users[user_id] = user_record.model_dump()
        user_emails[email_lower] = user_id
    else:
        user_id = user_emails[email_lower]

    access_token = create_access_token(data={"sub": user_id})
    return TokenResponse(access_token=access_token, token_type="bearer", user_id=user_id)


async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except jwt.InvalidTokenError:
        raise credentials_exception

    user = users.get(user_id)
    if user is None:
        raise credentials_exception

    return user
