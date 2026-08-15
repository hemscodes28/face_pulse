from pydantic import BaseModel, Field

class SignupRequest(BaseModel):
    full_name: str = Field(..., min_length=2, description="User's full name")
    email: str = Field(..., description="User's email address")
    password: str = Field(..., min_length=6, description="Password (at least 6 chars)")
    confirm_password: str = Field(..., min_length=6, description="Must match password")

class LoginRequest(BaseModel):
    email: str = Field(..., description="User's email address")
    password: str = Field(..., description="Password")

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user_id: str

class GoogleLoginRequest(BaseModel):
    token: str = Field(..., description="Dummy google token from frontend")
