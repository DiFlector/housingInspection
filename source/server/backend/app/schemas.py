from typing import List, Optional, Union
from pydantic import BaseModel, Field, EmailStr, validator
from datetime import datetime

# --- Token ---
class Token(BaseModel):
    access_token: str
    token_type: str

# --- User ---
class UserBase(BaseModel):
    username: str = Field(..., example="john_doe", min_length=3, max_length=20)
    email: EmailStr = Field(..., example="john.doe@example.com")
    full_name: Optional[str] = Field(None, example="John Doe", max_length=100)

class UserCreate(UserBase):
    password: str = Field(..., example="secret_password", min_length=8)
    password_confirm: str = Field(..., example="secret_password")
    role: str = Field("citizen", example="citizen")

    @validator("password")
    def password_strength(cls, v):
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        return v

    @validator("password_confirm")
    def passwords_match(cls, v, values, **kwargs):
        if 'password' in values and v != values['password']:
            raise ValueError('Passwords do not match')
        return v

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    role: str

    class Config:
        from_attributes = True

class UserUpdate(BaseModel):
    username: Optional[str] = Field(None, example="john_doe", min_length=3, max_length=20)
    email: Optional[EmailStr] = Field(None, example="john.doe@example.com")
    full_name: Optional[str] = Field(None, example="John Doe", max_length=100)
    role: Optional[str] = Field(None, example="citizen")
    is_active: Optional[bool] = None

# --- Appeal Status ---
class AppealStatusBase(BaseModel):
  name: str = Field(..., example="New", max_length=50)

class AppealStatusCreate(AppealStatusBase):
  pass

class AppealStatus(AppealStatusBase):
  id: int
  class Config:
      from_attributes = True

# --- Appeal Category ---
class AppealCategoryBase(BaseModel):
  name: str = Field(..., example="Room merge", max_length=50)

class AppealCategoryCreate(AppealCategoryBase):
  pass

class AppealCategory(AppealCategoryBase):
  id: int
  class Config:
      from_attributes = True

# --- Appeal ---
class AppealBase(BaseModel):
    address: str = Field(..., example="ул. Пушкина, д. Колотушкина", min_length=5, max_length=255)
    description: Optional[str] = Field(None, example="Описание проблемы", max_length=1000)
    category_id: int = Field(..., example=1)

class AppealCreate(AppealBase):
    pass

class Appeal(AppealBase):
    id: int
    user_id: int
    status_id: int
    created_at: datetime
    updated_at: datetime
    file_paths: Optional[List[str]] = None
    user: User
    status: AppealStatus
    category: AppealCategory

    class Config:
        from_attributes = True

class AppealUpdate(BaseModel):
  status_id: Optional[int] = None
  category_id: Optional[int] = Field(None, example=1)
  address: Optional[str] = Field(None, example="ул. Пушкина, д. Колотушкина", min_length=5, max_length=255)
  description: Optional[str] = Field(None, example="Описание проблемы", max_length=1000)

class MessageBase(BaseModel):
    content: str = Field(..., example="Текст сообщения")

class Message(MessageBase):
    id: int
    appeal_id: int
    sender_id: int
    created_at: datetime
    file_paths: Optional[List[str]] = None
    sender: User

    class Config:
        from_attributes = True

# --- Device Token ---
class DeviceTokenCreate(BaseModel):
    fcm_token: str
    device_type: Optional[str] = None