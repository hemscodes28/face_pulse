from fastapi import APIRouter

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["Authentication"]
)

from app.schemas.auth_schema import SignupRequest, LoginRequest, TokenResponse, GoogleLoginRequest
import app.services.auth_service as auth_service

@router.post("/signup", response_model=TokenResponse)
def signup(request: SignupRequest):
    return auth_service.signup(request)

@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest):
    return auth_service.login(request)

@router.post("/google", response_model=TokenResponse)
def google_login(request: GoogleLoginRequest):
    return auth_service.google_login(request)
