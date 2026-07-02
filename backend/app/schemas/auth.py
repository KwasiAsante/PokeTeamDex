from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr = Field(..., description="Email address for the new account.")
    password: str = Field(..., description="Plain-text password (hashed server-side before storage).")


class LoginRequest(BaseModel):
    email: EmailStr = Field(..., description="Registered email address.")
    password: str = Field(..., description="Account password.")


class TokenResponse(BaseModel):
    access_token: str = Field(..., description="JWT bearer token. Pass as 'Authorization: Bearer <token>' on all protected endpoints.")
    token_type: str = Field("bearer", description="Token scheme — always 'bearer'.")


class UserResponse(BaseModel):
    id: int = Field(..., description="Database ID of the user.")
    email: str = Field(..., description="Registered email address.")

    model_config = {"from_attributes": True}
